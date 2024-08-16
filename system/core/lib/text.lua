local text = {trimLetters = {" ", "\t", "\r", "\n"}}

function text.startwith(tool, str, startCheck)
    return tool.sub(str, 1, tool.len(startCheck)) == startCheck
end

function text.endwith(tool, str, endCheck)
    return tool.sub(str, tool.len(str) - (tool.len(endCheck) - 1), tool.len(str)) == endCheck
end

function text.trimLeft(tool, str, list)
    list = list or text.trimLetters

    local newstr = ""
    local allowTrim = true
    for i = 1, tool.len(str) do
        local char = tool.sub(str, i, i)
        if allowTrim then
            if not table.exists(list, char) then
                newstr = newstr .. char
                allowTrim = false
            end
        else
            newstr = newstr .. char
        end
    end
    return newstr
end

function text.trimRight(tool, str, list)
    list = list or text.trimLetters

    local newstr = ""
    local allowTrim = true
    for i = tool.len(str), 1, -1 do
        local char = tool.sub(str, i, i)
        if allowTrim then
            if not table.exists(list, char) then
                newstr = char .. newstr
                allowTrim = false
            end
        else
            newstr = char .. newstr
        end
    end
    return newstr
end

function text.trim(tool, str, list)
    str = text.trimLeft(tool, str, list)
    str = text.trimRight(tool, str, list)
    return str
end

function text.escapePattern(str)
    return str:gsub("([^%w])", "%%%1")
end

text.unloadable = true
return text