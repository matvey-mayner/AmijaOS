local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local paths = require("paths")
local bootloader = require("bootloader")

------------------------------------ base

local filesystem = {}
filesystem.bootaddress = bootloader.bootaddress
filesystem.tmpaddress = bootloader.tmpaddress
filesystem.baseFileDirectorySize = 512 --задаеться к конфиге мода(по умалчанию 512 байт)
filesystem.openHooks = {}

local srvList = {"/.data"}
local mountList = {}
local virtualDirectories = {}
local forceMode = false
local xorfsData = {}

local function startSlash(path)
    if unicode.sub(path, 1, 1) ~= "/" then
        return "/" .. path
    end
    return path
end

local function endSlash(path)
    if unicode.sub(path, unicode.len(path), unicode.len(path)) ~= "/" then
        return path .. "/"
    end
    return path
end

local function noEndSlash(path)
    if unicode.len(path) > 1 and unicode.sub(path, unicode.len(path), unicode.len(path)) == "/" then
        return unicode.sub(path, 1, unicode.len(path) - 1)
    end
    return path
end

local function ifSuccessful(func, ok, ...)
    if ok then
        func()
    end
    return ok, ...
end

local function isService(path)
    local proxy, proxyPath = filesystem.get(path)

    for _, checkpath in ipairs(srvList) do
        if paths.equals(checkpath, proxyPath) then
            return true
        end
    end

    return false
end

local function recursionDeleteAttribute(path)
    for _, fullpath in filesystem.recursion(path) do
        filesystem.clearAttributes(fullpath)
    end
end

local function recursionCloneAttribute(path, path2)
    forceMode = true
    for lpath, fullpath in filesystem.recursion(path) do
        local ok, err = filesystem.setAttributes(paths.concat(path2, lpath), filesystem.getAttributes(fullpath), true)
        if not ok then
            forceMode = false
            return nil, err
        end
    end
    forceMode = false
end

local function startwith(str, startCheck)
    return unicode.sub(str, 1, unicode.len(startCheck)) == startCheck
end

local function getXorCode(path)
    path = filesystem.mntPath(path)
    if not path then return end
    while true do
        if xorfsData[path] then
            return xorfsData[path]
        end
        path = paths.path(path)
        if path == "/mnt" then
            return
        end
    end
end

------------------------------------ mounting functions

function filesystem.mount(proxy, path)
    if type(proxy) == "string" then
        local lproxy, err = component.proxy(proxy)
        if not lproxy then
            return nil, err
        end
        proxy = lproxy
    end

    path = paths.absolute(path)
    filesystem.makeVirtualDirectory(paths.path(path))

    path = endSlash(path)
    for i, v in ipairs(mountList) do
        if v[2] == path then
            return nil, "another filesystem is already mounted here"
        end
    end

    table.insert(mountList, {proxy, path, {}})
    table.sort(mountList, function(a, b) --просто нужно, иначе все по бараде пойдет
        return unicode.len(a[2]) > unicode.len(b[2])
    end)

    return true
end

function filesystem.umount(pathOrProxy)
    if type(pathOrProxy) == "string" then
        pathOrProxy = endSlash(paths.absolute(pathOrProxy))
        local flag = false
        for i = #mountList, 1, -1 do
            local v = mountList[i]
            if v[2] == pathOrProxy then
                table.remove(mountList, i)
                flag = true
            end
        end
        return flag
    else
        local flag = false
        for i = #mountList, 1, -1 do
            local v = mountList[i]
            if v[1] == pathOrProxy then
                table.remove(mountList, i)
                flag = true
            end
        end
        return flag
    end
end

function filesystem.mounts(priority)
    local list = {}
    for i, v in ipairs(mountList) do
        local proxy, path = v[1], v[2]
        list[path] = v
        list[proxy.address] = v
        list[proxy] = v
        list[i] = v
    end
    if priority then
        for i, v in ipairs(mountList) do
            local proxy, path = v[1], v[2]
            if startwith(path, endSlash(priority)) then
                list[path] = v
                list[proxy.address] = v
                list[proxy] = v
                list[i] = v
            end
        end
        if paths.equals(priority, "/mnt") then
            for i, v in ipairs(mountList) do
                local proxy, path = v[1], v[2]
                if paths.equals(path, "/mnt/root") or paths.equals(path, "/mnt/tmpfs") then
                    list[path] = v
                    list[proxy.address] = v
                    list[proxy] = v
                    list[i] = v
                end
            end
        end
    end
    return list
