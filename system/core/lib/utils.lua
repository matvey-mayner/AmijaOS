local component = require("component")
local utils = {}

function utils.check(func, ...)
    local result = {pcall(func, ...)}
    if result[1] then
        return table.unpack(result, 2)
    else
        return nil, result[2] or "unknown error"
    end
end

function utils.findModem(wireless)
    if wireless then
        for address in component.list("modem", true) do
            if component.invoke(address, "isWireless") then
                if component.invoke(address, "setStrength", math.huge) >= 400 then
                    return address
                end
            end
        end
    else
        for address in component.list("modem", true) do
            if not component.invoke(address, "isWireless") then
                return address
            end
        end
    end

    return (component.list("modem", true)())
end

function utils.openPort(modem, port)
    local result, err = modem.open(port)
    if result == nil then --если открыто больше портов чем поддерживает модем(false означает что выбраный порт уже открыт, по этому проверка явная, на nil)
        modem.close()
        return modem.open(port)
    end
    return result, err
end

function utils.safeExec(func, errorOutput, tag) --для event.hyperHook или других hyper методов, обрабатывает ошибку и пишет в лог в случаи чего
    local result = {xpcall(func, debug.traceback)}
    if not result[1] then
        require("logs").log(result[2], tag or "safe exec error")
        if errorOutput then
            return table.unpack(errorOutput)
        end
    else
        return table.unpack(result, 2)
    end
end

utils.unloadable = true
return utils