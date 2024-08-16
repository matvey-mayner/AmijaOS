local component = require("component", true)
local hook = {}

----------------------------

local globalComponentHooks = {}
local localComponentHooks = {}
local invoke = component.invoke

function component.invoke(address, method, ...)
    checkArg(1, address, "string")
    checkArg(2, method, "string")

    local args = {...}
    local resultHooks = {}
    local resultHook
    for i, hook in ipairs(globalComponentHooks) do
        address, method, args, resultHook = hook(address, method, args) --можно вернуть два nil и потом фейковый результат в таблице
        if resultHook then
            table.insert(resultHooks, resultHook)
        end
    end
    if localComponentHooks[address] then
        for i, hook in ipairs(localComponentHooks[address]) do
            address, method, args, resultHook = hook(address, method, args)
            if resultHook then
                table.insert(resultHooks, resultHook)
            end
        end
    end

    if address then
        local result = {pcall(invoke, address, method, table.unpack(args))} --для правильного разположения ошибки
        for i, v in ipairs(resultHooks) do
            result = v(result)
        end
        if result[1] then
            return table.unpack(result, 2)
        else
            error(result[2], 2)
        end
    elseif args then
        return table.unpack(args)
    end
end

----------------------------

function hook.addGlobalComponentHook(func)
    table.insert(globalComponentHooks, func)
end

function hook.delGlobalComponentHook(func)
    table.clear(globalComponentHooks, func)
end

function hook.addComponentHook(address, func)
    if not localComponentHooks[address] then localComponentHooks[address] = {} end
    table.insert(localComponentHooks[address], func)
end

function hook.delComponentHook(address, func)
    if not localComponentHooks[address] then localComponentHooks[address] = {} end
    table.clear(localComponentHooks[address], func)
end

return hook