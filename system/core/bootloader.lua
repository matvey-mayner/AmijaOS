--OpenKernel bootloader

------------------------------------base init

local params = (...) or {}
local component, computer, unicode = component, computer, unicode

local pullSignal = computer.pullSignal
local shutdown = computer.shutdown
local error = error
local pcall = pcall

_G._COREVERSION = "OpenKernel 1.1"
_G._OSVERSION = _G._COREVERSION --это перезаписываеться в дистрибутивах

local bootloader = params.unpackBootloader or {} --библиотека загрузчика
bootloader.firstEeprom = component.list("eeprom")() --хранит адрес eeprom с которого произошла загрузка
bootloader.tmpaddress = computer.tmpAddress()

bootloader.bootaddress = computer.getBootAddress()
bootloader.bootfs = component.proxy(bootloader.bootaddress)

bootloader.coreversion = _G._COREVERSION
bootloader.runlevel = "Kernel"

function computer.runlevel()
    return bootloader.runlevel
end

------------------------------------ set architecture

bootloader.supportedArchitectures = {
    ["Lua 5.3"] = true,
    ["Lua 5.4"] = true
}

local architecture = "unknown"
if computer.getArchitecture then architecture = computer.getArchitecture() end
if not bootloader.supportedArchitectures[architecture] then
    pcall(computer.setArchitecture, "Lua 5.4")
    pcall(computer.setArchitecture, "Lua 5.3")
end

------------------------------------ bootloader constants

bootloader.defaultShellPath = "/system/System-main.lua"

------------------------------------ base functions

function bootloader.yield() --катыльный способ вызвать прирывания дабы избежать краша(звук издаваться не будет так как функция завершаеться ошибкой из за переданого 0)
    pcall(computer.beep, 0)
end

function bootloader.createEnv() --создает _ENV для программы, где _ENV будет личьный, а _G обший
    return setmetatable({_G = _G}, {__index = _G})
end

function bootloader.find(name, ignoreData)
    local checkList = {"/data/", "/vendor/", "/system/", "/system/core/"} --в порядке уменьшения приоритета(data самый приоритетный)
    if ignoreData then
        table.remove(checkList, 1)
    end
    for index, pathPath in ipairs(checkList) do
        local path = pathPath .. name
        if bootloader.bootfs.exists(path) and not bootloader.bootfs.isDirectory(path) then
            return path
        end
    end
end

function bootloader.readFile(fs, path)
    local file, err = fs.open(path, "rb")
    if not file then return nil, err end

    local buffer = ""
    repeat
        local data = fs.read(file, math.huge)
        buffer = buffer .. (data or "")
    until not data
    fs.close(file)

    return buffer
end

function bootloader.writeFile(fs, path, data)
    local file, err = fs.open(path, "wb")
    if not file then return nil, err end
    local ok, err = fs.write(file, data)
    if not ok then
        pcall(fs.close, file)
        return nil, err
    end
    fs.close(file)
    return true
end

function bootloader.loadfile(path, mode, env)
    local data, err = bootloader.readFile(bootloader.bootfs, path)
    if not data then return nil, err end
    return load(data, "=" .. path, mode or "bt", env or _G)
end

function bootloader.dofile(path, env, ...)
    return assert(bootloader.loadfile(path, nil, env))(...)
end

------------------------------------ bootloader functions

function bootloader.unittests(path, ...)
    local fs = require("filesystem")
    local paths = require("paths")
    local programs = require("programs")

    for _, file in ipairs(fs.list(path)) do
        local lpath = paths.concat(path, file)
        local ok, state, log = assert(programs.execute(lpath, ...))
        if not ok then
            error("error \"" .. (state or "unknown error") .. "\" in unittest: " .. file, 0)
        elseif not state then
            error("warning unittest \"" .. file .. "\" \"" .. (log and (", log:\n" .. log) or "") .. "\"", 0)
        end
    end
end

function bootloader.autorunsIn(path, ...)
    local fs = require("filesystem")
    local paths = require("paths")
    local event = require("event")
    local programs = require("programs")

    for i, v in ipairs(fs.list(path)) do
        local full_path = paths.concat(path, v)

        local func, err = programs.load(full_path)
        if not func then
            event.errLog("err \"" .. (err or "unknown error") .. "\", to load program: " .. full_path)
        else
            local ok, err = pcall(func, ...)
            if not ok then
                event.errLog("err \"" .. (err or "unknown error") .. "\", in program: " .. full_path)
            end
        end        
    end
end

