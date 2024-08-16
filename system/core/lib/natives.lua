local natives = {}
--позваляет получить доступ к оригинальным методам библиотек computer и component
--например если нужно исключить влияния vcomponent

local function deepclone(tbl, newtbl)
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

-- clone
natives.component = deepclone(component)
natives.computer = deepclone(computer)
natives.table = deepclone(table) --table и math в likeOS содержут дополнительные методы, данные же таблицы не содержут этих методов
natives.math = deepclone(math)
natives.pcall = pcall
natives.xpcall = xpcall
natives.pairs = pairs
natives.ipairs = ipairs

-- we remove the excess
natives.computer.runlevel = nil

return natives