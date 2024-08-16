local fs = require("filesystem")
local paths = require("paths")
local system = require("system")
local archiver = {}
archiver.formatsPath = system.getResourcePath("formats")
archiver.forceDriver = nil
archiver.supported = {}
for i, name in ipairs(fs.list(archiver.formatsPath)) do
    archiver.supported[i] = paths.hideExtension(paths.name(name))
end

function archiver.findDriver(path, custom)
    if archiver.forceDriver then
        if fs.exists(archiver.forceDriver) then
            return require(archiver.forceDriver)
        end
    else
        local function fromSignature()
            local signature = fs.readSignature(path)
            if signature == "AFP_____" then
                return "afpx"
            else
                return "tar"
            end
        end

        local function driver(exp)
            local formatDriverPath = paths.concat(archiver.formatsPath, exp .. ".lua")
            if fs.exists(formatDriverPath) then
                return require(formatDriverPath)
            end
        end

        local exp = custom or paths.extension(path)
        if exp then
            local lib = driver(exp)
            if lib then
                return lib
            else
                return driver(fromSignature())
            end
        else
            return driver(fromSignature())
        end
    end
end

function archiver.pack(dir, outputpath, custom)
    dir = paths.canonical(dir)
    outputpath = paths.canonical(outputpath)

    local driver = archiver.findDriver(outputpath, custom)
    if driver then
        return driver.pack(dir, outputpath)
    else
        return nil, "unknown archive format"
    end
end

function archiver.unpack(inputpath, dir, custom)
    inputpath = paths.canonical(inputpath)
    dir = paths.canonical(dir)

    local driver = archiver.findDriver(inputpath, custom)
    if driver then
        return driver.unpack(inputpath, dir)
    else
        return nil, "unknown archive format"
    end
end

archiver.unloadable = true
return archiver