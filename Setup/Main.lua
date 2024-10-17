local component = require("component")
local gpu = component.gpu
local fs = require("filesystem")
local comp = require("computer")
local event = require("event")
local os = require("os")

os.execute("wget -f https://raw.githubusercontent.com/matvey-mayner/MaynerAPI/main/MAYNERAPI.lua /lib/MAYNERAPI.lua")
os.execute("wget -f https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/BIOS.lua /tmp/b.lua")

local mayner = require("MAYNERAPI")

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
    gpu.set(25, 14, "But Орешки тупитупи cant delete") -- Ну Это Правда!; СУПЧИК НАСРАЛ НЕ ТАК - gamma63
    gpu.set(25, 15, "System!")

mayner.DrawButton(69, 23, 6, 1, "Accept", 0xFFFFFF, 0x4b4b4b, function()
  if buttons1 == "Show" then
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)

    gpu.fill(12, 23, 6, 1, " ")
    gpu.fill(69, 23, 6, 1, " ")
    gpu.fill(25, 6, 37, 15, " ")
      
    buttons1 = "Hide"

    fs.remove("/")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/bootloader.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/LICENSE")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/logo.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/recovery.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/autoruns/a_component.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/boot/a_functions.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/boot/b_lua_improvements.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/bit32.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/cache.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/clipboard.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/colors.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/event.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/filesystem.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/graphic.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/hook.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/internet.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/lastinfo.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/logs.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/natives.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/note.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/package.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/parser.lua")
    os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/paths.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/programs.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/registry.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/serialization.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/sha256.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/sides.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/syntax.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/system.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/term.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/text.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/thread.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/time.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/utils.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/uuid.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/vcomponent.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/vgpu.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/archiver/init.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/archiver/formats/afpx.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/lib/archiver/formats/tar.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/luaenv/a_base.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/luaenv/b_os.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/unittests/a_readbit.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/unittests/b_writebit.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/unittests/c_split.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/unittests/d_toParts.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/system/core/unittests/e_sha256.lua")
os.execute("wget https://raw.githubusercontent.com/matvey-mayner/OpenKernel/main/Kernel.lua")
    os.execute("wget -f https://raw.githubusercontent.com/matvey-mayner/MaynerAPI/main/MAYNERAPI.lua /system/core/lib/MAYNERAPI.lua")
    os.execute("flash -q /tmp/b.lua")
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