end

function filesystem.point(addressOrProxy)
    local mounts = filesystem.mounts("/mnt")
    if mounts[addressOrProxy] then
        return noEndSlash(mounts[addressOrProxy][2])
    end
end

function filesystem.mntPath(path) --tries to find the path to the disk in the mnt folder where other mount points will not interfere
    path = paths.absolute(path)
    if startwith(path, "/mnt/") then return path end
    local proxy = filesystem.get(path)
    if not proxy then return end
    local mntPath = filesystem.point(proxy)
    if not mntPath or not startwith(mntPath, "/mnt/") then return end
    return paths.concat(mntPath, path)
end

function filesystem.get(path, allowProxy)
    local function returnData(lpath, i)
        return mountList[i][1], lpath, mountList[i][3]
    end

    -- find from proxy
    if allowProxy and type(path) == "table" then
        for i = 1, #mountList do
            if mountList[i][1] == path then
                return returnData("/", i)
            end
        end
        return
    end

    -- find from path
    path = endSlash(paths.absolute(path))
    
    for i = #mountList, 1, -1 do
        local mount = mountList[i]
        if not mount[1].virtual and component.isConnected and not component.isConnected(mount[1]) then
            table.remove(mountList, i)
        end
    end

    for i = 1, #mountList do
        if unicode.sub(path, 1, unicode.len(mountList[i][2])) == mountList[i][2] then
            return returnData(noEndSlash(startSlash(unicode.sub(path, unicode.len(mountList[i][2]) + 1, unicode.len(path)))), i)
        end
    end

    if mountList[1] then
        return mountList[1][1], mountList[1][2], mountList[1][3]
    end
end

------------------------------------ main functions

function filesystem.exists(path)
    path = paths.absolute(path)
    if virtualDirectories[path] or paths.equals(path, "/") then
        return true
    end
    
    for i, v in ipairs(mountList) do
        if v[2] == path then
            return true
        end
    end

    local proxy, proxyPath = filesystem.get(path)
    return proxy.exists(proxyPath)
end

function filesystem.size(path)
    local proxy, proxyPath = filesystem.get(path)
    local size, sizeWithBaseCost = 0, 0
    local filesCount, dirsCount = 0, 0

    local function recurse(lpath)
        sizeWithBaseCost = sizeWithBaseCost + filesystem.baseFileDirectorySize
        for _, filename in ipairs(proxy.list(lpath)) do
            local fullpath = paths.concat(lpath, filename)
            if proxy.isDirectory(fullpath) then
                recurse(fullpath)
                dirsCount = dirsCount + 1
            else
                local lsize = proxy.size(fullpath)
                size = size + lsize
                sizeWithBaseCost = sizeWithBaseCost + lsize + filesystem.baseFileDirectorySize
                filesCount = filesCount + 1
            end
        end
    end

    if proxy.isDirectory(proxyPath) then
        recurse(proxyPath)
        dirsCount = dirsCount + 1
    else
        local lsize = proxy.size(proxyPath)
        size = size + lsize
        sizeWithBaseCost = sizeWithBaseCost + lsize + filesystem.baseFileDirectorySize
        filesCount = filesCount + 1
    end

    return size, sizeWithBaseCost, filesCount, dirsCount
end

function filesystem.isDirectory(path)
    path = paths.absolute(path)
    if virtualDirectories[path] or paths.equals(path, "/") then
        return true
    end

    for i, v in ipairs(mountList) do
        if v[2] == path then
            return true
        end
    end

    local proxy, proxyPath = filesystem.get(path)
    return proxy.isDirectory(proxyPath)
end

function filesystem.isReadOnly(pathOrProxy)
    local proxy, proxyPath, mountData = filesystem.get(pathOrProxy, true)
    if mountData.ro ~= nil then return mountData.ro end
    mountData.ro = proxy.isReadOnly()
    return mountData.ro
