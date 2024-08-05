local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu

mayner.Window()
gpu.set(10, 4, "Exemple")
  mayner.DrawButton(63, 4, 7, 1, "X", 0x000000, 0xFF0000, function()
    gpu.setBackground(0x6BC1F7)
    gpu.fill(10, 4, 63, 20, " ")
end)
