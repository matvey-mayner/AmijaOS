local parser = require("parser")
local unicode = require("unicode")
local graphic = require("graphic")
local event = require("event")
local term = {}

function term.create(screen, x, y, sizeX, sizeY, selected, isPal)
    local obj = {}
    obj.window = graphic.createWindow(screen, x, y, sizeX, sizeY, selected, isPal)
    obj.screen = screen
    obj.cursorX = 1
    obj.cursorY = 1
    obj.bg = isPal and 15 or 0x000000
    obj.fg = isPal and 0  or 0xffffff

    obj.x = x
    obj.y = y
    obj.sizeX = sizeX
    obj.sizeY = sizeY
    obj.selected = selected
    obj.isPal = isPal
    obj.defaultPrintTab = 8

    setmetatable(obj, {__index = term})
    return obj
end


function term:print(...)
    local args = table.pack(...)
    local len = args.n
    local printResult = ""
    
    for i = 1, len do
        local str = tostring(args[i])
        printResult = printResult .. str
        if i ~= len then
            local strlen = #str
            local dtablen = self.defaultPrintTab
            local tablen = 0
            while tablen <= 0 do
                tablen = dtablen - strlen
                dtablen = dtablen + self.defaultPrintTab
            end
            printResult = printResult .. string.rep(" ", tablen)
        end
    end

    self:writeLn(printResult)
end

function term:setColors(bg, fg)
    self.bg = bg
    self.fg = fg
end

function term:setCursor(x, y)
    self.cursorX = x
    self.cursorY = y
end

function term:getColors()
    return self.bg, self.fg
end

function term:getCursor()
    return self.cursorX, self.cursorY
end

function term:clear()
    self.window:clear(self.bg)
    self:setCursor(1, 1)
end

function term:newLine()
    self.cursorX = 1
    if self.cursorY < self.sizeY then
        self.cursorY = self.cursorY + 1
    else
        self.window:copy(1, 2, self.sizeX, self.sizeY - 1, 0, -1)
        self.window:fill(1, self.sizeY, self.sizeX, 1, self.bg, 0, " ")
    end
end

function term:write(str)
    str = tostring(str)
    for i, lstr in ipairs(parser.split(unicode, str, "\n")) do
        if i > 1 then
            self:newLine()
        end
        for i2, line in ipairs(parser.toLines(lstr, self.sizeX - (self.cursorX - 1))) do
            if i2 > 1 then
                self:newLine()
            end
            self.window:set(self.cursorX, self.cursorY, self.bg, self.fg, line)
            self.cursorX = self.cursorX + unicode.wlen(line)
            --[[
            if self.cursorX > self.sizeX then
                self:newLine()
            elseif i > 1 or i2 > 1 then
                self:newLine()
            end
            ]]
        end
    end
end

function term:writeLn(str)
    self:write(tostring(str) .. "\n")
end

function term:read(hidden, buffer, syntax, disHistory)
    local reader = self.window:read(self.cursorX, self.cursorY, self.sizeX - (self.cursorX - 1), self.bg, self.fg, nil, hidden, buffer, false, syntax, disHistory)
    while true do
        local eventData = {event.pull()}
        local windowEventData = self.window:uploadEvent(eventData)
        local out = reader.uploadEvent(windowEventData)
        if out == true then
            return false
        elseif type(out) == "string" then
            return out
        end
    end
end

function term:readLn(hidden, buffer, syntax, disHistory)
    local out = self:read(hidden, buffer, syntax, disHistory)
    self:newLine()
    return out
end

term.unloadable = true
return term