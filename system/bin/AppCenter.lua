local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer = require("computer")



mayner.DrawButton(30, 8, 7, 3, "FileManager", 0x000000, 0xFFFFFF, function()
      assert(prog.execute("/system/bin/filemanager.lua"))
end)  
