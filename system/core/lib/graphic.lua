local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local event = require("event")
local package = require("package")
local colors = require("colors")
local cache = require("cache")
local lastinfo = require("lastinfo")
local clipboardlib = require("clipboard")

local isSyntaxInstalled = package.isInstalled("syntax")
local isVGpuInstalled = package.isInstalled("vgpu")

------------------------------------

local graphic = {}
graphic.colorAutoFormat = true --рисует псевдографикой на первом тире оттенки серого
graphic.allowHardwareBuffer = false
graphic.allowSoftwareBuffer = false

graphic.screensBuffers = {}
graphic.updated = {}
graphic.windows = setmetatable({}, {__mode = "v"})
graphic.inputHistory = {}

graphic.cursorChar = "|"
graphic.hideChar = "*"
graphic.cursorColor = nil
graphic.selectColor = nil
graphic.selectColorFore = nil
graphic.defaultInputForeground = nil
graphic.defaultInputBackground = nil
graphic.fakePalette = nil

graphic.gpuPrivateList = {} --для приватизации видеокарт, дабы избежать "кражи" другими процессами, добовляйте так graphic.gpuPrivateList[gpuAddress] = true
graphic.vgpus = {}
graphic.bindCache = {}
graphic.topBindCache = {}

graphic.lastScreen = nil

local function valueCheck(value)
    if value ~= value or value == math.huge or value == -math.huge then
        value = 0
    end
    return math.round(value)
end

------------------------------------class window

local function set(self, x, y, background, foreground, text, vertical, pal)
    local gpu = graphic.findGpu(self.screen)
    if gpu then
        gpu.setBackground(background, xor(self.isPal, pal))
        gpu.setForeground(foreground, xor(self.isPal, pal))
        gpu.set(valueCheck(self.x + (x - 1)), valueCheck(self.y + (y - 1)), text, vertical)
    end

    graphic.updated[self.screen] = true
    graphic.lastScreen = self.screen
end

local function get(self, x, y)
    local gpu = graphic.findGpu(self.screen)
    if gpu then
        return gpu.get(valueCheck(self.x + (x - 1)), valueCheck(self.y + (y - 1)))
    end
end

local function fill(self, x, y, sizeX, sizeY, background, foreground, char, pal)
    local gpu = graphic.findGpu(self.screen)
    if gpu then
        gpu.setBackground(background, xor(self.isPal, pal))
        gpu.setForeground(foreground, xor(self.isPal, pal))
        gpu.fill(valueCheck(self.x + (x - 1)), valueCheck(self.y + (y - 1)), valueCheck(sizeX), valueCheck(sizeY), char)
    end

    graphic.updated[self.screen] = true
    graphic.lastScreen = self.screen
end

local function copy(self, x, y, sizeX, sizeY, offsetX, offsetY)
    local gpu = graphic.findGpu(self.screen)
    if gpu then
        gpu.copy(valueCheck(self.x + (x - 1)), valueCheck(self.y + (y - 1)), valueCheck(sizeX), valueCheck(sizeY), valueCheck(offsetX), valueCheck(offsetY))
    end

    graphic.updated[self.screen] = true
    graphic.lastScreen = self.screen
end

local function clear(self, color, pal)
    self:fill(1, 1, self.sizeX, self.sizeY, color, color, " ", pal)
end

local function setCursor(self, x, y)
    self.cursorX, self.cursorY = valueCheck(x), valueCheck(y)
end

local function getCursor(self)
    return self.cursorX, self.cursorY
end

local function write(self, data, background, foreground, autoln, pal)
    local gpu = graphic.findGpu(self.screen)

    if gpu then
        local buffer = ""
        local setX, setY = self.cursorX, self.cursorY
        local function applyBuffer()
            gpu.set(self.x + (setX - 1), self.y + (setY - 1), buffer)
            buffer = ""
            setX, setY = self.cursorX, self.cursorY
        end

        local cpal = xor(self.isPal, pal)
        gpu.setBackground(background or (cpal and colors.black or 0), cpal)
        gpu.setForeground(foreground or (cpal and colors.white or 0xFFFFFF), cpal)

        for i = 1, unicode.len(data) do
            local char = unicode.sub(data, i, i)
            local ln = autoln and self.cursorX > self.sizeX
            local function setChar()
                --gpu.set(self.x + (self.cursorX - 1), self.y + (self.cursorY - 1), char)
                buffer = buffer .. char
                self.cursorX = self.cursorX + 1
            end
            if char == "\n" or ln then
                self.cursorY = self.cursorY + 1
                self.cursorX = 1
                applyBuffer()
                if ln then
                    setChar()
                end
            else
                setChar()
            end
        end

        applyBuffer()
    end
    
    graphic.updated[self.screen] = true
    graphic.lastScreen = self.screen
end

