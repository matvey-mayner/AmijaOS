local fs = require("filesystem")
local programs = require("programs")
local paths = require("paths")
local system = require("system")

------------------------------------------------

local osenv = {}

os.remove = fs.remove
os.rename = fs.rename

function os.execute(command) --в системе пока-что нет консоли
    if not command then return true end
    return programs.execute(command)
end

function os.tmpname()
    local name = ""
    for i = 1, 16 do
        name = name .. tostring(math.floor(math.random(0, 9)))
    end
    name = name .. ".tmp"

    return paths.concat("/tmp", name)
end

function os.getenv(varname)
    return osenv[varname]
end

function os.setenv(varname, value)
    osenv[varname] = value
    return value --так работает в openOS
end

------------------------------------------------

function os.exit(code)
    error({reason = "interrupted", code = code or 0}, 0)
end

local native_pcall = pcall
local native_xpcall = xpcall

function _G.pcall(...)
    return system.checkExitinfo(native_pcall(...))
end

function _G.xpcall(...)
    return system.checkExitinfo(native_xpcall(...))
end