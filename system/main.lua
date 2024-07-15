local component = require("component")
local gpu = component.gpu
local computer = require("computer")

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
gpu.set(34, 12, "AmijaOS")

drawLoadingBar()
local fs = require("filesystem")
local mayner = require("MAYNERAPI")
local event = require("event")

local function workspace()

gpu.setBackground(0xFFFFFF)
gpu.setForeground(0x000000)
gpu.fill(1, 1, 80, 1, " ")

------------------------------------Main-WorkSpace------------------------------
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x6BC1F7)
gpu.fill(1, 1, 80, 25, " ")
  
mayner.DrawButton(1, 1, 1, 1, "AmijaOS", 0x000000, 0xFFFFFF, function()
      computer.shutdown()
end)
--------------------------------------------------------------------------------
while true do
    event.pull("touch")
end
end
