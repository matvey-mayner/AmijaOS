local component = require("component")
local fs = require("filesystem")
local event = require("event")
local gpu = component.gpu
local mayner = require("MAYNERAPI")
-- Переменная для строки, на которой будет происходить вывод
y = 5

gpu.setBackground(0x707070)
gpu.fill(1, 2, 30, 25, " ")
gpu.setBackground(0xFFFFFF)
gpu.fill(31, 2, 50, 25, " ")

-- Получаем список файлов и директорий
local files = fs.list("/")

--[[
gpu.setBackground(0x00FF00)
gpu.fill(1, 2, 80, 25, " ")
]]--
  
-- Выводим содержимое на экран
for i, name in ipairs(files) do
    gpu.set(14, y, name)  -- Выводим имя файла или директории
    y = y + 1            -- Переходим на следующую строку
end