local function uploadEvent(self, eventData)
    local newEventData
    if eventData then
        if eventData[2] == self.screen and
        (eventData[1] == "touch" or eventData[1] == "drop" or eventData[1] == "drag" or eventData[1] == "scroll") then
            local oldSelected = self.selected
            local rePosX = (eventData[3] - self.x) + 1
            local rePosY = (eventData[4] - self.y) + 1
            local crePosX = math.ceil(rePosX)
            local crePosY = math.ceil(rePosY)
            self.selected = false

            local inside = crePosX >= 1 and crePosY >= 1 and crePosX <= self.sizeX and crePosY <= self.sizeY
            if inside or self.outsideEvents then
                self.selected = true
                newEventData = {eventData[1], eventData[2], rePosX, rePosY, eventData[5], eventData[6]}
            end

            if eventData[1] == "drop" then
                self.selected = oldSelected
            end
        elseif eventData[1] == "key_down" or eventData[1] == "key_up" or eventData[1] == "clipboard" then
            if table.exists(lastinfo.keyboards[self.screen], eventData[2]) then 
                newEventData = eventData
            end
        elseif eventData[1] == "softwareInsert" then --для подключения виртуальных клавиатур
            if eventData[2] == self.screen then
                newEventData = eventData
            end
        end
    end

    newEventData = newEventData or {}
    if not self.selected then
        newEventData = {}
    end
    newEventData.windowEventData = true
    return newEventData
end

local function toRealPos(self, x, y)
    return self.x + (x - 1), self.y + (y - 1)
end

local function toFakePos(self, x, y)
    return x - (self.x - 1), y - (self.y - 1)
end

