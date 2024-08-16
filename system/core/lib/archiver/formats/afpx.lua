local fs = require("filesystem")
local paths = require("paths")
local unicode = require("unicode")

--------------------------------------------

--afp - archive files pack
local nullchar = string.char(0)

--------------------------------------------

local function tableRemove(tbl, dat)
    local count = 0
    for k, v in pairs(tbl) do
        if v == dat then
            count = count + 1
            tbl[k] = nil
        end
    end
    return count > 0
end

local afpx = {}

function afpx.pack(dir, outputpath)
    local files = {}
    local function process()
        local outputfile = assert(fs.open(outputpath, "wb"))
        table.insert(files, outputfile)
        assert(outputfile.write("AFP_____"))

        local function addfile(path)
            local full_path = paths.concat(dir, path)
            assert(outputfile.write(path:sub(2, #path) .. nullchar))
            assert(outputfile.write(tostring(math.floor(fs.size(full_path))) .. nullchar))

            local file, err = fs.open(full_path, "rb")
            if not file then error("error: " .. err .. " to open file " .. full_path, 0) end
            table.insert(files, file)
            while true do
                local data = file.read(math.huge)
                if not data then break end
                assert(outputfile.write(data))
            end
            tableRemove(files, file)
            file.close()
        end
        local function recurse(ldir)
            local archpath = unicode.sub(ldir, unicode.len(dir) + 1, unicode.len(ldir))
            if archpath:sub(1, 1) ~= "/" then archpath = "/" .. archpath end

            for _, path in ipairs(fs.list(ldir)) do
                local full_path = paths.concat(ldir, path)

                if full_path ~= outputpath then
                    if fs.isDirectory(full_path) then
                        recurse(full_path)
                    else
                        addfile(paths.concat(archpath, path))
                    end
                end
            end
        end
        recurse(dir)
        tableRemove(files, outputfile)
        outputfile.close()
    end

    local ret = {pcall(process)}
    for i, v in ipairs(files) do
        v.close()
    end
    return table.unpack(ret)
end

function afpx.unpack(inputpath, dir)
    local files = {}
    local function process()
        local inputfile = assert(fs.open(inputpath, "rb"))
        table.insert(files, inputfile)

        local signature = inputfile.read(8)
        if signature == "AFP_____" then --archive files pack
            local function read()
                local data = ""
                while true do
                    local ldata = inputfile.read(1)
                    if not ldata or ldata == nullchar then break end
                    data = data .. ldata
                end
                return data
            end
            while true do
                local path = read()
                if path == "" then break end
                if path:find("%.%.") then error("this archive is broken", 2) end
                local filesize = tonumber(read())

                local path = paths.concat(dir, path)
                fs.makeDirectory(paths.path(path))
                local file = assert(fs.open(path, "wb"))
                table.insert(files, file)
                while true do
                    local data = inputfile.read(filesize)
                    if not data then break end
                    filesize = filesize - #data
                    assert(file.write(data))
                    if filesize <= 0 then break end
                end
                tableRemove(files, file)
                file.close()
            end
        else
            error("this arhive format is not supported", 0)
        end

        tableRemove(files, inputfile)
        inputfile.close()
    end

    local ret = {pcall(process)}
    for i, v in ipairs(files) do
        v.close()
    end
    return table.unpack(ret)
end

afpx.unloadable = true
return afpx