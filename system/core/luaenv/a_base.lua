function _G.loadfile(path, mode, env)
    local fs = require("filesystem")
    local content, err = fs.readFile(path)
    if not content then return nil, err end
    return load(content, "=" .. path, mode, env or require("bootloader").createEnv())
end

--вы не должны запускать им проги! это вызовет проблеммы с обработкой ошибок и потоками в целевой программе, для запуска программ используйте programs.execute
function _G.dofile(path, ...)
    local code, err = loadfile(path)
    if not code then
        return error(err .. ":" .. path, 0)
    end
    return code(...)
end