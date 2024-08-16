local component = require("component")
local fs = require("filesystem")
local paths = require("paths")
local event = require("event")
local computer = require("computer")
local internet = {settings = {}}
internet.settings.timeout = 3
internet.settings.downloadPart = 1024 * 32
internet.settings.pingHost = "http://google.com"

local unknown = "unknown error"

local cardIterator
function internet.card() --поралелит нагрузку на несколько инетных карт, чтобы можно было открыть больше сокетов итд
    if cardIterator then
        local result = cardIterator()
        if result then
            return result
        end
    end

    cardIterator = component.list("internet", true)
    if cardIterator then
        return (cardIterator())
    end
end

function internet.cardProxy()
    return component.proxy(internet.card() or "")
end

function internet.check()
    local proxy = internet.cardProxy()
    if proxy then
        local handle = proxy.request(internet.settings.pingHost)
        if handle then
            local data = handle.read()
            pcall(handle.close)
            if data then
                return true
            end
        end
    end
    return false
end

function internet.wait(handle, waittime)
    local startTime = computer.uptime()
    while true do
        local successfully, err = handle.finishConnect()
        if successfully then
            return true
        elseif successfully == nil then
            return nil, tostring(err or unknown)
        end

        if computer.uptime() - startTime > (waittime or internet.settings.timeout) then
            return nil, "timeout error"
        end

        event.yield()
    end
end

function internet.readAll(handle)
    local data = {}
    while true do
        local result, reason = handle.read(math.huge) 
        if result then
            table.insert(data, result)
        else
            handle.close()
            
            if reason then
                return nil, reason
            else
                return table.concat(data)
            end
        end
    end
end

function internet.get(url)
    local inet = internet.cardProxy()
    if not inet then
        return nil, "no internet-card"
    end

    local handle, err = inet.request(url)
    if handle then
        local successfully, err = internet.wait(handle)
        if not successfully then
            return nil, err
        end

        return internet.readAll(handle)
    else
        return nil, tostring(err or unknown)
    end
end

function internet.download(url, path)
    local inet = internet.cardProxy()
    if not inet then
        return nil, "no internet-card"
    end

    local handle, err = inet.request(url)
    if handle then
        local successfully, err = internet.wait(handle)
        if not successfully then
            return nil, err
        end

        fs.makeDirectory(paths.path(path))
        local file, err = fs.open(path, "wb")
        if not file then
            return nil, err
        end
        
        local data = {}
        local dataSize = 0
        while true do
            local result, reason = handle.read(math.huge) 
            if result then
                table.insert(data, result)
                dataSize = dataSize + #result

                if dataSize >= internet.settings.downloadPart then
                    file.write(table.concat(data))
                    data = {}
                    dataSize = 0
                end
            else
                if #data > 0 then
                    file.write(table.concat(data))
                end
                file.close()
                handle.close()
                
                if reason then
                    return nil, reason
                else
                    return true
                end
            end
        end
    else
        return nil, tostring(err or unknown)
    end
end

local function removeTrues(results)
    for i, tbl in ipairs(results) do
        if tbl[1] == true then
            table.remove(tbl, 1)
        end
    end
    return results
end

function internet.downloads(downloads)
    local thread = require("thread")
    local threads = {}
    for _, download in ipairs(downloads) do
        local th = thread.create(internet.download, table.unpack(download))
        table.insert(threads, th)
        th:resume()
    end
    return removeTrues(thread.waitForAll(threads))
end

function internet.gets(gets)
    local thread = require("thread")
    local threads = {}
    for _, url in ipairs(gets) do
        local th = thread.create(internet.get, url)
        table.insert(threads, th)
        th:resume()
    end
    return removeTrues(thread.waitForAll(threads))
end

internet.getInternetFile = internet.get
internet.unloadable = true
return internet