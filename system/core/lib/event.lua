local computer = require("computer")
local component = require("component")
local fs = require("filesystem")
local package = require("package")

local event = {}
event.minTime = 0 --минимальное время прирывания, можно увеличить, это вызовет подения производительности но уменьшет энергопотребления
event.listens = {}

------------------------------------------------------------------------ functions

local function tableInsert(tbl, value) --кастомный insert с возвращения значения
    for i = 1, #tbl + 1 do
        if not tbl[i] then
            tbl[i] = value
            return i
        end
    end
end

local function runThreads(eventData)
    local thread = package.get("thread")
    if thread then
        local function find(tbl)
            local parsetbl = tbl.childs
            if not parsetbl then parsetbl = tbl end
            for i = #parsetbl, 1, -1 do
                local v = parsetbl[i]
                v:status()
                if v.dead or not v.thread or coroutine.status(v.thread) == "dead" then
                    table.remove(parsetbl, i)
                    v.thread = nil
                    v.dead = true
                elseif v.enable then --если поток спит или умер то его потомки так-же не будут работать
                    v.out = {thread.xpcall(v.thread, table.unpack(v.args or eventData))}
                    if not v.out[1] then
                        event.errLog("thread error: " .. tostring(v.out[2] or "unknown") .. "\n" .. tostring(v.out[3] or "unknown"))
                    end

                    v.args = nil
                    find(v)
                end
            end
        end
        find(thread.threads)
    end
end

local isListen = false
local function runCallback(isTimer, func, index, ...)
    isListen = true
    local ok, err = xpcall(func, debug.traceback, ...)
    isListen = false

    if ok then
        if err == false then --таймер/слушатель хочет отключиться
            event.listens[index].killed = true
            event.listens[index] = nil
        end
    else
        event.errLog((isTimer and "timer" or "listen") .. " error: " .. tostring(err or "unknown"))
    end
end

------------------------------------------------------------------------ functions

function event.stub()
    event.push("stub")
end

function event.errLog(data)
    require("logs").log(data)
end

function event.sleep(waitTime)
    waitTime = waitTime or 0.1

    local startTime = computer.uptime()
    repeat
        computer.pullSignal(waitTime - (computer.uptime() - startTime))
    until computer.uptime() - startTime >= waitTime
end

function event.yield()
    computer.pullSignal(event.minTime)
end

function event.events(timeout, types, maxcount) --получает эвенты пока сыпуться
    timeout = timeout or 0.1
    local eventList = {}
    local lastEventTime = computer.uptime()
    while true do
        local ctime = computer.uptime()
        local eventData = {computer.pullSignal(timeout)}
        if #eventData > 0 and (not types or types[eventData[1]]) then
            lastEventTime = ctime
            table.insert(eventList, eventData)
            if maxcount and #eventList >= maxcount then
                break
            end
        elseif ctime - lastEventTime > timeout then
            break
        end
    end
    return eventList
end

function event.wait() --ждать то тех пор пока твой поток не убьют
    event.sleep(math.huge)
end

function event.listen(eventType, func, th)
    checkArg(1, eventType, "string", "nil")
    checkArg(2, func, "function")
    return tableInsert(event.listens, {th = th, eventType = eventType, func = func, type = true}) --нет класический table.insert не подайдет, так как он не дает понять, нуда вставил значения
end

function event.timer(time, func, times, th)
    checkArg(1, time, "number")
    checkArg(2, func, "function")
    checkArg(3, times, "number", "nil")
    return tableInsert(event.listens, {th = th, time = time, func = func, times = times or 1, lastTime = computer.uptime(), type = false})
end

function event.cancel(num)
    checkArg(1, num, "number")

    local ok = not not event.listens[num]
    if ok then
        event.listens[num].killed = true
        event.listens[num] = nil
    end
    return ok
end

function event.pull(waitTime, ...) --реализует фильтер
    local filters = table.pack(...)

    if type(waitTime) == "string" then
        table.insert(filters, 1, waitTime)
        filters.n = filters.n + 1
        waitTime = math.huge
    elseif not waitTime then
        waitTime = math.huge
    end

    if filters.n == 0 then
        return computer.pullSignal(waitTime)
    end
    
    local startTime = computer.uptime()
    while true do
        local ltime = waitTime - (computer.uptime() - startTime)
        if ltime <= 0 then break end
        local eventData = {computer.pullSignal(ltime)}

        local ok = true
        for i = 1, filters.n do
            local value = filters[i]
            if value and value ~= eventData[i] then
                ok = false
                break
            end
        end

        if ok then
            return table.unpack(eventData)
        end
    end
end

------------------------------------------------------------------------ custom queue

local remove = table.remove
local insert = table.insert
local unpack = table.unpack

local raw_computer_pullSignal = computer.pullSignal
local customQueue = {}

local function computer_pullSignal(...)
    if #customQueue == 0 then
        return raw_computer_pullSignal(...)
    else
        return unpack(remove(customQueue, 1))
    end
end

function computer.pushSignal(...)
    insert(customQueue, {...})
end

------------------------------------------------------------------------ hyper methods

--имеет самый самый высокий приоритет из возможных
--не может быть как либо удален до перезагрузки
--вызываеться при каждом завершении pullSignal даже если события не пришло
--ошибки в функции переданой в hyperListen будут переданы в вызвавщий pullSignal
function event.hyperListen(func)
    checkArg(1, func, "function")
    local pullSignal = computer_pullSignal
    local unpack = table.unpack
    computer_pullSignal = function (time)
        local eventData = {pullSignal(time)}
        func(unpack(eventData))
        return unpack(eventData)
    end
