local bootloader = ...
local component = component
local computer = computer
local unicode = unicode

------------------------------------

local libenv = bootloader.createEnv()
local loadingNow = {}
local package = {
    paths = {"/data/lib", "/vendor/lib", "/system/lib", "/system/core/lib"}, --позиция по мере снижения приоритета(первый элемент это самый высокий приоритет)
    allowEnclosedLoadingCycle = false,
    hardAutoUnloading = false,
    hooks = {}
}

------------------------------------ adding static libraries to the list

package.loaded = {
    ["package"] = package,
    ["bootloader"] = bootloader
}

for key, value in pairs(_G) do
    if type(value) == "table" then
        package.loaded[key] = value
    end
end

------------------------------------ caches

package.cache = {}
package.libStubsCache = {}

------------------------------------

local function raw_require(name)
    if not package.loaded[name] and not package.cache[name] then
        local finded = package.find(name)
        if not finded then
            error("lib " .. name .. " is not found", 3)
        end

        loadingNow[name] = true
        local lib = assert(loadfile(finded, nil, libenv))()
        loadingNow[name] = nil

        if type(lib) ~= "table" or lib.unloadable then
            package.cache[name] = lib
        else
            package.loaded[name] = lib
        end
    end

    if not package.loaded[name] and not package.cache[name] then
        error("lib " .. name .. " is not found" , 3)
    end

    return package.loaded[name] or package.cache[name]
end

local function hooked_require(name)
    local lib = raw_require(name)
    for _, hook in ipairs(package.hooks) do
        lib = hook(name, lib)
    end
    return lib
end

------------------------------------

function package.find(name)
    local fs = require("filesystem")
    local paths = require("paths")

    local function resolve(path, deep)
        if fs.exists(path) then
            if fs.isDirectory(path) then
                local lpath = paths.concat(path, "init.lua")
                if fs.exists(lpath) and not fs.isDirectory(lpath) then
                    return lpath
                end
            else
                return path
            end
        end

        if not deep then
            return resolve(path .. ".lua", true)
        end
    end
    
    if unicode.sub(name, 1, 1) == "/" then
        return resolve(name)
    else
        for i, v in ipairs(package.paths) do
            local path = resolve(paths.concat(v, name))
            if path then
                return path
            end
        end
    end
end

function package.require(name, force)
    if force then
        return hooked_require(name)
    end

    local lib = package.loaded[name] or package.cache[name]
    if lib then
        return lib
    elseif package.hardAutoUnloading or loadingNow[name] then
        if package.hardAutoUnloading or package.allowEnclosedLoadingCycle then
            if package.libStubsCache[name] then
                return package.libStubsCache[name]
            else
                package.libStubsCache[name] = setmetatable({}, {__index = function (_, key)
                    return (hooked_require(name))[key]
                end, __newindex = function (_, key, value)
                    (hooked_require(name))[key] = value
                end})
                return package.libStubsCache[name]
            end
        else
            error("enclosed loading cycle is disabled", 2)
        end
    else
        return hooked_require(name)
    end
end

function package.get(name)
    return package.loaded[name] or package.cache[name]
end

function package.isLoaded(name)
    return not not package.get(name)
end

function package.isLoadingNow(name)
    return not not loadingNow[name]
end

function package.isInstalled(name)
    return not not package.find(name)
end

function package.applyHook(hook)
    table.insert(package.hooks, hook)
end

function package.cancelHook(hook)
    table.clear(package.hooks, hook)
end

function package.register(name, path)
    if bootloader.bootfs.exists(path) and not package.loaded[name] and not package.cache[name] then
        local lib = bootloader.dofile(path, nil, bootloader.createEnv())
        if type(lib) ~= "table" or lib.unloadable then
            package.cache[name] = lib
        else
            package.loaded[name] = lib
        end
        return lib
    end
end

function package.invoke(libname, method, ...)
    local lib = require(libname)
    local obj = lib[method]
    if type(obj) == "function" then
        return obj(...)
    else
        return obj
    end
end

function package.delay(lib, action)
    local mt = {}
    function mt.__index(tbl, key)
        mt.__index = nil
        if type(action) == "function" then
            action()
        else
            dofile(action)
        end
        return tbl[key]
    end
    if lib.internal then
       setmetatable(lib.internal, mt)
    end
    setmetatable(lib, mt)
end

function package.unload(name, force)
    if force then
        if package.loaded[name] then
            table.clear(package.loaded[name])
            package.loaded[name] = nil
        end

        if _G[name] then
            table.clear(_G[name])
            _G[name] = nil
        end
    end
    
    if package.cache[name] then
        table.clear(package.cache[name])
        package.cache[name] = nil
    end
end

local attachMeta = {__index = function(lib, key)
    if lib.functionCache[key] then
        return lib.functionCache[key]
    end

    local fs = require("filesystem")
    local paths = require("paths")

    local path = paths.concat(lib.functionFolder, key .. ".lua")
    if fs.exists(path) then
        local func = assert(loadfile(path, nil, libenv))
        lib.functionCache[key] = func
        return func
    end
end}
function package.attachFunctionFolder(lib, path) --позваляет сохранить малоиспользуемые функции библиотеки на HDD отдельным файлом чтобы загружать ее по необходимости и экономить память
    lib.functionFolder = require("system").getResourcePath(path)
    lib.functionCache = {}
    require("cache").attachUnloader(lib.functionCache)
    setmetatable(lib, attachMeta)
end

------------------------------------

return package