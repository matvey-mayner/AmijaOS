local fs = require("filesystem")
local unicode = require("unicode")
local paths = require("paths")
local package = require("package")
local bootloader = require("bootloader")
local event = require("event")

------------------------------------

local programs = {}
programs.paths = {"/data/bin", "/vendor/bin", "/system/bin", "/system/core/bin"} --позиция по мере снижения приоритета(первый элемент это самый высокий приоритет)
programs.mainFile = "main.lua"
programs.extension = ".app"

function programs.find(name)
    if unicode.sub(name, 1, 1) == "/" then
        if fs.exists(name) then
            if fs.isDirectory(name) then
                local executeFile = paths.concat(name, programs.mainFile)
                if fs.exists(executeFile) and not fs.isDirectory(executeFile) then
                    return executeFile
                end
            else
                return name
            end
        end
    else
        for i, v in ipairs(programs.paths) do
            local path = paths.concat(v, name)
            if fs.exists(path .. ".lua") and not fs.isDirectory(path .. ".lua") then
                return path .. ".lua"
            else
                if fs.exists(path .. programs.extension) and fs.isDirectory(path .. programs.extension) then
                    path = paths.concat(path .. programs.extension, programs.mainFile)
                    if fs.exists(path) and not fs.isDirectory(path) then
                        return path
                    end
                end
            end
        end
    end
end

function programs.load(name, mode, env)
    local path = programs.find(name)
    if not path then return nil, "no such program" end
    return loadfile(path, mode, env or bootloader.createEnv())
end

function programs.execute(name, ...)
    local code, err = programs.load(name)
    if not code then return nil, err end
    
    local thread = package.get("thread")
    if not thread then
        return pcall(code, ...)
    else
        local t = thread.create(code, ...)
        t:resume() --потому что по умолчанию поток спит
        while t:status() ~= "dead" do event.yield() end
        return table.unpack(t.out or {true})
    end
end

function programs.xexecute(name, ...)
    local code, err = programs.load(name)
    if not code then return nil, err end
    
    local thread = package.get("thread")
    if not thread then
        return xpcall(code, debug.traceback, ...)
    else
        local t = thread.create(code, ...)
        t:resume() --потому что по умолчанию поток спит
        while t:status() ~= "dead" do event.yield() end
        return thread.decode(t)
    end
end

programs.unloadable = true
return programs