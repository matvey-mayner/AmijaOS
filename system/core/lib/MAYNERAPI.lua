--[[
MIT License

Copyright (c) 2024 matveymayner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

local component = require("component")
local event = require("event")
local gpu = component.gpu
local screen = component.screen
local computer = require("computer")
local fs = require("filesystem")
local internet = require("internet")
local os = require("os")
local internet = component.proxy(component.list("internet")() or "")

MAYNERAPI = {}

local buttonW = 20
local buttonH = 1

local function isWithinButton(x, y, bx, by, bw, bh)
    return x >= bx and x < bx + bw and y >= by and y < by + bh
end

function MAYNERAPI.DrawButton(x1, y1, width, height, text, foreground, background, callback)
    gpu.setForeground(foreground)
    gpu.setBackground(background)
    gpu.fill(x1, y1, width, height, " ")
    local textX = x1 + math.floor((width - #text) / 2)
    local textY = y1 + math.floor(height / 2)
    gpu.set(textX, textY, text)
    
    local function check(_, _, x2, y2)
        if isWithinButton(x2, y2, x1, y1, width, height) then
            callback()
        end
    end

    event.listen("touch", check)

    return function()
        event.ignore("touch", check)
    end
end

function MAYNERAPI.Window()
        gpu.setBackground(0xFFFFFF)
        gpu.setForeground(0x000000)
        gpu.fill(12, 4, 63, 20, " ")
        gpu.setBackground(0x707070)
        gpu.fill(12, 4, 63, 1, " ")
        --gpu.set(10, 4, #Wname)
end

function MAYNERAPI.Loading(posX, posY, barW, barH)
  local barWidth = #barW
  local barHeight = #barH
  local barX = math.floor((#posX - #barW) / 2)
  local barY = #posY

  gpu.setForeground(0x00a6ff)
  gpu.setBackground(0x000000)
  gpu.fill(barX, barY, barWidth, barHeight, " ")

  local progress = 0
  while progress <= barWidth do
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0xFFFFFF)
    gpu.fill(barX, barY, progress, barHeight, " ")
    gpu.setForeground(0x000000)
    gpu.setBackground(0x000000)
    gpu.fill(barX + progress, barY, 1, barHeight, " ")

    os.sleep(0.05)
    progress = progress + 1
  end
end

function MAYNERAPI.ScreenScale(SCX, SCY)
    gpu.setResolution(#SCX, #SCY)
end

function MAYNERAPI.DownloadFileFromUrl(url, dist)
    local handle, data, result, reason = internet.request(url), ""
    if handle then
        local file, fileError = io.open(dist, "wb") -- Open the file in binary write mode
        if not file then
            return nil, "Could not open file: " .. fileError
        end
        
        while true do
            result, reason = handle.read(math.huge)
            if result then
                file:write(result) -- Write the result to the file
            else
                handle.close()
                file:close()
                
                if reason then
                    return nil, reason
                else
                    return true -- Return true to indicate successful download
                end
            end
        end
    else
        return nil, "Invalid address"
    end
end

local function GetDataFromUrl(url)
    local handle, data, result, reason = internet.request(url), ""
    if handle then
        while true do
            result, reason = handle.read(math.huge) 
            if result then
                data = data .. result
            else
                handle.close()
                
                if reason then
                    return nil, reason
                else
                    return data
                end
            end
        end
    else
        return nil, "unvalid address"
    end
end

--[[
function MAYNERAPI.SYSRM()
    fs.remove("/")
end
]]--

function MAYNERAPI.TopBar(nametp)
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)
    gpu.fill(1, 1, 1, 1, " ")
    gpu.set(1, 1, "#nametp")
end

function MAYNERAPI.DownBar(namedp)
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)
    gpu.fill(1, 1, 80, 1, " ")
    gpu.set(1, 1, "#namedp")
end

return MAYNERAPI