function bootloader.initScreen(gpu, screen, rx, ry)
    pcall(component.invoke, screen, "turnOn")
    pcall(component.invoke, screen, "setPrecise", false)

    if gpu.getScreen() ~= screen then
        gpu.bind(screen, false)
    end

    if gpu.setActiveBuffer and gpu.getActiveBuffer() ~= 0 then
        gpu.setActiveBuffer(0)
    end
    
    local mx, my = gpu.maxResolution()
    rx = rx or mx
    ry = ry or my
    if rx > mx then rx = mx end
    if ry > my then ry = my end

    gpu.setDepth(1)
    gpu.setDepth(gpu.maxDepth())
    gpu.setResolution(rx, ry)
    gpu.setBackground(0)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, rx, ry, " ")

    return rx, ry
end

function bootloader.bootstrap()
    if bootloader.runlevel ~= "Kernel" then error("!!!bootstrap can only be started with Kernel Level!!!", 0) end

    --natives позваляет получить доступ к нетронутым методами библиотек computer и component
    _G.natives = bootloader.dofile("/system/core/lib/natives.lua", bootloader.createEnv())

    --на lua 5.3 нет встроеной либы bit32, но она нужна для совместимости, так что хай будет
    if not bit32 then 
        _G.bit32 = bootloader.dofile("/system/core/lib/bit32.lua", bootloader.createEnv())
    end

    --бут скрипты
    do 
        local path = "/system/core/boot/"
        for i, v in ipairs(bootloader.bootfs.list(path) or {}) do
            bootloader.dofile(path .. v, _G)
        end
    end

    --инициализация библиотек
    bootloader.dofile("/system/core/luaenv/a_base.lua", bootloader.createEnv())
    local package = bootloader.dofile("/system/core/lib/package.lua", bootloader.createEnv(), bootloader)
    _G.require = package.require
    _G.computer = nil
    _G.component = nil
    _G.unicode = nil
    _G.natives = nil
    package.register("paths", "/system/core/lib/paths.lua")
    local filesystem = package.register("filesystem", "/system/core/lib/filesystem.lua")
    require("vcomponent", true) --подключения библиотеки виртуальных компонентов
    require("hook", true) --подключения библиотеки хуков
    local event = require("event", true)
    require("lastinfo", true)
    require("cache", true)

    --проверка целосности системы (юнит тесты)
    bootloader.unittests("/system/core/unittests")
    bootloader.unittests("/system/unittests")

    --запуск автозагрузочных файлов ядра и дистрибутива
    bootloader.autorunsIn("/system/core/luaenv")
    bootloader.autorunsIn("/system/core/autoruns")
    bootloader.autorunsIn("/system/autoruns")

    --инициализация
    bootloader.runlevel = "kernel"
    filesystem.init()
end

function bootloader.runShell(path, ...)
    --запуск оболочки дистрибутива
    if require("filesystem").exists(path) then
        bootloader.bootSplash("Starting The System...")
        assert(require("programs").load(path))(...)
    else
        bootloader.bootSplash("!KERNEL PANIC!")
        os.sleep(0.05)
        computer.beep(100, 0.8)
        local component = require("component")
        local gpu = component.gpu
        local computer = require("computer")
        local event = require("event")

          gpu.setBackground(0x000000)
          gpu.setForeground(0xFFFFFF)
          gpu.fill(1, 1, 50, 16, " ")

        gpu.setResolution(50, 16)
        computer.beep(100, 0.8)
        os.sleep(0.08)
        gpu.set(18, 1, "!Kernel Panic!")
        os.sleep(0.08)
        gpu.set(16, 2, "Your Computer Has")
        os.sleep(0.08)
        gpu.set(19, 3, "Been Crashed")
        os.sleep(0.08)
        gpu.set(1, 15, "Error Code: KERNEL_DID_NOT_FIND_THE_SYSTEM")

        while true do
            event.pull("touch")
        end
        
        bootloader.waitEnter()
    end
end

------------------------------------ sysinit

local err = "unknown"
local lowLevelInitializerErr

local function doLowLevel(lowLevelInitializer)
    if bootloader.bootfs.exists(lowLevelInitializer) and not bootloader.bootfs.isDirectory(lowLevelInitializer) then
        local code, lerr = bootloader.loadfile(lowLevelInitializer)
        if code then
            local lowLevelInitializerResult = {xpcall(code, debug.traceback)}
            if not lowLevelInitializerResult[1] then
                err = lowLevelInitializerResult[2] or "unknown"
                lowLevelInitializerErr = true
            end
        else
            err = lerr or "unknown"
            lowLevelInitializerErr = true
        end
    end
end

doLowLevel("/system/lowlevel.lua")

------------------------------------ registry

