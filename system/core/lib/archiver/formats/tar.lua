local fs = require("filesystem")
local paths = require("paths")
local unicode = require("unicode")

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

--------------------------------------------

local tar = {}

function tar.pack(dir, outputpath)
    dir = paths.canonical(dir)
    outputpath = paths.canonical(outputpath)
end

function tar.unpack(inputpath, dir)
    inputpath = paths.canonical(inputpath)
    dir = paths.canonical(dir)
end

tar.unloadable = true
return tar