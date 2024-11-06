local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer = require("computer")

StartType = "close"

gpu.setBackground(0x000000)
gpu.fill(1, 2, 30, 25, " ")
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(31, 2, 50, 25, " ")

-- Version 1.7
local component = component
local computer = computer
local fs = component.proxy(computer.getBootAddress())
local gpu = component.proxy(component.list("gpu")())
local screen = component.list("screen")()
gpu.bind(screen)
gpu.setResolution(50, 16)  -- Set screen resolution

local currentDir = "/"
local hostapt = "http://83.25.177.183/package-host/packages/"
local sysupdate = "https://raw.githubusercontent.com/matvey-mayner/Jinto/main/system/mainsys.lua"

local function clear()
    gpu.fill(1, 1, 50, 16, " ")
end

local function write(x, y, text)
    gpu.set(x, y, text)
end

local function readInput(prompt)
    write(1, 16, prompt)
    local input = ""
    while true do
        local event, _, char = computer.pullSignal()
        if event == "key_down" then
            if char == 13 then
                gpu.fill(#prompt + 1, 16, 50 - #prompt, 1, " ")
                break
            elseif char == 8 then
                if #input > 0 then
                    input = input:sub(1, -2)
                    write(#input + #prompt, 16, " ")
                end
            else
                input = input .. string.char(char)
                write(#input + #prompt, 16, string.char(char))
            end
        end
    end
    return input
end

local function resolvePath(path)
    if path:sub(1, 1) == "/" then
        return path
    else
        return currentDir .. path
    end
end

local function listDisks()
    local y = 2
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy then
            write(1, y, "Disk: " .. address:sub(1, 8))
            y = y + 1
            if type(proxy.list) == "function" then
                for file in proxy.list("/") do
                    write(1, y, " - " .. file)
                    y = y + 1
                end
            else
                write(1, y, "Error: `list` is not a function")
                y = y + 1
            end
        else
            write(1, y, "Error: Unable to access filesystem at " .. address:sub(1, 8))
            y = y + 1
        end
    end
end

local function ls()
    if fs.isDirectory(currentDir) then
        local items = fs.list(currentDir)  -- Получаем список файлов как таблицу
        local y = 2
        for _, item in ipairs(items) do  -- Проходим по таблице
            write(1, y, item)
            y = y + 1
        end
    else
        write(1, 15, "Error: Not a directory")
    end
end

local function cd(path)
    local newPath = resolvePath(path)
    if fs.isDirectory(newPath) then
        currentDir = newPath
        if currentDir:sub(-1) ~= "/" then
            currentDir = currentDir .. "/"
        end
    else
        write(1, 15, "Error: Directory not found")
    end
end

local function rm(path)
    local fullPath = resolvePath(path)
    if fs.exists(fullPath) then
        fs.remove(fullPath)
    else
        write(1, 15, "Error: File not found")
    end
end

local function title()
    write(1, 1, "Welcome To Jinto!")
end

local function apt(url, path)

    local internet_address = component.list("internet")()
    if not internet_address then
        write(1, 15, "Error: Internet card not found\n")
        return
    end
    
    local inet = component.proxy(internet_address)
    
    local handle, err = inet.request(url.. ".lua")
    if not handle then
        write(1, 15, "Error: " .. tostring(err) .. "\n")
        return
    end

    local filename = url:match("/([^/]+)$")
    if not filename then
        write(1, 15, "Error: Could not determine filename from URL\n")
        return
    end
    filename = path.. filename
    local file = fs.open(filename, "w")
    if not file then
        write(1, 15, "Error opening file\n")
        return
    end

    local totalBytes = 0
    while true do
        local chunk = handle.read(1024)  -- Читаем 1024 байта за раз
        if not chunk then break end  -- Если нет больше данных, выходим из цикла
        fs.write(file, chunk)
        totalBytes = totalBytes + #chunk
    end
    
    fs.close(file)
    handle.close()  -- Закрываем поток после использования
    write(1, 1, "Downloaded: " .. filename .. " (" .. totalBytes .. " bytes)\n")
end

local function mkdir(path)
    local fullPath = resolvePath(path)
    if not fs.exists(fullPath) then
        fs.makeDirectory(fullPath)
    else
        write(1, 15, "Error: Directory already exists")
    end
end

local function shutdown()
    computer.shutdown()
end

local function reboot()
    computer.shutdown(true)
end

local function cat(path)
    local fullPath = resolvePath(path)
    if fs.exists(fullPath) then
        local handle = fs.open(fullPath, "r")
        local y = 2
        repeat
            local data = fs.read(handle, 64)
            if data then
                write(1, y, data)
                y = y + 1
            end
        until not data
        fs.close(handle)
    else
        write(1, 15, "Error: File not found")
    end
end

local function edit(path)
    local fullPath = resolvePath(path)
    local lines = {}
    
    if fs.exists(fullPath) then
        local handle = fs.open(fullPath, "r")
        repeat
            local line = fs.read(handle, 64)
            if line then
                table.insert(lines, line)
            end
        until not line
        fs.close(handle)
    else
        write(1, 15, "Creating new file: " .. path)
    end

    clear()
    write(1, 1, "Editing: " .. path)
    write(1, 2, "Use arrow keys to navigate. Type to edit.")
    write(1, 3, "Press Enter to insert new line. CTRL+S to save and exit.")

    local cursorX, cursorY = 1, 5
    local currentLine = 1

    local function refreshScreen()
        clear()
        write(1, 1, "Editing: " .. path)
        for i = 1, math.min(#lines, 10) do
            write(1, i + 4, lines[i] or "")
        end
        gpu.set(cursorX, cursorY, "_")
    end

    refreshScreen()

    while true do
        local event, _, char, code = computer.pullSignal()

        if event == "key_down" then
            if char == 13 then  -- Enter
                table.insert(lines, currentLine + 1, "")
                currentLine = currentLine + 1
                cursorX, cursorY = 1, math.min(cursorY + 1, 14)
            elseif char == 8 then  -- Backspace
                local line = lines[currentLine]
                if #line > 0 then
                    lines[currentLine] = line:sub(1, -2)
                end
            elseif code == 200 then  -- Up arrow
                if currentLine > 1 then
                    currentLine = currentLine - 1
                    cursorY = cursorY - 1
                end
            elseif code == 208 then  -- Down arrow
                if currentLine < #lines then
                    currentLine = currentLine + 1
                    cursorY = cursorY + 1
                end
            elseif code == 203 then  -- Left arrow
                if cursorX > 1 then
                    cursorX = cursorX - 1
                end
            elseif code == 205 then  -- Right arrow
                cursorX = cursorX + 1
            elseif code == 31 then  -- CTRL+S (save)
                fs.remove(fullPath)
                local handle = fs.open(fullPath, "w")
                for _, line in ipairs(lines) do
                    fs.write(handle, line .. "\n")
                end
                fs.close(handle)
                write(1, 15, "File saved.")
                break
            else
                lines[currentLine] = (lines[currentLine] or "") .. string.char(char)
                cursorX = cursorX + 1
            end
            refreshScreen()
        end
    end
end

local function help()
    clear()
    title()
    write(1, 2, "ls = list")
    write(1, 3, "run = starting app")
    write(1, 4, "cls = clear screen")
    write(1, 5, "cd = move to directory")
    write(1, 6, "cat = reading file")
    write(1, 7, "rm = removing file")
    write(1, 8, "edit = editing file")
    write(1, 9, "mkdir = making directory")
    write(1, 10, "apt install = installing file")
    write(1, 11, "update = update system")
    write(1, 12, "apt set = set apt host")
    write(1, 13, "help = commands list")
end

local function run(path)
    local fullPath = resolvePath(path)
    if fs.exists(fullPath) then
        local handle, err = fs.open(fullPath, "r")
        if not handle then
            write(1, 15, "Error: Could not open file - " .. err .. "\n")
            return
        end

        local content = ""
        repeat
            local chunk = fs.read(handle, math.huge)  -- Читаем весь файл за один раз
            if chunk then
                content = content .. chunk
            end
        until not chunk
        fs.close(handle)

        local program, loadErr = load(content, "=" .. path)
        if program then
            local success, execErr = pcall(program)
            if not success then
                write(1, 15, "Execution error: " .. execErr .. "\n")
            end
        else
            write(1, 15, "Load error: " .. loadErr .. "\n")
        end
    else
        write(1, 15, "Error: File not found\n")
    end
end

local function executeCommand(command)
    local args = {}
    for word in command:gmatch("%S+") do
        table.insert(args, word)
    end

    if args[1] == "cls" then
        clear()
        title()
    elseif args[1] == "ls" then
        if args[2] == "disks" then
            clear()
            title()
            listDisks()
        else
            clear()
            title()
            ls()
        end
    elseif args[1] == "cd" and args[2] then
        clear()
        title()
        cd(args[2])
    elseif args[1] == "rm" and args[2] then
        rm(args[2])
    elseif args[1] == "mkdir" and args[2] then
        mkdir(args[2])
    elseif args[1] == "shutdown" then
        shutdown()
    elseif args[1] == "reboot" then
        reboot()
    elseif args[1] == "cat" and args[2] then
        cat(args[2])
    elseif args[1] == "edit" and args[2] then
        edit(args[2])
    elseif args[1] == "run" and args[2] then
        run(args[2])
    elseif args[1] == "apt" and args[3] then
        if args[2] == "install" and args[3] then
            apt(hostapt.. args[3], "/system/bin/")
        elseif args[2] == "set" and args[3] then
            hostapt = args[3]
        end
    elseif args[1] == "update" then
        apt(sysupdate.. "/system/")
        computer.shutdown(true)
        elseif args[1] == "help" then
        help()
    else
        run("/system/bin/".. command)
    end
end

local function shell()
    clear()
    title()

    while true do
        write(1, 16, "> ")
        local command = readInput(currentDir .. "> ")
        executeCommand(command)
    end
end

shell()
