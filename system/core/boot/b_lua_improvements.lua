local npairs, nipairs = pairs, ipairs
local getmetatable = getmetatable

function _G.pairs(tbl)
    local mt = getmetatable(tbl)
    return (mt and mt.__pairs or npairs)(tbl)
end

function _G.ipairs(tbl)
    local mt = getmetatable(tbl)
    return (mt and mt.__ipairs or nipairs)(tbl)
end