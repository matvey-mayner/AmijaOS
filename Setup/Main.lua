local component = require("component")
local gpu = component.gpu
local mayner = require("MAYNERAPI")
local fs = require("filesystem")
local comp = require("computer")
local event = require("event")

gpu.setResolution(80, 25)

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x6BC1F7)
gpu.fill(1, 1, 80, 25, " ")

mayner.Window()

buttons1 = "Show" --Ох всякие странные переменый, и сюда пришли!

gpu.set(12, 4, "Amija OS Setup")

mayner.DrawButton(66, 4, 7, 1, "X", 0x000000, 0xFF0000, function()
    comp.shutdown()
end)

    gpu.setBackground(0x4a4a4a)
    gpu.setForeground(0x000000)
    gpu.fill(25, 6, 37, 15, " ")

---------------Это То что будет выводиться на тёмном прямоугольничке

    gpu.set(25, 6, "You agree with the GNU GPL V3")
    gpu.set(25, 7, "And The System Rules")
    gpu.set(25, 8, "When you install The System (AmijaOS)")
    gpu.set(25, 9, "!!!YOUR ALL DATA WILL BE ERASED!!!")
    gpu.set(25, 10, "!!!AND WHEN YOU INSTALLING AMIJAOS!!!")
    gpu.set(25, 11, "!!!YOUR EEPROM WILL BE REWRITED!!!")
    gpu.set(25, 12, "And you not have root access")
    gpu.set(25, 13, "To edit The system!")
    gpu.set(25, 14, "But Орешки тупитупи cant delete") -- Ну Это Правда!
    gpu.set(25, 15, "System!")

mayner.DrawButton(69, 23, 6, 1, "Accept", 0xFFFFFF, 0x4b4b4b, function()
  if buttons1 == "Show" then
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)

    gpu.fill(12, 23, 6, 1, " ")
    gpu.fill(69, 23, 6, 1, " ")
    gpu.fill(25, 6, 37, 15, " ")
      
    buttons1 = "Hide"
  end
end)

mayner.DrawButton(12, 23, 6, 1, "Cancel", 0xFFFFFF, 0x4b4b4b, function()
  if buttons1 == "Show" then
    comp.shutdown()
    end
end)
    
while true do
  event.pull("touch")
end
