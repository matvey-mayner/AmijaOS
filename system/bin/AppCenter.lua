local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer
WinType = "show"

mayner.Window()
gpu.set(12, 4, "AppCenter")
  mayner.DrawButton(66, 4, 7, 1, "X", 0x000000, 0xFF0000, function()
    if WinType == "show" then
      WinType = "hide"
      gpu.setBackground(0x6BC1F7)
      gpu.fill(12, 4, 63, 20, " ")
    end
end)

mayner.DrawButton(30, 8, 7, 3, "FileManager", 0x000000, 0xFFFFFF, function()
      assert(prog.execute("/system/bin/filemanager.lua"))
end)  
