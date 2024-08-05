local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer

mayner.Window()
gpu.set(12, 4, "Exemple")
  mayner.DrawButton(66, 4, 7, 1, "X", 0x000000, 0xFF0000, function()
    gpu.setBackground(0x6BC1F7)
    gpu.fill(12, 4, 63, 20, " ")
end)
