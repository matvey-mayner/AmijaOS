local fs = require("filesystem")
local time = {unloadable = true}

function time.getRealTime()
    local file = assert(fs.open("/tmp/null", "wb"))
    file.close()

    local unixTime = fs.lastModified("/tmp/null")
    fs.remove("/tmp/null")

    return unixTime
end

function time.getGameTime() --везврашяет игровые милисикунды
    return os.time() * 1000
end

------------------------------------------

function time.addTimeZone(unixTime, timezone)
    return ((unixTime / 1000) + (timezone * 60 * 60)) * 1000
end

function time.parseSecond(unixTime)
    return math.floor((unixTime / 1000) % 60)
end

function time.parseMinute(unixTime)
    return math.floor((unixTime / 1000 / 60) % 60)
end

function time.parseHours(unixTime)
    return math.floor((unixTime / 1000 / (60 * 60)) % 24)
end

function time.formatTime(unixTime, withSecond, withData)
    local str = ""

    local hours = tostring(time.parseHours(unixTime))
    if #hours < 2 then hours = "0" .. hours end
    str = str .. hours .. ":"

    local minute = tostring(time.parseMinute(unixTime))
    if #minute < 2 then minute = "0" .. minute end
    str = str .. minute

    if withSecond then
        str = str .. ":"
        local second = tostring(time.parseSecond(unixTime))
        if #second < 2 then second = "0" .. second end
        str = str .. second
    end

    return str
end

return time