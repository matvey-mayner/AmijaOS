local unicode = require("unicode")
local text = require("text")
local parser = {}

function parser.split(tool, str, seps) --дробит строку по разделителям(сохраняяя пустые строки)
    local parts = {""}

    if type(seps) ~= "table" then
        seps = {seps}
    end

    local index = 1
    local strlen = tool.len(str)
    while index <= strlen do
        while true do
            local isBreak
            for i, sep in ipairs(seps) do
                if tool.sub(str, index, index + (tool.len(sep) - 1)) == sep then
                    table.insert(parts, "")
                    index = index + tool.len(sep)
                    isBreak = true
                    break
                end
            end
            if not isBreak then break end
        end

        parts[#parts] = parts[#parts] .. tool.sub(str, index, index)
        index = index + 1
    end

    return parts
end

function parser.change(tool, str, list)
    for from, to in pairs(list) do
        str = table.concat(parser.split(tool, str, from), to)
    end
    return str
end

function parser.fastChange(str, list)
    for from, to in pairs(list) do
        local lfrom, lto
        if #from == 1 then
            lfrom = "%" .. from
        else
            lfrom = text.escapePattern(from)
        end
        if #to == 1 then
            lto = "%" .. to
        else
            lto = text.escapePattern(to)
        end
        str = str:gsub(lfrom, lto)
    end
    return str
end

function parser.toParts(tool, str, max) --дробит строку на куски с максимальным размером
    local strs = {}
    while tool.len(str) > 0 do
        table.insert(strs, tool.sub(str, 1, max))
        str = tool.sub(str, tool.len(strs[#strs]) + 1)
    end
    return strs
end

function parser.toLines(str, max)
    return parser.toParts(unicode, str, max)
end

function parser.toLinesLn(str, max)
    local raw_lines = parser.split(unicode, str, "\n")
    local lines = {}
    for _, raw_line in ipairs(raw_lines) do
        if raw_line == "" then
            table.insert(lines, "")
        else
            local tmpLines = parser.toParts(unicode, raw_line, max or 50)
            for _, line in ipairs(tmpLines) do
                table.insert(lines, line)
            end
        end
    end
    return lines
end

function parser.parseTraceback(traceback, maxlen, maxlines, spaces)
    maxlen = maxlen or 50
    maxlines = maxlines or 15
    spaces = spaces or 2

    local tab = string.char(9)
    local space = string.rep(" ", spaces)

    local lines = {}
    for i, str in ipairs(parser.toLinesLn(traceback, maxlen)) do
        table.insert(lines, (str:gsub(tab, space)))
        if #lines >= maxlines then
            break
        end
    end
    
    return lines
end

function parser.formatTraceback(...)
    return table.concat(parser.parseTraceback(...), "\n")
end

parser.unloadable = true
return parser