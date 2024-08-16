for i = 1, 16 do
    local bytes = {}
    local byte = math.random(0, 255)
    for i = 1, 8 do
        bytes[i] = math.random(0, 1) == 0
        byte = bit32.writebit(byte, i - 1, bytes[i])
    end
    
    for i, v in ipairs(bytes) do
        if bit32.readbit(byte, i - 1) ~= v then
            return false
        end
    end
end

return true