local function readNoDraw(self, x, y, sizeX, background, foreground, preStr, hidden, buffer, clickCheck, syntax)
    local createdX
    if preStr then
        createdX = x
        x = x + #preStr
        sizeX = sizeX - #preStr
    end

    local sizeY = 1
    local isMultiline = sizeY ~= 1 --пока что не работает
    local whitelist

    local maxX, maxY = self.x + (x - 1) + (sizeX - 1), self.y + (y - 1) + (sizeY - 1)
    
    local disHistory = not not hidden
    local disableClipboard = not not hidden
    local maxDataSize = math.huge

    buffer = buffer or ""
    local lastBuffer = ""
    local allowUse = not clickCheck and self.selected
    local historyIndex
    
    local gpu = graphic.findGpu(self.screen)
    local depth = gpu.getDepth()

    if depth == 1 then
        syntax = nil
    end

    local function getPalColor(pal)
        if graphic.fakePalette then
            return graphic.fakePalette[pal] or 0
        else
            return gpu.getPaletteColor(pal)
        end
    end

    local function findColor(rgb, pal, bw)
        if self.isPal and depth > 1 then
            return pal
        else
            if depth == 8 then
                return rgb
            elseif depth == 4 then
                return getPalColor(pal)
            else
                return bw
            end
        end
    end

    background = background or graphic.defaultInputBackground or findColor(0x000000, colors.black, 0x000000)
    foreground = foreground or graphic.defaultInputForeground or findColor(0xffffff, colors.white, 0xffffff)
    local cursorColor     = graphic.cursorColor     or findColor(0x00ff00, colors.lightgreen, foreground)
    local selectColor     = graphic.selectColor     or findColor(0x0000ff, colors.blue,       foreground)
    local selectColorFore = graphic.selectColorFore
    if depth == 1 and not selectColorFore then
        selectColorFore = background
    end
    
    if not selectColor then
        if self.isPal and depth > 1 then
            selectColor = colors.blue
        else
            if depth == 8 then
                selectColor = 0x0000ff
            elseif depth == 4 then
                selectColor = getPalColor(colors.blue)
            else
                selectColor = 0xffffff
                selectColorFore = 0x000000
            end
        end
    end

    local title, titleColor

    local selectFrom
    local selectTo

    local offsetX = 0
    local offsetY = 0

    local lockState = false
    local drawLock = false

    local function getBackCol(i)
        if selectFrom then
            return (i >= selectFrom and i <= selectTo) and selectColor or background
        else
            return background
        end
    end

    local function getForeCol(i, def, pal)
        if pal then
            def = getPalColor(def)
        end
        if selectFrom and selectColorFore then
            return (i >= selectFrom and i <= selectTo) and selectColorFore or def
        else
            return def
        end
    end
    
    local function redraw()
        if drawLock then
            return drawLock
        end

        local gpu = graphic.findGpu(self.screen)
        if gpu then
            local cursorPos
            local str = buffer
            if allowUse and not lockState then
                --str = str .. "\0"
                cursorPos = unicode.len(str) + 1
                local nCursorPos = cursorPos + offsetX
                while nCursorPos < 1 do
                    offsetX = offsetX + 1
                    nCursorPos = cursorPos + offsetX
                end
                while nCursorPos > sizeX do
                    offsetX = offsetX - 1
                    nCursorPos = cursorPos + offsetX
                end
            end
            str = str .. lastBuffer

            --[[
            local num = (unicode.len(str) - sizeX) + 1
            if num < 1 then num = 1 end
            str = unicode.sub(str, num, unicode.len(str))

            str = str .. newLastBuffer
            if unicode.len(str) < sizeX then
                str = str .. string.rep(" ", sizeX - unicode.len(str))
            elseif unicode.len(str) > sizeX then
                str = unicode.sub(str, 1, sizeX)
            end
            ]]

            --local newstr = {}
            --[[
            local cursorPos
            for i = 1, unicode.len(str) do
                if unicode.sub(str, i, i) == "\0" then
                    cursorPos = i
                else
                    table.insert(newstr, unicode.sub(str, i, i))
                end
            end
            ]]


            local chars = {}
            for i = 1, unicode.len(str) do
                table.insert(chars, {hidden and graphic.hideChar or unicode.sub(str, i, i), getForeCol(i, foreground), getBackCol(i)})
            end
            if syntax == "lua" and isSyntaxInstalled then
                for index, value in ipairs(require("syntax").parse(str)) do
                    local isBreak
                    for i = 1, unicode.len(value[3]) do
                        local setTo = value[5] + (i - 1)
                        if not chars[setTo] then isBreak = true break end
                        chars[setTo] = {unicode.sub(value[3], i, i), getForeCol(i, value[4], true), getBackCol(setTo)}
                    end
                    if isBreak then break end
                end
            end

            if cursorPos then
                local cursorChar = {graphic.cursorChar, getForeCol(cursorPos, cursorColor), getBackCol(cursorPos)}
                if not pcall(table.insert, chars, cursorPos, cursorChar) then
                    table.insert(chars, cursorChar)
                end
            elseif #chars == 0 and title and titleColor then
                for i = 1, unicode.len(title) do
                    table.insert(chars, {unicode.sub(title, i, i), getForeCol(i, titleColor), getBackCol(i)})
                end
            end

            -- draw
            local defXpos = (self.x + (x - 1))
            local defYpos = (self.y + (y - 1))
            local xpos = (self.x + (x - 1))
            local ypos = (self.y + (y - 1))

            gpu.setForeground(foreground, self.isPal)
            gpu.setBackground(background, self.isPal)
            gpu.fill(xpos, ypos, sizeX, sizeY, " ")
            --graphic._fill(gpu, xpos, ypos, sizeX, sizeY, background, self.isPal, foreground, self.isPal, " ")
            if createdX then
                --graphic._set(gpu, createdX, y, background, self.isPal, foreground, self.isPal, preStr)
                local lx, ly = self:toRealPos(createdX, y)
                gpu.set(lx, ly, preStr)
            end

            --[[
            if chars[1] then
                local lines = {{}}
                for _, chr in ipairs(chars) do
                    if chr[1] == "\n" then
                        table.insert(lines, {})
                    else
                        table.insert(lines[#lines], chr)
                    end
                end
                while #lines[1] == 0 do
                    table.remove(lines, 1)
                    ypos = ypos + 1
                end

                if lines[1][1] then
                    for offY, line in ipairs(lines) do
                        for offX, chr in ipairs(line) do
                            local placeX = (xpos + offX + offsetX) - 1
                            local placeY = (ypos + offY + offsetY) - 1
                            if placeX >= xpos and placeX < xpos + sizeX then
                                if placeY >= ypos and placeY < ypos + sizeY then
                                    gpu.setForeground(chr[2], self.isPal)
                                    gpu.setBackground(chr[3], self.isPal)
                                    gpu.set(placeX, placeY, chr[1])
                                end
                            end
                        end
                    end
                end
            end
            ]]

            if chars[1] then
                local lines = {{}}
                for _, chr in ipairs(chars) do
                    if chr[1] == "\n" then
                        table.insert(lines, {})
                    else
                        table.insert(lines[#lines], chr)
                    end
                end
                while #lines[1] == 0 do
                    table.remove(lines, 1)
                    ypos = ypos + 1
                end

                if lines[1][1] then
                    local oldFore = lines[1][1][2]
                    local oldBack = lines[1][1][3]
                    local oldY = ypos
                    local buff = ""

                    for offY, line in ipairs(lines) do
                        for offX, chr in ipairs(line) do
                            if oldFore ~= chr[2] or oldBack ~= chr[3] or ypos ~= oldY then
                                --[[
                                local lmax = xpos + (unicode.len(buff) - 1)
                                if lmax > maxX then
                                    buff = unicode.sub(buff, 1, math.clamp(unicode.len(buff) - (lmax - maxX), 0, math.huge))
                                end
                                if ypos <= maxY then
                                    ]]
                                gpu.setForeground(oldFore, self.isPal)
                                gpu.setBackground(oldBack, self.isPal)

                                local xplace = xpos + offsetX
                                local yplace = ypos + offsetY
                                if yplace >= defYpos and yplace < defYpos + sizeY and xplace < defXpos + sizeX then
                                    while xplace < defXpos do
                                        buff = unicode.sub(buff, 2, unicode.len(buff))
                                        xplace = xplace + 1
                                    end
                                    while xplace + unicode.len(buff) > defXpos + sizeX do
                                        buff = unicode.sub(buff, 1, unicode.len(buff) - 1)
                                    end
                                    gpu.set(xplace, yplace, buff)
                                end
                                    --graphic._set(gpu, xpos, ypos, oldBack, self.isPal, oldFore, self.isPal, buff)
                                --end

                                buff = ""
                                xpos = self.x + ((x + offX) - 2)
                                oldY = ypos
                                oldFore = chr[2]
                                oldBack = chr[3]
                            end
                            buff = buff .. chr[1]
                        end
                        --[[
                        local lmax = xpos + (unicode.len(buff) - 1)
                        if lmax > maxX then
                            buff = unicode.sub(buff, 1, math.clamp(unicode.len(buff) - (lmax - maxX), 0, math.huge))
                        end
                        if ypos <= maxY then
                        ]]
                        gpu.setForeground(oldFore, self.isPal)
                        gpu.setBackground(oldBack, self.isPal)

                        local xplace = xpos + offsetX
                        local yplace = ypos + offsetY
                        if yplace >= defYpos and yplace < defYpos + sizeY and xplace < defXpos + sizeX then
                            while xplace < defXpos do
                                buff = unicode.sub(buff, 2, unicode.len(buff))
                                xplace = xplace + 1
                            end
                            while xplace + unicode.len(buff) > defXpos + sizeX do
                                buff = unicode.sub(buff, 1, unicode.len(buff) - 1)
                            end
                            gpu.set(xplace, yplace, buff)
                        end
                            --graphic._set(gpu, xpos, ypos, oldBack, self.isPal, oldFore, self.isPal, buff)
                        --end
                    
                        ypos = ypos + 1
                        xpos = self.x + (x - 1)
                        buff = ""
                    end
                end
            end
        end

        graphic.updated[self.screen] = true
    end

    local function isEmpty(str)
        for i = 1, unicode.len(str) do
            if unicode.sub(str, i, i) ~= " " then
                return false
            end
        end
        return true
    end

    local function addToHistory(newBuff)
        if not disHistory and graphic.inputHistory[1] ~= newBuff and not isEmpty(newBuff) then
            table.insert(graphic.inputHistory, 1, newBuff)
            while #graphic.inputHistory > 64 do
                table.remove(graphic.inputHistory, #graphic.inputHistory)
            end
        end
    end

    local function removeSelect()
        selectFrom = nil
        selectTo = nil
    end

    local function removeSelectedContent()
        if selectFrom then
            local newbuff = buffer .. lastBuffer
            local removed = unicode.sub(newbuff, selectFrom, selectTo)
            buffer = unicode.sub(newbuff, 1, selectFrom - 1)
            lastBuffer = unicode.sub(newbuff, selectTo + 1, unicode.len(buffer))
            removeSelect()
            return removed
        end
    end

    local function contrainBuffer()
        while true do
            local firstLen = unicode.len(buffer)
            local lastLen = unicode.len(lastBuffer)
            local currentLen = firstLen + lastLen
            if currentLen > maxDataSize then
                if firstLen > 0 then
                    buffer = unicode.sub(buffer, 1, firstLen - 1)
                else
                    lastBuffer = unicode.sub(lastBuffer, 2, lastLen)
                end
            else
                break
            end
        end
    end

    local function wlCheck(chr)
        return not whitelist or whitelist[chr]
    end

    local function add(inputStr)
        historyIndex = nil
        removeSelectedContent()
        for i = 1, unicode.len(inputStr) do
            local chr = unicode.sub(inputStr, i, i)
            if chr == "\n" then
                if isMultiline and wlCheck(chr) then
                    buffer = buffer .. chr
                else
                    return buffer
                end
            elseif not unicode.isWide(chr) and wlCheck(chr) then
                buffer = buffer .. chr
            end
        end
        contrainBuffer()
        redraw()
    end

    local function clipboard(inputStr, force)
        if (not disableClipboard or force) and inputStr then
            local out = add(inputStr)
            if out then
                removeSelect()
                addToHistory(out)
                return out
            end
        end
    end

    local function outFromRead()
        allowUse = false
        redraw()
    end

    return {setLock = function(lock)
        lockState = lock
    end, getLock = function()
        return not not lockState
    end, uploadEvent = function(eventData) --по идеи сюда нужно закидывать эвенты которые прошли через window:uploadEvent
        --вызывайте функцию и передавайте туда эвенты которые сами читаете, 
        --если функция чтото вернет, это результат, если он TRUE(не false) значет было нажато ctrl+w

        if lockState then return end

        if not eventData.windowEventData then --если это не эвент окна то делаем его таковым(потому что я криворукий и забываю об этом постоянно)
            eventData = self:uploadEvent(eventData)
        end

        if clickCheck then
            if self.selected then
                if eventData[1] == "touch" and eventData[2] == self.screen and eventData[5] == 0 then
                    removeSelect()
                    if eventData[3] >= x and eventData[3] < x + sizeX and eventData[4] == y then
                        allowUse = true
                        redraw()
                    else
                        allowUse = false
                        redraw()
                    end
                end
            elseif allowUse then
                removeSelect()
                allowUse = false
                redraw()
            end
        elseif self.selected ~= allowUse then
            removeSelect()
            allowUse = not not self.selected
            redraw()
        end

        if allowUse then
            if eventData[1] == "key_down" then
                if eventData[4] == 28 then
                    historyIndex = nil

                    if isMultiline then
                        add("\n")
                    else
                        local newBuff = buffer .. lastBuffer
                        removeSelect()
                        addToHistory(newBuff)
                        outFromRead()
                        return newBuff
                    end
                elseif eventData[4] == 200 then --up
                    if isMultiline then
                        local cursorPos = #buffer + 1

                        --need write movment code

                        local newBuff = buffer .. lastBuffer
                        buffer = newBuff:sub(1, cursorPos - 1)
                        lastBuffer = newBuff:sub(cursorPos, #newBuff)
                        redraw()
                    else
                        if not disHistory then
                            historyIndex = (historyIndex or 0) + 1
                            if not graphic.inputHistory[historyIndex] then
                                historyIndex = #graphic.inputHistory
                            end
                            if graphic.inputHistory[historyIndex] then
                                buffer = graphic.inputHistory[historyIndex]
                                lastBuffer = ""
                                removeSelect()
                                redraw()
                            else
                                historyIndex = nil
                            end
                        end
                    end
                elseif eventData[4] == 208 then --down
                    if not disHistory and historyIndex then
                        if graphic.inputHistory[historyIndex - 1] then
                            historyIndex = historyIndex - 1
                            buffer = graphic.inputHistory[historyIndex]
                            lastBuffer = ""
                        else
                            historyIndex = nil
                            buffer = ""
                            lastBuffer = ""
                        end
                        removeSelect()
                        redraw()
                    end
                elseif eventData[4] == 203 then -- <
                    if selectFrom then
                        lastBuffer = removeSelectedContent()
                    elseif unicode.len(buffer) > 0 then
                        lastBuffer = unicode.sub(buffer, -1, -1) .. lastBuffer
                        buffer = unicode.sub(buffer, 1, unicode.len(buffer) - 1)
                    end
                    redraw()
                elseif eventData[4] == 205 then -- >
                    if selectFrom then
                        buffer = removeSelectedContent()
                    elseif unicode.len(lastBuffer) > 0 then
                        buffer = buffer .. unicode.sub(lastBuffer, 1, 1)
                        lastBuffer = unicode.sub(lastBuffer, 2, unicode.len(lastBuffer))
                    end
                    redraw()
                elseif eventData[4] == 14 then --backspace
                    historyIndex = nil

                    if selectFrom then
                        removeSelectedContent()
                    elseif unicode.len(buffer) > 0 then
                        buffer = unicode.sub(buffer, 1, unicode.len(buffer) - 1)
                        removeSelect()
                    end
                    redraw()
                elseif eventData[3] == 23 and eventData[4] == 17 then --ctrl+w
                    historyIndex = nil
                    removeSelect()
                    outFromRead()
                    return true --exit ctrl+w
                elseif eventData[3] == 1 and eventData[4] == 30 then --ctrl+a
                    buffer = buffer .. lastBuffer
                    lastBuffer = ""
                    selectFrom = 1
                    selectTo = unicode.len(buffer)
                    redraw()
                elseif eventData[3] == 3 and eventData[4] == 46 then --ctrl+c
                    if selectFrom and not disableClipboard then
                        clipboardlib.set(eventData[5], unicode.sub(buffer .. lastBuffer, selectFrom, selectTo))
                    end
                elseif eventData[3] == 24 and eventData[4] == 45 then --ctrl+x
                    if selectFrom then
                        clipboardlib.set(eventData[5], removeSelectedContent())
                        redraw()
                    end
                elseif eventData[3] == 22 and eventData[4] == 47 then --вставка с системного clipboard
                    local str = clipboard(clipboardlib.get(eventData[5]))
                    if str then outFromRead() return str end
                elseif eventData[4] == 211 then  --del
                    historyIndex = nil

                    if selectFrom then
                        removeSelectedContent()
                        redraw()
                    elseif unicode.len(lastBuffer) > 0 then
                        lastBuffer = unicode.sub(lastBuffer, 2, unicode.len(lastBuffer))
                        removeSelect()
                        redraw()
                    end
                elseif eventData[4] == 15 then --tab
                    add("  ")
                elseif eventData[3] > 0 then --any char
                    historyIndex = nil
                    local char = unicode.char(eventData[3])
                    if not unicode.isWide(char) and wlCheck(char) then
                        add(char)
                    end
                end
            elseif eventData[1] == "clipboard" then --вставка с реального clipboard
                local str = clipboard(eventData[3])
                if str then outFromRead() return str end
            elseif eventData[1] == "softwareInsert" then --для подключения виртуальных клавиатур
                local str = clipboard(eventData[3], true)
                if str then outFromRead() return str end
            end
        end
    end, redraw = redraw, getBuffer = function()
        return buffer .. lastBuffer
    end, setBuffer = function(v)
        buffer = v
        lastBuffer = ""
    end, setAllowUse = function(state)
        allowUse = state
    end, getAllowUse = function ()
        return allowUse
    end, setClickCheck = function (state)
        clickCheck = state
    end, getClickCheck = function ()
        return clickCheck
    end, add = add, setOffset = function (x, y)
        offsetX = x
        offsetY = y
    end, getOffset = function ()
        return offsetX, offsetY
    end, setAllowHistory = function (allow)
        disHistory = not allow
    end, setAllowClipboard = function (allow)
        disableClipboard = not allow
    end, setMaxStringLen = function (max)
        maxDataSize = max
    end, setTitle = function (t, tc)
        title, titleColor = t, tc
    end, setWhitelist = function(list)
        whitelist = list
    end, setDrawLock = function(state)
        drawLock = state
    end}
end

local function read(...)
    local reader = readNoDraw(...)
    reader.redraw()
    return reader
end

function graphic.createWindow(screen, x, y, sizeX, sizeY, selected, isPal)
    local obj = {
        screen = screen,
        x = x or 1,
        y = y or 1,
        sizeX = sizeX,
        sizeY = sizeY,
        cursorX = 1,
        cursorY = 1,

        readNoDraw = readNoDraw,
        read = read,
        toRealPos = toRealPos,
        toFakePos = toFakePos,
        set = set,
        get = get,
        fill = fill,
        copy = copy,
        clear = clear,
        uploadEvent = uploadEvent,
        write = write,
        getCursor = getCursor,
        setCursor = setCursor,
        isPal = isPal or false,
    }

    if not sizeX or not sizeY then
        local rx, ry = graphic.getResolution(screen)
        obj.sizeX = sizeX or rx
        obj.sizeY = sizeY or ry
    end

    if selected ~= nil then
        obj.selected = selected
    else
        obj.selected = false
    end

    if obj.selected then --за раз может быть активно только одно окно
        for i, window in ipairs(graphic.windows) do
            if window.screen == screen then
                window.selected = false
            end
        end
    end

    table.insert(graphic.windows, obj)
    return obj
end

------------------------------------ window methods

graphic.defaultWindows = {}

local function window(screen)
    local rx, ry = graphic.getResolution(screen)
    graphic.defaultWindows[screen] = graphic.defaultWindows[screen] or graphic.createWindow(screen, 1, 1, rx, ry)
    local window = graphic.defaultWindows[screen]
    window.sizeX = rx
    window.sizeY = ry
    return graphic.defaultWindows[screen]
end

function graphic.readNoDraw(screen, ...)
    return window(screen):readNoDraw(...)
end

function graphic.read(screen, ...)
    return window(screen):read(...)
end

function graphic.toRealPos(screen, ...)
    return window(screen):toRealPos(...)
end

function graphic.toFakePos(screen, ...)
    return window(screen):toFakePos(...)
end

function graphic.set(screen, ...)
    return window(screen):set(...)
end

function graphic.get(screen, ...)
    return window(screen):get(...)
end

function graphic.fill(screen, ...)
    return window(screen):fill(...)
end

function graphic.copy(screen, ...)
    return window(screen):copy(...)
end

function graphic.clear(screen, ...)
    return window(screen):clear(...)
end

function graphic.readNoDraw(screen, ...)
    return window(screen):readNoDraw(...)
end

function graphic.uploadEvent(screen, ...)
    return window(screen):uploadEvent(...)
end

function graphic.write(screen, ...)
    return window(screen):write(...)
end

function graphic.getCursor(screen, ...)
    return window(screen):getCursor(...)
end

function graphic.setCursor(screen, ...)
    return window(screen):setCursor(...)
end

------------------------------------

function graphic.unloadBuffer(screen)
    local gpu = graphic.findGpu(screen)

    graphic.bindCache[screen] = nil
    graphic.topBindCache[screen] = nil
    graphic.vgpus[screen] = nil

    if graphic.screensBuffers[screen] then
        gpu.freeBuffer(graphic.screensBuffers[screen])
    end
end

function graphic.unloadBuffers()
    for address in component.list("screen", true) do
        graphic.unloadBuffer(address)
    end
end

function graphic.findGpuAddress(screen, topOnly)
    local deviceinfo = lastinfo.deviceinfo
    if not deviceinfo[screen] then
        graphic.bindCache[screen] = nil
        graphic.topBindCache[screen] = nil
        graphic.vgpus[screen] = nil
        return
    end

    local bindCache = graphic.bindCache
    if topOnly then
        bindCache = graphic.topBindCache
    end

    if bindCache[screen] and not graphic.gpuPrivateList[bindCache[screen]] then
        return bindCache[screen]
    end

    local screenLevel = tonumber(deviceinfo[screen].capacity) or 0
    local bestGpuLevel = -math.huge
    local gpuLevel, bestGpu
    local function check(deep)
        for address in component.list("gpu") do
            local connectScr = component.invoke(address, "getScreen")
            local connectedAny = not not connectScr
            local connected = connectScr == screen

            if not graphic.gpuPrivateList[address] and (deep or connected) then
                gpuLevel = (tonumber(deviceinfo[address].capacity) or 0) / 1000

                if not topOnly then
                    if connectedAny and not connected then
                        gpuLevel = gpuLevel - 1000
                    else
                        if connected and gpuLevel == screenLevel then
                            gpuLevel = gpuLevel + 2000
                        elseif connected then
                            gpuLevel = gpuLevel + 1000
                        end

                        if gpuLevel == screenLevel then
                            gpuLevel = gpuLevel + 20
                        elseif gpuLevel > screenLevel then
                            gpuLevel = gpuLevel + 10
                        end
                    end
                end

                if gpuLevel > bestGpuLevel then
                    bestGpuLevel = gpuLevel
                    bestGpu = address
                end
            end
        end
    end
    
    if not topOnly then
        check()
    end
    check(true)

    bindCache[screen] = bestGpu
    return bestGpu
end

function graphic.findGpuProxy(screen, topOnly)
    local addr = graphic.findGpuAddress(screen, topOnly)
    if addr then
        return component.proxy(addr)
    end
end

function graphic.initGpu(screen, gpuaddress)
    local gpu = component.proxy(gpuaddress)

    if gpu.getScreen() ~= screen then
        gpu.bind(screen, false)
    end

    if isVGpuInstalled and not graphic.vgpus[screen] then
        if graphic.allowSoftwareBuffer then
            graphic.vgpus[screen] = require("vgpu").create(gpu, screen)
        elseif gpu.getDepth() == 1 then
            graphic.vgpus[screen] = require("vgpu").createStub(gpu)
        end
    end

    if gpu.setActiveBuffer then
        if graphic.allowHardwareBuffer then
            if not graphic.screensBuffers[screen] then
                gpu.setActiveBuffer(0)
                graphic.screensBuffers[screen] = gpu.allocateBuffer(gpu.getResolution())
            end

            if graphic.screensBuffers[screen] then
                gpu.setActiveBuffer(graphic.screensBuffers[screen])
            end
        else
            gpu.setActiveBuffer(0)
            gpu.freeAllBuffers()
        end
    end

    if graphic.vgpus[screen] then
        return graphic.vgpus[screen]
    else
        return gpu
    end
end

function graphic.findGpu(screen, topOnly)
    local gpu = graphic.findGpuAddress(screen, topOnly)
    if gpu then
        return graphic.initGpu(screen, gpu)
    end
end

function graphic.findNativeGpu(screen)
    local gpu = graphic.findGpuProxy(screen)
    if gpu then
        if gpu.getScreen() ~= screen then
            gpu.bind(screen, false)
        end
        pcall(gpu.setActiveBuffer, 0)
        return gpu
    end
end

------------------------------------

local function backBuffer(screen, ...)
    local gpu = graphic.findGpu(screen)
    if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
        gpu.setActiveBuffer(graphic.screensBuffers[screen] or 0)
    end
    return ...
end

function graphic.getResolution(screen)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.getResolution())
    end
end

function graphic.maxResolution(screen)
    local gpu = graphic.findGpu(screen, true)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.maxResolution())
    end
end

function graphic.setResolution(screen, x, y)
    local gpu = graphic.findGpu(screen, true)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            local activeBuffer = gpu.getActiveBuffer()

            local palette
            if gpu.getDepth() > 1 then
                palette = {}
                for i = 0, 15 do
                    table.insert(palette, graphic.getPaletteColor(screen, i) or 0)
                end
            end
            
            local newBuffer = gpu.allocateBuffer(x, y)
            if newBuffer then
                graphic.screensBuffers[screen] = newBuffer

                gpu.bitblt(newBuffer, nil, nil, nil, nil, activeBuffer)
                gpu.freeBuffer(activeBuffer)

                if palette then
                    gpu.setActiveBuffer(0)
                    for i, color in ipairs(palette) do
                        gpu.setPaletteColor(i - 1, color)
                    end
                    
                    gpu.setActiveBuffer(newBuffer)
                    for i, color in ipairs(palette) do
                        gpu.setPaletteColor(i - 1, color)
                    end
                else
                    gpu.setActiveBuffer(newBuffer)
                end
            else
                gpu.setActiveBuffer(0)
                graphic.screensBuffers[screen] = nil
            end
        end

        if graphic.screensBuffers[screen] then
            gpu.setResolution(x, y)
            gpu.setActiveBuffer(0)
            return backBuffer(screen, gpu.setResolution(x, y))
        else
            return gpu.setResolution(x, y)
        end
    end
end

function graphic.isValidResolution(screen, x, y)
    local rx, ry = graphic.maxResolution(screen)
    return not (x > rx or y > rx or (x * y) > (rx * ry))
end

function graphic.setPaletteColor(screen, i, v)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
            gpu.setPaletteColor(i, v)
            gpu.setActiveBuffer(graphic.screensBuffers[screen] or 0)
        end
        return gpu.setPaletteColor(i, v)
    end
end

function graphic.getPaletteColor(screen, i)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.getPaletteColor(i))
    end
end

function graphic.setPalette(screen, palette, fromZero)
    local gpu = graphic.findGpu(screen)
    if gpu then
        local from = fromZero and 0 or 1
        
        local function set()
            for i = from, from + 15 do
                local index = i
                if not fromZero then
                    index = i - 1
                end
                
                if gpu.getPaletteColor(index) ~= palette[i] then
                    gpu.setPaletteColor(index, palette[i])
                end
            end
        end

        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
            set()
            gpu.setActiveBuffer(graphic.screensBuffers[screen] or 0)
        end
        set()
    end
end

function graphic.getPalette(screen, fromZero)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end

        local palette = {}
        for i = 0, 15 do
            if fromZero then
                palette[i] = gpu.getPaletteColor(i)
            else
                palette[i + 1] = gpu.getPaletteColor(i)
            end
        end
        return backBuffer(screen, palette)
    end
end

function graphic.getDepth(screen)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.getDepth())
    end
end

function graphic.setDepth(screen, v)
    local gpu = graphic.findGpu(screen, true)
    if gpu then
        graphic.vgpus[screen] = nil
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
            gpu.setDepth(v)
            gpu.setActiveBuffer(graphic.screensBuffers[screen] or 0)
        end
        return gpu.setDepth(v)
    end
end

function graphic.maxDepth(screen)
    local gpu = graphic.findGpu(screen, true)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.maxDepth())
    end
end

function graphic.getViewport(screen)
    local gpu = graphic.findGpu(screen)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.getViewport())
    end
