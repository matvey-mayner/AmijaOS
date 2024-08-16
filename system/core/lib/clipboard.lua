local cache = require("cache")
local component = require("component")
local clipboard = {}
clipboard.realClipboard = true
clipboard.defaultUser = "default"

function clipboard.get(user)
    if not cache.data.clipboard then cache.data.clipboard = {} end
    return cache.data.clipboard[user or clipboard.defaultUser]
end

function clipboard.set(user, content)
    if not cache.data.clipboard then cache.data.clipboard = {} end
    cache.data.clipboard[user or clipboard.defaultUser] = content

    if content and clipboard.realClipboard and component.debug then
        component.debug.sendToClipboard(user, content)
    end
end

clipboard.unloadable = true
return clipboard