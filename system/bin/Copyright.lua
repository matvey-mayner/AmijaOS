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
gpu.set(25, 4, "AmijaOS 1.5 Cascade")
gpu.set(25, 5, "Copyright © 2024 - 2024")
gpu.set(25, 7, "Developers:")
gpu.set(25, 8 , "matveymayner, Discord: matveymayner")
gpu.set(25, 9, "snus, Discord: super_snus")
gpu.set(25, 10, "BigDanXvo, Discord: danxvo")
gpu.set(25, 11, "Logic")
gpu.set(25, 13, "Making MAYNERAPI")
gpu.set(25, 14, "matveymayner")
gpu.set(25, 15, "BigDanXvo")
gpu.set(25, 17, "AmijaOS site: amijaos.kernel.rf.gd")