local unicode = require("unicode")
local paths = {}
paths.baseDirectory = "/data"
paths.unloadable = true

function paths.segments(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
        local current, up = part:find("^%.?%.$")
        if current then
            if up == 2 then
                table.remove(parts)
            end
        else
            table.insert(parts, part)
        end
    end
    return parts
end

------------------------------------

function paths.xconcat(...) --работает как concat но пути начинаюшиеся со / НЕ обрабатываються как отновительные а откидывают путь в начало
    local set = table.pack(...)
    for index, value in ipairs(set) do
        checkArg(index, value, "string")
    end
    for index, value in ipairs(set) do
        if unicode.sub(value, 1, 1) == "/" and index > 1 then
            local newset = {}
            for i = index, #set do
                table.insert(newset, set[i])
            end
            return paths.xconcat(table.unpack(newset))
        end
    end
    return paths.canonical(table.concat(set, "/"))
end

function paths.sconcat(main, ...) --работает так же как concat но если итоговый путь не указывает на целевой обьект первого путя то вернет false
    main = paths.canonical(main) .. "/"
    local path = paths.concat(main, ...) .. "/"
    if unicode.sub(path, 1, unicode.len(main)) == main then
        return paths.canonical(path)
    end
    return false
end

function paths.concat(...) --класический concat как в openOS
    local set = table.pack(...)
    for index, value in ipairs(set) do
        checkArg(index, value, "string")
    end
    return paths.canonical(table.concat(set, "/"))
end

------------------------------------

function paths.absolute(path) --работает как canonical но обрабатывает baseDirectory
    local result = table.concat(paths.segments(path), "/")
    if unicode.sub(path, 1, 1) == "/" then
        return "/" .. result
    else
        if paths.baseDirectory then
            return paths.concat(paths.baseDirectory, path)
        else
            return result
        end
    end
end

function paths.canonical(path)
    local result = table.concat(paths.segments(path), "/")
    if unicode.sub(path, 1, 1) == "/" then
        return "/" .. result
    end
    return result
end

local function rawEquals(pathsList)
    local mainPath = pathsList[1]
    for i = 2, #pathsList do
        if mainPath ~= pathsList[i] then
            return false
        end
    end
    return true
end

function paths.equals(...)
    local pathsList = {...}
    for i, path in ipairs(pathsList) do
        pathsList[i] = paths.canonical(path)
    end
    return rawEquals(pathsList)
end

function paths.linkEquals(...)
    local fs = require("filesystem")
    local pathsList = {...}
    for i, path in ipairs(pathsList) do
        pathsList[i] = fs.mntPath(path)
    end
    return rawEquals(pathsList)
end

function paths.path(path)
    path = paths.canonical(path)
    local parts = paths.segments(path)
    local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
    if unicode.sub(path, 1, 1) == "/" and unicode.sub(result, 1, 1) ~= "/" then
        return paths.canonical("/" .. result)
    else
        return paths.canonical(result)
    end
end
  
function paths.name(path)
    checkArg(1, path, "string")
    local parts = paths.segments(path)
    return parts[#parts]
end

function paths.extension(path)
    local name = paths.name(path)
    if not name then
        return
    end

	local exp
    for i = 1, unicode.len(name) do
        local char = unicode.sub(name, i, i)
        if char == "." then
            if i ~= 1 then
                exp = {}
            end
        elseif exp then
            table.insert(exp, char)
        end
    end

    if exp and #exp > 0 then
        return table.concat(exp)
    end
end

function paths.changeExtension(path, exp)
    return paths.hideExtension(path) .. (exp and ("." .. exp) or "")
end

function paths.hideExtension(path)
    path = paths.canonical(path)

    local exp = paths.extension(path)
    if exp then
        return unicode.sub(path, 1, unicode.len(path) - (unicode.len(exp) + 1))
    else
        return path
    end
end

return paths