end

function graphic.setViewport(screen, x, y)
    local gpu = graphic.findGpu(screen, true)
    if gpu then
        if gpu.setActiveBuffer and graphic.allowHardwareBuffer then
            gpu.setActiveBuffer(0)
        end
        return backBuffer(screen, gpu.setViewport(x, y))
    end
end

------------------------------------

function graphic.isAvailable(screen)
    if not component.isConnected(screen) then return false end
    return not not graphic.findGpuAddress(screen)
end

function graphic.forceUpdate(screen)
    if graphic.allowSoftwareBuffer or graphic.allowHardwareBuffer then
        if screen then
            graphic.updateFlag(screen)
            graphic.update(screen)
        else
            for lscreen, ctype in component.list("screen") do
                graphic.updateFlag(lscreen)
                graphic.update(lscreen)
            end
        end
    end
end

function graphic.update(screen)
    if graphic.updated[screen] then
        local gpuaddress = graphic.findGpuAddress(screen)
        if gpuaddress then
            if graphic.allowSoftwareBuffer then
                local gpu = graphic.initGpu(screen, gpuaddress)
                if gpu.update then --if this is vgpu
                    gpu.update()
                end
            elseif graphic.allowHardwareBuffer then
                local gpu = graphic.initGpu(screen, gpuaddress)
                if gpu.bitblt then
                    gpu.bitblt()
                end
            end
            graphic.updated[screen] = nil
        end

        graphic.lastScreen = screen
    end
