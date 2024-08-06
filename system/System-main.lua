local component = require("component")
local gpu = component.gpu
local computer = require("computer")

StartType = "close"
AppOpen = nil

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
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x6BC1F7)
gpu.fill(1, 1, 80, 25, " ")

gpu.setBackground(0xFFFFFF)
gpu.setForeground(0x000000)
gpu.fill(1, 1, 80, 1, " ")

local function Start()
    mayner.DrawButton(1, 2, 12, 1, "shutdown    ", 0x000000, 0xFFFFFF, function()
      if StartType == "open" then
        computer.shutdown()
      end
    end)
    
     mayner.DrawButton(1, 3, 12, 1, "Reboot     ", 0x000000, 0xFFFFFF, function()
      if StartType == "open" then
        computer.shutdown(true)
      end
    end)
    
     mayner.DrawButton(1, 4, 12, 1, "file manager", 0x000000, 0xFFFFFF, function()
      if StartType == "open" then
        --assert(prog.execute("/system/bin/test.lua"))
        AppOpen = "/system/bin/test.lua"
        StartType = "close"
        gpu.setBackground(0xFFFFFF)
        gpu.setForeground(0x000000)
        gpu.set(1, 1, "AmijaOS")
      end
    end)
end

mayner.DrawButton(1, 1, 7, 1, "AmijaOS", 0x000000, 0xFFFFFF, function()
      Start()
      if StartType == "open" then
        
        gpu.setBackground(0xFFFFFF)
        gpu.setForeground(0x000000)
        gpu.set(1, 1, "AmijaOS")
        
        StartType = "close"
        gpu.setBackground(0x6BC1F7)
        gpu.fill(1, 2, 12, 3, " ")
      elseif StartType == "close" then
        gpu.setBackground(0x6699ff)
        gpu.setForeground(0x000000)
        gpu.set(1, 1, "AmijaOS")
        
        StartType = "open"
        Start()
      end
end)

local function clear(BackGround)
  gpu.setBackground(BackGround)
  gpu.fill(1, 2, 80, 25, " ")
  gpu.setBackground(0xFFFFFF)
  gpu.setForeground(0x000000)
  gpu.set(1, 1, "AmijaOS")
end

--------------------------------------------------------------------------------


---------------------------------hell---(сюда-лучше-не-идти)--------------------
while true do
    event.pull("touch")
    if AppOpen ~= nil then
      gpu.setBackground(0xFFFFFF)
      gpu.setForeground(0xFF0000)
      gpu.set(74, 1, "◖")
      gpu.set(80, 1, "◗")
      
      gpu.setForeground(0x000000)
      gpu.set(9, 1, "|")
      gpu.set(11, 1, AppOpen)
      mayner.DrawButton(75, 1, 5, 1, "  X  ", 0xFFFFFF, 0xFF0000, function()
        AppOpen = nil
        clear(0x6BC1F7)
      end)
      gpu.setBackground(0xFFFFF)
      gpu.setForeground(0xFF0000)
        
      if StartType == "close" then
        assert(prog.execute(AppOpen))
      end
    elseif AppOpen == nil then
      gpu.setBackground(0xFFFFFF)
      gpu.fill(8, 1, 80, 1, " ")
    end
    
end
--------------------------------------------------------------------------------
