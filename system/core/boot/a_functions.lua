------------------------------------------------ math
function math.round(number)
    if number >= 0 then
        return math.floor(number + 0.5)
    else
        return math.ceil(number - 0.5)
    end
end

function math.map(value, low, high, low_2, high_2)
    local relative_value = (value - low) / (high - low)
    local scaled_value = low_2 + (high_2 - low_2) * relative_value
    return scaled_value
end

function math.clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

function math.roundTo(number, numbers)
    numbers = numbers or 3
    return tonumber(string.format("%." .. tostring(math.floor(numbers)) .. "f", number))
end


function math.mapRound(value, low, high, low_2, high_2)
    return math.round(math.map(value, low, high, low_2, high_2))
end

function math.clampRound(value, min, max)
    return math.round(math.clamp(value, min, max))
end


------------------------------------------------ table
function table.clone(tbl, newtbl)
    newtbl = newtbl or {}
    for k, v in pairs(tbl) do
        newtbl[k] = v
    end
    return newtbl
end

function table.add(base, add)
    for _, v in ipairs(add) do
        table.insert(base, v)
    end
end

function table.exists(tbl, val)
    for k, v in pairs(tbl) do
        if v == val then
            return true, k
        end
    end
    return false
end

function table.find(tbl, val)
    return select(2, table.exists(tbl, val))
end

function table.clear(tbl, val)
    local state = false
    for k, v in pairs(tbl) do
        if val == nil or v == val then
            tbl[k] = nil
            state = true
        end
    end
    return state
end

function table.deepclone(tbl, newtbl)
    local cache = {}
    local function recurse(tbl, newtbl)
        newtbl = newtbl or {}

        for k, v in pairs(tbl) do
            if type(v) == "table" then
                local ltbl = cache[v]
                if not ltbl then
                    cache[v] = {}
                    ltbl = cache[v]
                    recurse(v, cache[v])
                end
                newtbl[k] = ltbl
            else
                newtbl[k] = v
            end
        end

        return newtbl
    end

    return recurse(tbl, newtbl)
end

function table.low(tbl)
    local newtbl = {}
    for i, v in ipairs(tbl) do
        newtbl[i - 1] = v
    end
    return newtbl
end

function table.high(tbl)
    local newtbl = {}
    for i, v in ipairs(tbl) do
        newtbl[i + 1] = v
    end
    return newtbl
end

function table.fromIterator(...)
    local tbl = {}
    for a, b, c, d, e, f, g, h, j, k in ... do
        table.insert(tbl, {a, b, c, d, e, f, g, h, j, k})
    end
    return tbl
end

function table.len(tbl)
    local len = 0
    for i, v in pairs(tbl) do
        len = len + 1
    end
    return len
end

------------------------------------------------ other

function spcall(...)
    local result = table.pack(pcall(...))
    if not result[1] then
        error(tostring(result[2]), 3)
    else
        return table.unpack(result, 2, result.n)
    end
end

function xor(...)
    local state = false
    for _, flag in ipairs({...}) do
        if flag then
            state = not state
        end
    end
    return state
end

function toboolean(object)
    object = tostring(object)
    if object == "true" or object == "1" then
        return true
    else
        return false
    end
end