end

function graphic.updateFlag(screen)
    graphic.updated[screen] = true
end

event.hyperListen(function(eventType, _, ctype)
    if (eventType == "component_added" or eventType == "component_removed") and (ctype == "screen" or ctype == "gpu") then
        graphic.bindCache = {}
        graphic.topBindCache = {}
        graphic.vgpus = {}
    end
end)

------------------------------------

function graphic.getDeviceTier(address)
    local capacity = lastinfo.deviceinfo[address].capacity
    if capacity == "8000" then
        return 3
    elseif capacity == "2000" then
        return 2
    elseif capacity == "800" then
        return 1
    else
        return -1
    end
end

function graphic.saveGpuSettings(gpu)
    if type(gpu) == "string" then
        gpu = component.proxy(gpu)
    end

    local screen = gpu.getScreen()
    if not screen then
        return function () end
    end

    local palette = graphic.getPalette(screen)
    local depth = gpu.getDepth()
    local rx, ry = gpu.getResolution()
    local buffer = gpu.getActiveBuffer and gpu.getActiveBuffer()

    return function ()
        graphic.setPalette(screen, palette)
        gpu.setDepth(depth)
        gpu.setResolution(rx, ry)
        if buffer then
            gpu.setActiveBuffer(buffer)
        end
    end
