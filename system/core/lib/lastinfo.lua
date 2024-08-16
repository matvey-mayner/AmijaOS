local event = require("event")
local computer = require("computer")
local component = require("component")
local bootloader = require("bootloader")
local lastinfo = {keyboards = {}}

event.hyperListen(function (eventType, componentUuid, componentType)
    if bootloader.runlevel ~= "init" then
        if eventType == "component_added" then
            lastinfo.deviceinfo = nil

            if componentType == "keyboard" then
                table.clear(lastinfo.keyboards)
            elseif componentType == "screen" then
                lastinfo.keyboards[componentUuid] = nil
            end
        elseif eventType == "component_removed" then
            lastinfo.deviceinfo[componentUuid] = nil
            lastinfo.keyboards[componentUuid] = nil
        end
    end
end)

setmetatable(lastinfo, {__index = function(self, key)
    if key == "deviceinfo" then
        self.deviceinfo = computer.getDeviceInfo()
        return self.deviceinfo
    end
end})
setmetatable(lastinfo.keyboards, {__index = function(self, address)
    local result = {pcall(component.invoke, address, "getKeyboards")}
    if result[1] and type(result[2]) == "table" then
        self[address] = result[2]
        return result[2]
    end
end})
return lastinfo