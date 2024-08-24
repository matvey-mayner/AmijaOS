local mayner = require("MAYNERAPI")
local component = require("component")
local gpu = component.gpu
local computer = require("computer")

StartType = "close"

gpu.setBackground(0x000000)
gpu.fill(1, 2, 30, 25, " ")
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(31, 2, 50, 25, " ")
gpu.set(25, 2, "AmijaOS")
gpu.set(25, 3, "Copyright © 2024 - 2024")
gpu.set(25, 6, "Developers:")
gpu.set(25, 7, "matveymayner, Discord: matveymayner")
gpu.set(25, 8, "snus, Discord: super_snus")
gpu.set(25, 9, "BigDanXvo, Discord: danxvo")
gpu.set(25, 10, "Logic")
gpu.set(25, 12, "Making API")
gpu.set(25, 13, "matveymayner")
gpu.set(25, 14, "BigDanXvo")