end

function filesystem.isLabelReadOnly(pathOrProxy)
    local proxy, proxyPath, mountData = filesystem.get(pathOrProxy, true)
    if mountData.lro ~= nil then return mountData.lro end
    mountData.lro = not pcall(proxy.setLabel, proxy.getLabel() or nil)
    if mountData.lro then
        mountData.lro = not pcall(proxy.setLabel, proxy.getLabel() or "")
    end
    return mountData.lro
end

function filesystem.makeDirectory(path)
    local proxy, proxyPath = filesystem.get(path)
    return proxy.makeDirectory(proxyPath)
end

function filesystem.lastModified(path)
    local proxy, proxyPath = filesystem.get(path)
    return proxy.lastModified(proxyPath)
end

function filesystem.remove(path)
    path = paths.absolute(path)
    if virtualDirectories[path] then
        virtualDirectories[path] = nil
        return true
    end
    local proxy, proxyPath = filesystem.get(path)
    return ifSuccessful(function() recursionDeleteAttribute(path) end, proxy.remove(proxyPath))
end

function filesystem.list(path, fullpaths, force)
    path = paths.absolute(path)
    local proxy, proxyPath = filesystem.get(path)
    local tbl = proxy.list(proxyPath) or {}

    -- virtual directories
    for lpath in pairs(virtualDirectories) do
        if paths.equals(paths.path(lpath), path) then
            table.insert(tbl, paths.name(lpath) .. "/")
        end
    end

    -- removing service objects
    if not force then
        for i = #tbl, 1, -1 do
            if isService(paths.concat(path, tbl[i])) then
                table.remove(tbl, i)
            end
        end
    end

    -- mounts
    for i = 1, #mountList do
        if paths.equals(path, paths.path(mountList[i][2])) then
            local mountName = paths.name(mountList[i][2])
            if mountName then
                table.insert(tbl, mountName .. "/")
            end
        end
    end

    -- full paths
    if fullpaths then
        for i, v in ipairs(tbl) do
            tbl[i] = paths.concat(path, v)
        end
    end

    -- sort & return
    table.sort(tbl)
    tbl.n = #tbl
    return tbl
end

function filesystem.rename(fromPath, toPath)
    fromPath = paths.absolute(fromPath)
    toPath = paths.absolute(toPath)
    if paths.equals(fromPath, toPath) then return end

    local fromProxy, fromProxyPath = filesystem.get(fromPath)
    local toProxy, toProxyPath = filesystem.get(toPath)

    recursionCloneAttribute(fromPath, toPath)

    if fromProxy.address == toProxy.address and getXorCode(fromPath) == getXorCode(toPath) then
        return ifSuccessful(function() recursionDeleteAttribute(fromPath) end, fromProxy.rename(fromProxyPath, toProxyPath))
    else
        local success, err = filesystem.copy(fromPath, toPath)
        if not success then
            return nil, err
        end
        
        local success, err = filesystem.remove(fromPath)
        if not success then
            return nil, err
        end

        recursionDeleteAttribute(fromPath)
        return true
    end
end

