local deviceinfo = computer.getDeviceInfo()

local function getBestGPUOrScreenAddress(componentType) --функцию подарил игорь тимофеев
    local bestWidth, bestAddress = 0

    for address in component.list(componentType) do
        local width = tonumber(deviceinfo[address].width)
        if component.type(componentType) == "screen" then
            if #component.invoke(address, "getKeyboards") > 0 then --экраны с кравиатурами имеют больший приоритет
                width = width + 10
            end
        end

        if width > bestWidth then
            bestAddress, bestWidth = address, width
        end
    end

    return bestAddress
end

local gpu = component.proxy((computer.getBootGpu and computer.getBootGpu() or getBestGPUOrScreenAddress("gpu")) or error("no gpu found", 0))
local screen = (computer.getBootScreen and computer.getBootScreen() or getBestGPUOrScreenAddress("screen")) or error("no screen found", 0)
gpu.bind(screen)
local keyboards = component.invoke(screen, "getKeyboards")
local rx, ry = gpu.getResolution()
local depth = gpu.getDepth()

local drive = component.proxy(computer.getBootAddress())
local internet = component.proxy(component.list("internet")() or "")
local installerVersion = "AmijaOS Setup"

------------------------------------

local function segments(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
        local current, up = part:find("^%.?%.$")
        if current then
            if up == 2 then
                table.remove(parts)
            end
        else
            table.insert(parts, part)
        end
    end
    return parts
end

local function canonical(path)
    local result = table.concat(segments(path), "/")
    if unicode.sub(path, 1, 1) == "/" then
        return "/" .. result
    else
        return result
    end
end

local function fs_path(path)
    local parts = segments(path)
    local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
    if unicode.sub(path, 1, 1) == "/" and unicode.sub(result, 1, 1) ~= "/" then
        return canonical("/" .. result)
    else
        return canonical(result)
    end
end

local function fs_concat(...)
    local set = table.pack(...)
    for index, value in ipairs(set) do
        checkArg(index, value, "string")
    end
    return canonical(table.concat(set, "/"))
end

local function cloneTo(folder, targetPath, targetDrive)
    for _, lpath in ipairs(drive.list(folder) or {}) do
        local full_path = fs_concat(folder, lpath)
        local target_path = fs_concat(targetPath, lpath)

        if drive.isDirectory(full_path) then
            cloneTo(full_path, target_path, targetDrive)
        else
            local file = drive.open(full_path, "rb")
            local buffer = ""
            repeat
                local data = drive.read(file, math.huge)
                buffer = buffer .. (data or "")
            until not data
            drive.close(file)

            targetDrive.makeDirectory(fs_path(target_path))
            local file = targetDrive.open(target_path, "wb")
            targetDrive.write(file, buffer)
            targetDrive.close(file)
        end
    end
end

------------------------------------

local function isValideKeyboard(address)
    for i, v in ipairs(keyboards) do
        if v == address then
            return true
        end
    end
end

local function getInternetFile(url)
    local handle, data, result, reason = internet.request(url), ""
    if handle then
        while true do
            result, reason = handle.read(math.huge) 
            if result then
                data = data .. result
            else
                handle.close()
                
                if reason then
                    return nil, reason
                else
                    return data
                end
            end
        end
    else
        return nil, "unvalid address"
    end
end

local function split(str, sep)
    local parts, count, i = {}, 1, 1
    while 1 do
        if i > #str then break end
        local char = str:sub(i, i - 1 + #sep)
        if not parts[count] then parts[count] = "" end
        if char == sep then
            count = count + 1
            i = i + #sep
        else
            parts[count] = parts[count] .. str:sub(i, i)
            i = i + 1
        end
    end
    if str:sub(#str - (#sep - 1), #str) == sep then table.insert(parts, "") end
    return parts
end

------------------------------------

local function invert()
    gpu.setBackground(gpu.setForeground(gpu.getBackground()))
end

local function setText(str, posX, posY)
    gpu.set((posX or 0) + math.floor(rx / 2 - ((#str - 1) / 2) + .5), posY or math.floor(ry / 2 + .5), str)
end

local function clear()
    gpu.setBackground(0)
    gpu.setForeground(-1)
    gpu.fill(1, 1, rx, ry, " ")
end

local function menu(label, strs, selected)
    local selected = selected or 1
    local function redraw()
        clear()
        invert()
        setText(label, nil, 1)
        invert()
        for i, v in ipairs(strs) do
            if selected == i then invert() end
            setText(v, nil, i + 1)
            if selected == i then invert() end
        end
    end
    redraw()
    while true do
        local eventData = {computer.pullSignal()}
        if isValideKeyboard(eventData[2] or "") then
            if eventData[1] == "key_down" then
                if eventData[4] == 208 then
                    if selected < #strs then
                        selected = selected + 1
                        redraw()
                    end
                elseif eventData[4] == 200 then
                    if selected > 1 then
                        selected = selected - 1
                        redraw()
                    end
                elseif eventData[4] == 28 then
                    return selected
                end
            end
        end
    end
end

local function status(text)
    clear()
    setText(text)
end

------------------------------------

local function getInstallDisk()
    local strs = {}
    local addresses = {}

    for address in component.list("filesystem") do
        if not component.invoke(address, "isReadOnly") and address ~= drive.address and address ~= computer.tmpAddress() then
            table.insert(strs, address:sub(1, 4) .. ":" .. (component.invoke(address, "getLabel") or "noLabel"))
            table.insert(addresses, address)
        end
    end
    table.insert(strs, "back")
    return component.proxy(addresses[menu("select disk", strs, 1)] or "")
end

local function selectDist(dists)
    local strs = {}
    local funcs = {}

    for i, v in ipairs(dists) do
        table.insert(strs, v.name)
        table.insert(funcs, v.call)
    end
    table.insert(strs, "back")

    local num
    while true do
        num = menu("select distribution", strs, num)
        if funcs[num] then
            local proxy = getInstallDisk()
            if proxy then
                if menu("comfirm? the disk will be cleared!", {"NO", "Yes"}) == 2 then
                    status("Please Wait")
                    proxy.remove("/")
                    local label = strs[num]
                    if label == "core only" then
                        label = "OpenKernel"
                    end
                    proxy.setLabel(label)
                    funcs[num](proxy)
                    if computer.setBootAddress then computer.setBootAddress(proxy.address) end
                    if computer.setBootFile then computer.setBootFile("/kernel.lua") end
                    computer.shutdown("fast")
                end
            end
        else
            break
        end
    end
end

local function offline()
    local dists = {}
    for i, v in ipairs(drive.list("/distributions") or {}) do
        table.insert(dists, {name = v:sub(1, #v - 1), call = function(proxy)
            cloneTo("/core", "/", proxy)
            cloneTo("/distributions/" .. v, "/", proxy)
        end})
    end
    table.insert(dists, {name = "core only", call = function(proxy)
        cloneTo("/core", "/", proxy)
    end})
    selectDist(dists)
end

local function download(url, targetDrive)
    local filelist = split(assert(getInternetFile(url .. "/ins/list.txt")), "\n")

    for i, path in ipairs(filelist) do
        if path ~= "" then
            local full_url = url .. path
            local data = assert(getInternetFile(full_url))

            targetDrive.makeDirectory(fs_path(path))
            local file = targetDrive.open(path, "wb")
            targetDrive.write(file, data)
            targetDrive.close(file)
        end
    end
end

local function online()
    local dists = {}

    local filelist = split(assert(getInternetFile("https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/ins/list.txt")), split(assert(getInternetFile("https://raw.githubusercontent.com/matvey-mayner/AmijaOS/main/Setup/filelist.txt")), "\n")
    for i, v in ipairs(filelist) do
        if v ~= "" then
            local url, name = table.unpack(split(v, ";"))
            table.insert(dists, {name = name, call = function(proxy)
                download("https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main", proxy)
                download("https://raw.githubusercontent.com/matvey-mayner/AmijaOS/main", proxy)
                download(url, proxy)
            end})
        end
    end

    table.insert(dists, {name = "AmijaOS", call = function(proxy)
        download("https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main", proxy)
        download("https://raw.githubusercontent.com/matvey-mayner/AmijaOS/main", proxy)
    end})

    selectDist(dists)
end

local strs = {"shutdown"}
local funcs = {computer.shutdown}

if internet then
    table.insert(strs, 1, "online mode")
    table.insert(funcs, 1, online)
end

if drive.exists("/core") then
    table.insert(strs, 1, "offline mode")
    table.insert(funcs, 1, offline)
end

local num
while true do
    num = menu(installerVersion, strs, num)
    funcs[num]()
end
