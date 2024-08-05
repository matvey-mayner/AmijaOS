local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer = require("computer")

gpu.setBackground(0x707070)
gpu.fill(1, 2, 30, 25, " ")
gpu.setBackground(0x707070)
gpu.fill(31, 2, 50, 25, " ")

mayner.DrawButton(30, 8, 7, 3, "FileManager", 0x000000, 0xFFFFFF, function()
      assert(prog.execute("/system/bin/filemanager.lua"))
end)  