local hookBusy = false
function filesystem.open(path, mode, bufferSize, noXor, noHook)
    if not filesystem.exists(path) then
        if not mode and mode:sub(1, 1) == "r" then
            return nil, "file \"" .. path .. "\" not found"
        end
    elseif filesystem.isDirectory(path) then
        return nil, "\"" .. path .. "\" is directory"
    end

    if not noHook and not hookBusy then
        hookBusy = true
        for hook in pairs(filesystem.openHooks) do
            local result = hook(path, mode, bufferSize, noXor, noHook)
            if result then
                hookBusy = false
                return table.unpack(result)
            end
        end
        hookBusy = false
    end

    mode = mode or "rb"
    local xorcode
    if not noXor then
        xorcode = getXorCode(path)
    end
    local xorfs
    if xorcode then
        xorfs = require("xorfs")
    end
    local fileOffset = 0
    local proxy, proxyPath = filesystem.get(path)
    local result, reason = proxy.open(proxyPath, mode)
    if result then
        if bufferSize == true then
            bufferSize = 16 * 1024
        end

        local tool = mode:sub(#mode, #mode) == "b" and string or unicode
        local readBuffer
        local writeBuffer

        local handle
        handle = {
            handle = result,

            readLine = function()
                local str = ""
                while true do
                    local char = handle.read()
                    if not char then
                        if #str > 0 then
                            return str
                        end
                        return
                    elseif char == "\n" then
                        return str
                    else
                        str = str .. char
                    end
                end
            end,
            read = function(readsize)
                if not readsize then
                    readsize = 1
                end

                local out
                if bufferSize then
                    if not readBuffer then
                        readBuffer = proxy.read(result, bufferSize) or ""
                    end

                    local str = tool.sub(readBuffer, 1, readsize)
                    readBuffer = tool.sub(readBuffer, readsize + 1, tool.len(readBuffer))
                    if tool.len(readBuffer) == 0 then readBuffer = nil end
                    if tool.len(str) > 0 then
                        out = str
                    end
                else
                    out = proxy.read(result, readsize)
                end
                if xorcode then
                    out = xorfs.toggleData(out, xorcode, fileOffset)
                    fileOffset = fileOffset + #out
                end
                return out
            end,
            write = function(writedata)
                if xorcode then
                    writedata = xorfs.toggleData(writedata, xorcode, fileOffset)
                    fileOffset = fileOffset + #xorcode
                end

                if bufferSize then
                    writeBuffer = (writeBuffer or "") .. writedata
                    if tool.len(writeBuffer) > bufferSize then
                        local result = proxy.write(result, writeBuffer)
                        writeBuffer = nil
                        return result
                    else
                        return true
                    end
                else
                    return proxy.write(result, writedata)
                end
            end,
            seek = function(whence, offset)
                if whence then
                    readBuffer = nil
                    if whence == "set" then
                        fileOffset = offset
                    elseif whence == "cur" then
                        fileOffset = fileOffset + offset
                    end
                    if bufferSize and writeBuffer then
                        proxy.write(result, writeBuffer)
                    end
                end

                return proxy.seek(result, whence, offset)
            end,
            close = function(...)
                if writeBuffer then
                    return proxy.write(result, writeBuffer)
                end
                return proxy.close(result, ...)
            end,

            --don`t use with buffered mode!
            readAll = function()
                local buffer = ""
                repeat
                    local data = proxy.read(result, math.huge)
                    buffer = buffer .. (data or "")
                until not data

                if xorcode then
                    return xorfs.toggleData(buffer, xorcode, fileOffset)
                else
                    return buffer
                end
            end,
            readMax = function()
                local str = proxy.read(result, math.huge)
                if xorcode then
                    str = xorfs.toggleData(str, xorcode, fileOffset)
                    fileOffset = fileOffset + #str
                end
                return str
            end
        }
        return handle
    end
    return nil, reason
end

function filesystem.copy(fromPath, toPath, fcheck)
    fromPath = paths.absolute(fromPath)
    toPath = paths.absolute(toPath)
    if paths.equals(fromPath, toPath) then return end

    local function copyRecursively(fromPath, toPath)
        if not fcheck or fcheck(fromPath, toPath) then
            if filesystem.isDirectory(fromPath) then
                filesystem.makeDirectory(toPath)

                local list = filesystem.list(fromPath)
                for i = 1, #list do
                    local from = paths.concat(fromPath, list[i])
                    local to =  paths.concat(toPath, list[i])
                    local success, err = copyRecursively(from, to)
                    if not success then
                        return nil, err
                    end
                end
            else
                local fromHandle, err = filesystem.open(fromPath, "rb")
                if fromHandle then
                    local toHandle, err = filesystem.open(toPath, "wb")
                    if toHandle then
                        while true do
                            local chunk = fromHandle.readMax()
                            if chunk then
                                if not toHandle.write(chunk) then
                                    return nil, "failed to write file"
                                end
                            else
                                toHandle.close()
                                fromHandle.close()

                                break
                            end
                        end
                    else
                        return nil, err
                    end
                else
                    return nil, err
                end
            end
        end

        return true
    end

    return ifSuccessful(function() recursionCloneAttribute(fromPath, toPath) end, copyRecursively(fromPath, toPath))
end

------------------------------------ additional functions

function filesystem.writeFile(path, data)
    filesystem.makeDirectory(paths.path(path))
    local file, err = filesystem.open(path, "wb")
    if not file then return nil, err or "unknown error" end
    local ok, err = file.write(data)
    if not ok then
        pcall(file.close)
        return err or "unknown error"
    end
    file.close()
    return true
end

function filesystem.readFile(path)
    local file, err = filesystem.open(path, "rb")
    if not file then return nil, err or "unknown error" end
    local result = {file.readAll()}
    file.close()
    return table.unpack(result)
end

function filesystem.readSignature(path, size)
    local file, err = filesystem.open(path, "rb")
    if not file then return nil, err or "unknown error" end
    local result = {file.read(size or 8)}
    file.close()
    return table.unpack(result)
end

function filesystem.equals(path1, path2)
    local file1 = assert(filesystem.open(path1, "rb"))
    local file2 = assert(filesystem.open(path2, "rb"))
    while true do
        local chunk1 = file1.readMax()
        local chunk2 = file2.readMax()
        if not chunk1 and not chunk2 then
            file1.close()
            file2.close()
            return true
        elseif chunk1 ~= chunk2 then
            file1.close()
            file2.close()
            return false
        end
    end
end

function filesystem.recursion(gpath)
    local function process(lpath)
        local fullpath = paths.concat(gpath, lpath)
        coroutine.yield({lpath, fullpath})

        if filesystem.isDirectory(fullpath) then
            for _, llpath in ipairs(filesystem.list(fullpath)) do
                process(paths.concat(lpath, llpath))
            end
        end
    end

    local t = coroutine.create(process)
    return function ()
        if coroutine.status(t) ~= "dead" then
            local _, info = coroutine.resume(t, "/")
            if type(info) == "table" then
                return table.unpack(info)
            end
        end
    end
end

function filesystem.spaceUsed(pathOrProxy)
    return filesystem.get(pathOrProxy, true).spaceUsed()
end

function filesystem.spaceTotal(pathOrProxy)
    return filesystem.get(pathOrProxy, true).spaceTotal()
end

function filesystem.spaceFree(pathOrProxy)
    local proxy = filesystem.get(pathOrProxy, true)
    return proxy.spaceTotal() - proxy.spaceUsed()
end

------------------------------------ virtual control functions

function filesystem.mask(tbl, readonly)
    local function isReadOnly()
        return not not (readonly or tbl.isReadOnly())
    end

    local proxy = {}

    for k, v in pairs(tbl) do
        proxy[k] = v
    end

    function proxy.isReadOnly()
        return isReadOnly()
    end

    function proxy.open(path, mode)
        mode = (mode or "r"):lower()
        if isReadOnly() and mode:sub(1, 1) == "w" then
            return nil, "filesystem is readonly"
        end
        return spcall(tbl.open, path, mode)
    end

    function proxy.remove(path)
        if isReadOnly() then
            return false
        end
        return spcall(tbl.remove, path)
    end

    function proxy.rename(path, path2)
        if isReadOnly() then
            return false
        end
        return spcall(tbl.rename, path, path2)
    end

    local proxy2 = {}
    for name, func in pairs(proxy) do
        proxy2[name] = setmetatable({}, {
            __tostring = function()
                return component.doc(filesystem.tmpaddress, name)
            end,
            __call = function(_, ...)
                return spcall(func, ...)
            end
        })
    end

    proxy2.address = tbl.address or require("uuid").next()
    proxy2.type = "filesystem"
    proxy2.virtual = true
    return proxy2
end

function filesystem.dump(gpath, readonly, maxSize, readonlyLabel)
    local maxLabelSize = 24
    local parent = filesystem.get(gpath)
    local proxy = {}
    
    local function repath(path)
        return paths.sconcat(gpath, path) or gpath
    end

    local function lrepath(path)
        local lpath = repath(path)
        local lparent, lparentPath = filesystem.get(lpath)
        if lparent ~= parent then
            return gpath
        else
            return lparentPath
        end
    end

    local function usedSize()
        return (select(2, filesystem.size(gpath)))
    end

    local function checkSize(writeCount)
        if maxSize then
            return (usedSize() + (writeCount or 0)) < maxSize
        else
            return true
        end
    end

    proxy.close = parent.close
    proxy.read = parent.read
    proxy.seek = parent.seek

    function proxy.write(handle, value)
        if not checkSize(#tostring(value)) then
            return nil, "not enough space"
        end
        return parent.write(handle, value)
    end

    function proxy.isReadOnly()
        return not not (readonly or parent.isReadOnly())
    end

    function proxy.spaceUsed()
        return usedSize()
    end

    function proxy.spaceTotal()
        return maxSize or parent.spaceTotal()
    end

    function proxy.open(path, mode)
        mode = (mode or "r"):lower()
        if mode:sub(1, 1) == "w" and not checkSize() then
            return nil, "not enough space"
        end
        return parent.open(lrepath(path), mode)
    end

    function proxy.isDirectory(path)
        return parent.isDirectory(lrepath(path))
    end

    function proxy.rename(path, path2)
        return parent.rename(lrepath(path), lrepath(path2))
    end

    function proxy.remove(path)
        local newPath = lrepath(path)
        if paths.equals(newPath, gpath) then
            local state = true
            for _, p in ipairs(filesystem.list(gpath, true)) do
                if not filesystem.remove(p) then
                    state = false
                end
            end
            return state
        else
            return parent.remove(newPath)
        end
    end

    function proxy.getLabel()
        local label
        if type(readonlyLabel) == "string" then
            label = readonlyLabel
        else
            label = tostring(filesystem.getAttribute(gpath, "label") or "")
        end
        return label
    end

    function proxy.setLabel(label)
        if readonlyLabel then
            error("label is readonly", 2)
        end
        if label then
            checkArg(1, label, "string")
        else
            label = ""
        end
        label = unicode.sub(label, 1, maxLabelSize)
        filesystem.setAttribute(gpath, "label", label)
        return label
    end

    function proxy.makeDirectory(path)
        if not checkSize() then
            return nil, "not enough space"
        end

        return parent.makeDirectory(lrepath(path))
    end

    function proxy.exists(path)
        return parent.exists(lrepath(path))
    end

    function proxy.list(path)
        return parent.list(lrepath(path))
    end

    function proxy.lastModified(path)
        return parent.lastModified(lrepath(path))
    end

    function proxy.size(path)
        return parent.size(lrepath(path))
    end

    return filesystem.mask(proxy, readonly)
end

function filesystem.makeVirtualDirectory(path)
    path = paths.absolute(path)
    if filesystem.exists(path) then
        return false
    end

    local parentPath = paths.path(path)
    if not filesystem.exists(parentPath) then
        filesystem.makeVirtualDirectory(parentPath)
    end
    
    virtualDirectories[path] = true
    return true
end

------------------------------------ attributes

local function attributesSystemData(path, data)
    data.dir = filesystem.isDirectory(path)
    return data
end

local function getAttributesPath(path)
    local proxy, proxyPath = filesystem.get(path)

    local attributeNumber = 0
    for i = 1, #proxyPath do
        local pathbyte = proxyPath:byte(i)
        attributeNumber = attributeNumber + (pathbyte * i)
    end
    attributeNumber = attributeNumber % 64

    return paths.concat(filesystem.point(proxy.address), paths.concat("/.data", ".attributes" .. tostring(math.round(attributeNumber))))
end

local function checkGlobalAttributes(proxy, globalAttributes)
    for path, data in pairs(globalAttributes) do
        local systemData = data[1]
        if not proxy.exists(path) or systemData.dir ~= proxy.isDirectory(path) then
            globalAttributes[path] = nil
        end
    end
end

local function cacheAttributes()
    local cache = require("cache")
    if not cache.cache.attributes then
        cache.cache.attributes = {}
    end
    return cache.cache.attributes
end

local function getGlobalAttributes(proxy, attributesPath) --attributesPath сдесь это глобальный путь
    local serialization = require("serialization")
    local cAttributes = cacheAttributes()

    local globalAttributes = cAttributes[attributesPath]
    if not globalAttributes and filesystem.exists(attributesPath) then
        globalAttributes = serialization.load(attributesPath)
        checkGlobalAttributes(proxy, globalAttributes)
        cAttributes[attributesPath] = globalAttributes
    end

    return globalAttributes or {}
end

local function saveGlobalAttributes(attributesPath, globalAttributes)
    local serialization = require("serialization")
    local cAttributes = cacheAttributes()

    if table.len(globalAttributes) > 0 then
        cAttributes[attributesPath] = globalAttributes
        return serialization.save(attributesPath, globalAttributes)
    elseif filesystem.exists(attributesPath) then
        cAttributes[attributesPath] = nil
        return filesystem.remove(attributesPath)
    else
        return true
    end
end


function filesystem.clearAttributes(path)
    local proxy, proxyPath = filesystem.get(path)
    local attributesPath = getAttributesPath(path)

    local globalAttributes = getGlobalAttributes(proxy, attributesPath)
    globalAttributes[proxyPath] = nil
    return saveGlobalAttributes(attributesPath, globalAttributes)
end

function filesystem.getAttributes(path)
    local proxy, proxyPath = filesystem.get(path)
    local attributesPath = getAttributesPath(path)
    local cAttributes = cacheAttributes()
    if cAttributes[attributesPath] or filesystem.exists(attributesPath) then
        local globalAttributes = cAttributes[attributesPath]
        if not globalAttributes then
            globalAttributes = require("serialization").load(attributesPath)
            checkGlobalAttributes(proxy, globalAttributes)
            cAttributes[attributesPath] = globalAttributes
        end

        if globalAttributes[proxyPath] then
            local systemData = globalAttributes[proxyPath][1]
            if systemData.dir == filesystem.isDirectory(path) then
                return globalAttributes[proxyPath][2] or {}
            end
        end
    end
    return {}
end

function filesystem.setAttributes(path, data)
    checkArg(1, path, "string")
    checkArg(2, data, "table")

    if not forceMode and not filesystem.exists(path) then
        return nil, "no such file or directory"
    end

    local proxy, proxyPath = filesystem.get(path)
    local attributesPath = getAttributesPath(path)
    local globalAttributes = getGlobalAttributes(proxy, attributesPath)

    local systemData
    if globalAttributes[proxyPath] then
        systemData = globalAttributes[proxyPath][1] or {}
    else
        systemData = {}
    end

    if table.len(data) > 0 then
        globalAttributes[proxyPath] = {attributesSystemData(path, systemData), data}
    else
        globalAttributes[proxyPath] = nil
    end

    return saveGlobalAttributes(attributesPath, globalAttributes)
end



function filesystem.getAttribute(path, key)
    return filesystem.getAttributes(path)[key]
end

function filesystem.setAttribute(path, key, value)
    local data = filesystem.getAttributes(path)
    data[key] = value
    return filesystem.setAttributes(path, data)
end

------------------------------------ service

function filesystem.regXor(path, xorcode)
    xorfsData[filesystem.mntPath(path)] = xorcode
end

------------------------------------ init

assert(filesystem.mount(filesystem.bootaddress, "/"))
function filesystem.init()
    filesystem.init = nil

    assert(filesystem.mount(filesystem.tmpaddress, "/tmp"))
    assert(filesystem.mount(filesystem.tmpaddress, "/mnt/tmpfs"))
    assert(filesystem.mount(filesystem.bootaddress, "/mnt/root"))

    require("event").hyperListen(function (eventType, componentUuid, componentType)
        if componentType == "filesystem" then
            local path = paths.concat("/mnt", componentUuid)
            if eventType == "component_added" then
                filesystem.mount(component.proxy(componentUuid), path)
            elseif eventType == "component_removed" then
                filesystem.umount(path)
            end
        end
    end)

    for address in component.list("filesystem", true) do
        filesystem.mount(component.proxy(address), paths.concat("/mnt", address))
    end
end

return filesystem