end

function event.hyperTimer(func)
    checkArg(1, func, "function")
    local pullSignal = computer_pullSignal
    computer_pullSignal = function (time)
        func()
        return pullSignal(time)
    end
end

function event.hyperHook(func)
    checkArg(1, func, "function")
    local pullSignal = computer_pullSignal
    computer_pullSignal = function (time)
        return func(pullSignal(time))
    end
end

function event.hyperCustom(func)
    checkArg(1, func, "function")
    local pullSignal = computer_pullSignal
    computer_pullSignal = function (time)
        return func(pullSignal, time)
    end
end

------------------------------------------------------------------------ custom pullSignal

function computer.pullSignal(waitTime) --кастомный pullSignal для работы background процессов
    if isListen then
        error("cannot use the pullSignal in the listener", 2)
    end

    waitTime = waitTime or math.huge
    if waitTime < event.minTime then
        waitTime = event.minTime
    end

    local thread = package.get("thread")
    local current
    if thread then
        current = thread.current()
    end

    local startTime = computer.uptime()
    while true do
        local realWaitTime = waitTime - (computer.uptime() - startTime)
        local isEnd = realWaitTime <= 0

        for k, v in pairs(event.listens) do --очистка от дохлых таймеров и слушателей
            if v.killed or (v.th and v.th:status() == "dead") then
                v.killed = true
                event.listens[k] = nil
            end
        end

        if thread then
            realWaitTime = event.minTime
        else
            --поиск времени до первого таймера, что обязательно на него успеть
            for k, v in pairs(event.listens) do --нет ipairs неподайдет, так могут быть дырки
                if not v.type and not v.killed and v.th == current then
                    local timerTime = v.time - (computer.uptime() - v.lastTime)
                    if timerTime < realWaitTime then
                        realWaitTime = timerTime
                    end
                end
            end

            if realWaitTime < event.minTime then --если время ожидания получилось меньше минимального времени то ждать минимальное(да таймеры будут плыть)
                realWaitTime = event.minTime
            end
        end

        local eventData
        if current then
            eventData = {coroutine.yield()}
        else
            eventData = {computer_pullSignal(realWaitTime)} --обязательно повисеть в pullSignal
            if not isListen then
                runThreads(eventData)
            end
        end

        local isEvent = #eventData > 0
        for k, v in pairs(event.listens) do --таймеры. нет ipairs неподайдет, там могут быть дырки
            if not v.type and not v.killed and v.th == current then
                if not v.th or v.th:status() == "running" then
                    local uptime = computer.uptime() 
                    if uptime - v.lastTime >= v.time then
                        v.lastTime = uptime --ДО выполнения функции ресатаем таймер, чтобы тайминги не поплывали при долгих функциях
                        if v.times <= 0 then
                            v.killed = true
                            event.listens[k] = nil
                        else
                            runCallback(true, v.func, k)
                            v.times = v.times - 1
                            if v.times <= 0 then
                                v.killed = true
                                event.listens[k] = nil
                            end
                        end
                    end
                elseif v.th:status() == "dead" then
                    v.killed = true
                    event.listens[k] = nil
                end
            elseif isEvent and v.type and not v.killed and v.th == current then
                if not v.th or v.th:status() == "running" then
                    if not v.eventType or v.eventType == eventData[1] then
                        runCallback(false, v.func, k, table.unpack(eventData))
                    end
                elseif v.th:status() == "dead" then
                    v.killed = true
                    event.listens[k] = nil
                end
            end
        end

        if isEvent then
            return table.unpack(eventData)
        elseif isEnd then
            break
        end
    end
end

------------------------------------------------------------------------ shutdown processing

local shutdownHandlers = {
    [function ()
        local gpu = component.getReal("gpu", true)

        if gpu then
            local vcomponent = require("vcomponent")
            for screen in component.list("screen") do
                if not vcomponent.isVirtual(screen) then
                    if gpu.getScreen() ~= screen then gpu.bind(screen, false) end
                    if gpu.setActiveBuffer then gpu.setActiveBuffer(0) end
                    gpu.setDepth(1)
                    gpu.setDepth(gpu.maxDepth())
                    gpu.setBackground(0)
                    gpu.setForeground(0xFFFFFF)
                    gpu.setResolution(50, 16)
                    gpu.fill(1, 1, 50, 16, " ")
                end
            end
        end
    end] = true
}

function event.addShutdownHandler(func)
    shutdownHandlers[func] = true
end

function event.delShutdownHandler(func)
    shutdownHandlers[func] = nil
end

local shutdown = computer.shutdown
function computer.shutdown(mode)
    if mode == "recovery" then
        local graphic = package.get("graphic")
        if graphic then
            fs.writeFile("/tmp/bootloader/recovery", graphic.lastScreen or "")
        else
            fs.writeFile("/tmp/bootloader/recovery", "")
        end
    elseif mode == "fast" then
        fs.writeFile("/tmp/bootloader/noRecovery", "")
    elseif mode == "faster" then
        mode = "fast"
    end

    local logs = require("logs")
    for handler in pairs(shutdownHandlers) do
        logs.checkWithTag("shutdown handler error", pcall(handler))
    end
    pcall(shutdown, mode)
    event.wait()
end

os.sleep = event.sleep
event.push = computer.pushSignal
return event