end

function graphic.screenshot(screen, x, y, sx, sy)
    local gpu = graphic.findGpu(screen)
    x = x or 1
    y = y or 1
    local rx, ry = gpu.getResolution()
    sx = sx or rx
    sy = sy or ry

    local index = 1
    local chars = {}
    local fores = {}
    local backs = {}
    for cy = y, y + (sy - 1) do
        for cx = x, x + (sx - 1) do
            local ok, char, fore, back = pcall(gpu.get, cx, cy)
            if ok then
                chars[index] = char
                fores[index] = fore
                backs[index] = back
            end
            index = index + 1
        end
    end

    return function()
        local gpu = graphic.findGpu(screen)

        local oldFore, oldBack, oldX, oldY = fores[1], backs[1], x, y
        local buff = ""

        local cx, cy = x, y
        for i = 1, index do
            local fore, back, char = fores[i], backs[i], chars[i]

            if char then
                if fore ~= oldFore or back ~= oldBack or oldY ~= cy then
                    gpu.setForeground(oldFore)
                    gpu.setBackground(oldBack)
                    gpu.set(oldX, oldY, buff)

                    oldFore = fore
                    oldBack = back
                    oldX = cx
                    oldY = cy
                    buff = char
                else
                    buff = buff .. char
                end
            end

            cx = cx + 1
            if cx >= x + sx then
                cx = x
                cy = cy + 1
            end
        end

        if oldFore then
            gpu.setForeground(oldFore)
            gpu.setBackground(oldBack)
            gpu.set(oldX, oldY, buff)
        end

        graphic.updated[screen] = true
        graphic.lastScreen = screen
    end
end

return graphic