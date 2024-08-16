local fs = require("filesystem")
local serialization = require("serialization")

--------------------------------

local function new(path, data)
    checkArg(1, path, "string")
    checkArg(2, data, "table", "nil")

    local lreg = {path = path, data = data or {}}
    if fs.exists(lreg.path) then
        local tbl = serialization.load(lreg.path)
        if tbl then
            lreg.data = tbl
        end
    end

    function lreg.save()
        return serialization.save(lreg.path, lreg.data)
    end

    function lreg.apply(tbl)
        if type(tbl) == "string" then
            local ntbl, err = serialization.load(tbl)
            if not ntbl then
                return nil, err
            end
            tbl = ntbl
        end
        local bl = {
            ["reg_rm_list"] = true,
            ["reg_rm_all"] = true,
            ["reg_adds"] = true
        }
        local function recurse(ltbl, native)
            for _, reg_rm in ipairs(ltbl.reg_rm_list or {}) do
                native[reg_rm] = nil
            end
            for _, reg_add in ipairs(ltbl.reg_adds or {}) do
                table.insert(native, reg_add)
            end
            if ltbl.reg_rm_all then
                for key in pairs(native) do
                    native[key] = nil
                end
            end
            for key, value in pairs(ltbl) do
                if not bl[key] then
                    if type(value) == "table" then
                        if type(native[key]) ~= "table" then
                            native[key] = {}
                        end
                        recurse(value, native[key])
                    else
                        native[key] = value
                    end
                end
            end
        end
        recurse(tbl, lreg.data)
        return true
    end

    function lreg.hotReload()
        local tbl = serialization.load(lreg.path)
        if tbl then
            lreg.data = tbl
        else
            lreg.data = {}
        end
    end
    
    setmetatable(lreg, {__newindex = function(_, key, value)
        if lreg.data[key] ~= value then
            lreg.data[key] = value
            lreg.save()
        end
    end, __index = function(_, key)
        return lreg.data[key]
    end})

    return lreg
end

local registry = new("/data/registry.dat")
rawset(registry, "new", new)
rawset(registry, "unloadable", true)
return registry