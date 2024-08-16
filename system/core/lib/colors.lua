---- base
local colors = {
    [0] = "white",
    [1] = "orange",
    [2] = "magenta",
    [3] = "lightBlue",
    [4] = "yellow",
    [5] = "lime",
    [6] = "pink",
    [7] = "gray",
    [8] = "lightGray",
    [9] = "cyan",
    [10] = "purple",
    [11] = "blue",
    [12] = "brown",
    [13] = "green",
    [14] = "red",
    [15] = "black"
}

---- reverse
do
    local keys = {}
    for k in pairs(colors) do
        table.insert(keys, k)
    end
    for _, k in pairs(keys) do
        colors[colors[k]] = k
    end
end

---- links
colors.silver = colors.lightGray
colors.lightGreen = colors.lime
colors.lightblue = colors.lightBlue
colors.lightgray = colors.lightGray
colors.lightgreen = colors.lightGreen

---- functions
function colors.hsvToRgb(h, s, v)
    h = h / 255
    s = s / 255
    v = v / 255

    local r, g, b

    local i = math.floor(h * 6);

    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);

    i = math.floor(i % 6)

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)

    return r, g, b
end

function colors.blend(r, g, b)
    r = math.floor(r)
    g = math.floor(g)
    b = math.floor(b)
    return math.floor(b + (g * 256) + (r * 256 * 256))
end

function colors.unBlend(color)
    color =  math.floor(color)
    local blue = color % 256
    local green = (color // 256) % 256
    local red = (color // (256 * 256)) % 256
    return math.floor(red), math.floor(green), math.floor(blue)
end

function colors.colorMul(color, mul)
    local r, g, b = colors.unBlend(color)
    return colors.blend(
        math.clampRound(r * mul, 0, 255),
        math.clampRound(g * mul, 0, 255),
        math.clampRound(b * mul, 0, 255)
    )
end

colors.unloadable = true
return colors