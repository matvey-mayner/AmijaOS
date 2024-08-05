local component = require("component")
local gpu = component.gpu
local computer = require("computer")

StartType = "close"

gpu.setResolution(80, 25)

local function drawLoadingBar()
  local barWidth = 50
  local barHeight = 1
  local barX = math.floor((80 - barWidth) / 2)
  local barY = 13

  gpu.setForeground(0xFFFFFF)
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

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0xbb6058)
gpu.fill(1, 1, 80, 25, " ")

gpu.setBackground(0xbb6058)
gpu.setForeground(0xFFFFFF)
gpu.set(37, 12, "AmijaOS")

drawLoadingBar()
local fs = require("filesystem")
local mayner = require("MAYNERAPI")
local event = require("event")
local prog = require("programs")

------------------------------------Main-WorkSpace------------------------------
drawLoadingBar = nil --Почему мы так решили? потому что мы не крысы и оперативу жрать не будем

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x6BC1F7)
gpu.fill(1, 1, 80, 25, " ")

gpu.setBackground(0xFFFFFF)
gpu.setForeground(0x000000)
gpu.fill(1, 1, 80, 1, " ")

local function StartMenu()
  mayner.DrawButton(1, 2, 7, 1, "Shutdown ", 0x000000, 0xFFFFFF, function()
    if StartType == "open" then
        computer.shutdown()
      end
  end)

  mayner.DrawButton(1, 3, 7, 1, "Reboot   ", 0x000000, 0xFFFFFF, function()
        if StartType == "open" then
        computer.shutdown(true)
      end
  end)

    mayner.DrawButton(1, 4, 7, 1, "AppCenter", 0x000000, 0xFFFFFF, function()
        if StartType == "open" then
          StartType = "close"
          assert(prog.execute("/system/bin/AppCenter.lua"))
      end
  end)
end

mayner.DrawButton(1, 1, 7, 1, "AmijaOS", 0x000000, 0xFFFFFF, function()
      StartMenu()
      if StartType == "open" then

          gpu.setBackground(0xFFFFFF)
          gpu.setForeground(0x000000)
          gpu.set(1, 1, "AmijaOS")
        
        StartType = "close"
        gpu.setBackground(0x6BC1F7)
        gpu.fill(1, 2, 11, 3, " ")
    elseif StartType == "close" then
          gpu.setBackground(0x6699ff)
          gpu.setForeground(0x000000)
          gpu.set(1, 1, "AmijaOS")
      
      StartType = "open"
      StartMenu()
    end
end)


--------------------------------------------------------------------------------
while true do
    event.pull("touch")
end
