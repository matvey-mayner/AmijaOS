local uuid = {}
uuid.null = "00000000-0000-0000-0000-000000000000"

function uuid.next()
    local r = math.random
    return string.format("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    r(0,255),r(0,255),r(0,255),r(0,255),
    r(0,255),r(0,255),
    r(64,79),r(0,255),
    r(128,191),r(0,255),
    r(0,255),r(0,255),r(0,255),r(0,255),r(0,255),r(0,255))
end

function uuid.isValid(str)
    if #str ~= #uuid.null then
        return false
    end

    for i = 1, #uuid.null do
        local need = uuid.null:sub(i, i)
        local char = str:sub(i, i)

        if xor(need == "-", char == "-") or (need ~= "-" and not tonumber(char, 16)) then
            return false
        end
    end
    
    return true
end

uuid.unloadable = true
return uuid