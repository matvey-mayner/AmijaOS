--bluetooth maded by HeroBrine1st
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local component = require("component")
local modem = component.modem
local bluetooth = {
	port = 61693,
	state = false,
	opened = false,
  	name = "AmijaOS",
	devices = {},	
}

local listener = function(...) 
	local signal = {...}
	if not signal[4] == bluetooth.port then return end 
	local reason = signal[6] 
	
	if reason == "PING" and bluetooth.opened then 
		modem.send(signal[3],bluetooth.port,"PONG",bluetooth.name)
	end
	if reason == "PONG" then
		computer.pushSignal("BLUETOOTH","PONG",signal[3],signal[7])
	end
end

function bluetooth.on()
	bluetooth.state = true
	modem.open(bluetooth.port)
	event.listen("modem_message",listener)
end

function bluetooth.off()
	bluetooth.state = false
	modem.close(bluetooth.port)
	event.ignore("modem_message",listener)
end

function bluetooth.open() bluetooth.opened = true end
function bluetooth.close() bluetooth.opened = false end

function bluetooth.sendFile(path,deviceAddress,dialogSending)
	dialogSending = dialogSending or function() end
	if not fs.exists(path) or fs.isDirectory(path) then return false end
	local name = fs.name(path)
	modem.send(deviceAddress,bluetooth.port,"SEND_REQUEST",name,bluetooth.name)
	local send = false
	local requestSuccess = false
	while not requestSuccess do
		local _,_,senderAddress,_,_,answer = event.pull("modem_message")
		if answer == "REQUEST_ALLOWED" and senderAddress == deviceAddress then requestSuccess = true send = true elseif answer == "REQUEST_DENIED" and senderAddress == deviceAddress then requestSuccess = true end  
	end
	if send then
		totalSize = 0
		local size = fs.size(path)
		modem.send(deviceAddress,bluetooth.port,"SEND_START",fs.size(path))
		local f = io.open(path,"r")
		repeat
			local data = f:read(128)
			if data then
				totalSize = totalSize + 128
				modem.send(deviceAddress,bluetooth.port,"FILE_CHUNK",data)
				dialogSending(size,totalSize)
				os.sleep(0.1)
			end
		until not data
		f:close()
		return true
	end
end

function bluetooth.receiveFile(dialogWait,dialogReceiving,dialogAnswer)
	dialogWait = dialogWait or function() end
	dialogReceiving = dialogReceiving or function() end
	dialogAnswer = dialogAnswer or function() return true end
	while true do
		local signal = {event.pull()}
		dialogWait()
		if signal[6] == "SEND_REQUEST" then
			local answer = dialogAnswer(signal[7],signal[8])
			modem.send(signal[3],bluetooth.port,answer and "REQUEST_ALLOWED" or "REQUEST_DENIED")
			if answer then
				while true do
					local _,_,address,_,_,status,size = event.pull("modem_message")
					if status == "SEND_START" and address == signal[3] then
						fs.remove("/bluetooth/" .. signal[7])
						fs.makeDirectory("/bluetooth/") 
						local f = io.open("/bluetooth/" .. signal[7],"w")
						local totalSize = 0
						while true do
							if totalSize == size then f:close() return true end
							local signal2 = {event.pull(10,"modem_message")}
							if #signal2 < 3 then return false end
							if signal2[3] == signal[3] and signal2[6] == "FILE_CHUNK" then
								f:write(signal2[7])
								totalSize = totalSize + #signal2[7]
								dialogReceiving(size,totalSize)
							end
						end
					end
				end
			end
		end
	end
end

function bluetooth.scan()
	if not bluetooth.state then bluetooth.on() end
	modem.broadcast(bluetooth.port,"PING")
	local devices = {}
	while true do
		local signal = {event.pull(1,"modem_message")}
		if #signal < 3 then break end
		if signal[6] == "PONG" then		
			table.insert(devices,{address=signal[3],name=signal[7]})
		end
	end
	bluetooth.devices = devices
	return devices
end

return bluetooth