local registry = {}
local getRegistry
do
    function getRegistry()
        if require then
            local result = {pcall(require, "registry")}
            if result[1] and type(result[2]) == "table" and type(result[2].data) == "table" then
                return result[2].data
            else
                return registry
            end
        else
            return registry
        end
    end

    local function serialize(value, path)
        local local_pairs = function(tbl)
            local mt = getmetatable(tbl)
            return (mt and mt.__pairs or pairs)(tbl)
        end

        local kw = {
            ["and"] = true,
            ["break"] = true,
            ["do"] = true,
            ["else"] = true,
            ["elseif"] = true,
            ["end"] = true,
            ["false"] = true,
            ["for"] = true,
            ["function"] = true,
            ["goto"] = true,
            ["if"] = true,
            ["in"] = true,
            ["local"] = true,
            ["nil"] = true,
            ["not"] = true,
            ["or"] = true,
            ["repeat"] = true,
            ["return"] = true,
            ["then"] = true,
            ["true"] = true,
            ["until"] = true,
            ["while"] = true
        }
        local id = "^[%a_][%w_]*$"
        local ts = {}
        local result_pack = {}
        local function recurse(current_value, depth)
            local t = type(current_value)
            if t == "number" then
                if current_value ~= current_value then
                    table.insert(result_pack, "0/0")
                elseif current_value == math.huge then
                    table.insert(result_pack, "math.huge")
                elseif current_value == -math.huge then
                    table.insert(result_pack, "-math.huge")
                else
                    table.insert(result_pack, tostring(current_value))
                end
            elseif t == "string" then
                table.insert(result_pack, (string.format("%q", current_value):gsub("\\\n", "\\n")))
            elseif
                t == "nil" or t == "boolean" or pretty and (t ~= "table" or (getmetatable(current_value) or {}).__tostring)
             then
                table.insert(result_pack, tostring(current_value))
            elseif t == "table" then
                if ts[current_value] then
                    error("tables with cycles are not supported")
                end
                ts[current_value] = true
                local f = table.pack(local_pairs(current_value))
                local i = 1
                local first = true
                table.insert(result_pack, "{")
                for k, v in table.unpack(f) do
                    if not first then
                        table.insert(result_pack, ",")
                        if pretty then
                            table.insert(result_pack, "\n" .. string.rep(" ", depth))
                        end
                    end
                    first = nil
                    local tk = type(k)
                    if tk == "number" and k == i then
                        i = i + 1
                        recurse(v, depth + 1)
                    else
                        if tk == "string" and not kw[k] and string.match(k, id) then
                            table.insert(result_pack, k)
                        else
                            table.insert(result_pack, "[")
                            recurse(k, depth + 1)
                            table.insert(result_pack, "]")
                        end
                        table.insert(result_pack, "=")
                        recurse(v, depth + 1)
                    end
                end
                ts[current_value] = nil -- allow writing same table more than once
                table.insert(result_pack, "}")
            else
                error("unsupported type: " .. t)
            end
        end
        recurse(value, 1)
        pcall(bootloader.writeFile, bootloader.bootfs, path, table.concat(result_pack))
    end

    local function unserialize(path)
        local content = bootloader.readFile(bootloader.bootfs, path)
        if content then
            local code = load("return " .. content, "=unserialize", "t", {math={huge=math.huge}})
            if code then
                local result = {pcall(code)}
                if result[1] and type(result[2]) == "table" then
                    return result[2]
                end
            end
        end
    end

    local registryPath = "/data/registry.dat"
    local mainRegistryPath = bootloader.find("registry.dat", true)

    if mainRegistryPath and not bootloader.bootfs.exists(registryPath) then
        pcall(bootloader.bootfs.makeDirectory, "/data")
        pcall(bootloader.writeFile, bootloader.bootfs, registryPath, bootloader.readFile(bootloader.bootfs, mainRegistryPath))
    end

    if bootloader.bootfs.exists(registryPath) then
        local reg = unserialize(registryPath)
        local mainReg = mainRegistryPath and unserialize(mainRegistryPath)
        if reg then
            if mainReg then
                local newKeysFound
                for key, value in pairs(mainReg) do
                    if reg[key] == nil then
                        reg[key] = value
                        newKeysFound = true
                    end
                end
                if newKeysFound then
                    serialize(reg, registryPath)
                end
            end
            registry = reg
        end
    end
end



------------------------------------ boot splash

do
    local gpu = component.proxy(component.list("gpu")() or "")
    if gpu and not getRegistry().disableLogo then
        for screen in component.list("screen") do
            bootloader.initScreen(gpu, screen)
        end
    end

    local logoPath = bootloader.find("logo.lua")
    local logoenv = {gpu = gpu, unicode = unicode, computer = computer, component = component, bootloader = bootloader}
    local logo = bootloader.loadfile(logoPath, nil, setmetatable(logoenv, {__index = _G}))
    
    function bootloader.bootSplash(text)
        if not logo or not gpu or getRegistry().disableLogo then return end
        logoenv.text = text
        for screen in component.list("screen") do
            logoenv.screen = screen
            logo()
        end
    end

    function bootloader.waitEnter()
        if not logo or not gpu or getRegistry().disableLogo then return end
        while true do
            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 28 then
                    return
                end
            end
        end
    end
end

------------------------------------ recovery

if not params.noRecovery and (params.forceRecovery or not getRegistry().disableRecovery) then
    local gpu = component.proxy(component.list("gpu")() or "")
    local defaultScreen = component.list("screen")()
    if gpu and defaultScreen then
        local recoveryScreen, playerNickname
        if params.forceRecovery then
            recoveryScreen = params.forceRecovery
            playerNickname = ""

            if #recoveryScreen == 0 then
                recoveryScreen = defaultScreen
            end
        else
            bootloader.bootSplash("Press R to open recovery mode")
            local startTime = computer.uptime()
            while computer.uptime() - startTime <= 1 do
                local eventData = {computer.pullSignal(0.1)}
                if eventData[1] == "key_down" and eventData[4] == 19 then
                    for address in component.list("screen") do
                        local keyboards = component.invoke(address, "getKeyboards")
                        for i, keyboard in ipairs(keyboards) do
                            if keyboard == eventData[2] then
                                recoveryScreen = address
                                playerNickname = eventData[6]
                                goto exit
                            end
                        end
                    end
                end
            end
            ::exit::
        end

        if recoveryScreen then
            bootloader.bootSplash("RECOVERY MODE")

            local recoveryPath = bootloader.find("recovery.lua")
            if recoveryPath then
                if getRegistry().disableLogo then --если лого отключено, то экран не был инициализирован ранее, а значит его нада инициализировать сейчас
                    bootloader.initScreen(gpu, recoveryScreen)
                end
                
                local env = bootloader.createEnv()
                env.bootloader = bootloader
                assert(xpcall(assert(bootloader.loadfile(recoveryPath, nil, env)), debug.traceback, recoveryScreen, playerNickname, params))
                computer.shutdown("fast")
            else
                bootloader.bootSplash("failed to open recovery. press enter to continue")
                bootloader.waitEnter()
            end
        end
    end
end

------------------------------------ bootstrap

bootloader.bootSplash("Booting...")
bootloader.yield()

if not lowLevelInitializerErr then
    doLowLevel("/OpenKernel_startup.lua") --может использоваться для запуска обновления системы

    if not lowLevelInitializerErr then
        local bootstrapResult = {xpcall(bootloader.bootstrap, debug.traceback)}
        bootloader.yield()

        if bootstrapResult[1] then
            local shellResult = {xpcall(bootloader.runShell, debug.traceback, bootloader.defaultShellPath)}
            bootloader.yield()

            if not shellResult[1] then
                err = tostring(shellResult[2])
            end
        else
            err = tostring(bootstrapResult[2])
        end
    end
end

------------------------------------ log error

local log_ok
if require and pcall then
    local function local_require(name)
        local result = {pcall(require, name)}
        if result[1] and type(result[2]) == "table" then
            return result[2]
        end
    end
    local event = local_require("event")
    if event and event.errLog then
        log_ok = pcall(event.errLog, "global error: " .. tostring(err))
    end
end

------------------------------------ error output

if log_ok and not getRegistry().disableAutoReboot then --если удалось записать log то комп перезагрузиться, а если не удалось то передаст ошибку в bios
    local component = require("component")
    local gpu = component.gpu
    local computer = require("computer")
    local event = require("event")
    
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
      gpu.fill(1, 1, 50, 16, " ")
    gpu.setResolution(50, 16)
    computer.beep(100, 0.8)
    os.sleep(0.08)
    gpu.set(18, 1, "!Kernel Panic!")
    os.sleep(0.08)
    gpu.set(16, 2, "Your Computer Has")
    os.sleep(0.08)
    gpu.set(19, 3, "Been Crashed")
    os.sleep(0.08)
    gpu.set(1, 15, "Error Code: KERNEL_FAILED_INIT_SYSTEM")

    while true do
        event.pull("touch")
    end
end
    local component = require("component")
    local gpu = component.gpu
    local computer = require("computer")
    local event = require("event")

      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
      gpu.fill(1, 1, 50, 16, " ")
        gpu.setResolution(50, 16)
    computer.beep(100, 0.8)
    os.sleep(0.08)
    gpu.set(18, 1, "!Kernel Panic!")
    os.sleep(0.08)
    gpu.set(16, 2, "Your Computer Has")
    os.sleep(0.08)
    gpu.set(19, 3, "Been Crashed")
    os.sleep(0.08)
    gpu.set(1, 15, "Error Code: KERNEL_FAILED_INIT_SYSTEM")

while true do
    event.pull("touch")
end
