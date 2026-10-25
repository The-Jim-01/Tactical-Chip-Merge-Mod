-- Game-verified enum order: Left, Top, Right, Down. Lua 5.4.
local M = {}
local bases = {[0]=15,[1]=13,[2]=9,[3]=5,[4]=1}
function M.rotate(mask, rotation)
    rotation = rotation % 4
    local out = 0
    for side = 0, 3 do
        if mask & (1 << side) ~= 0 then out = out | (1 << ((side + rotation) % 4)) end
    end
    return out
end
function M.mask(kind, rotation)
    assert(bases[kind], 'Unknown chip connection type')
    return M.rotate(bases[kind], rotation)
end
function M.configuration(mask)
    assert(mask > 0 and mask <= 15, 'A chip must have at least one side')
    for kind=0,4 do
        for rotation=0,3 do
            if M.mask(kind,rotation)==mask then return kind,rotation end
        end
    end
    error('Unsupported connection mask')
end
function M.union(inputs)
    local out=0
    for _, input in ipairs(inputs) do out=out | M.mask(input.kind,input.rotation) end
    return out
end
function M.toggle(selected, available, side)
    local bit=1 << side
    if available & bit == 0 then return selected,false,'Side unavailable' end
    local nextMask=selected ~ bit
    if nextMask==0 then return selected,false,'Keep at least one side' end
    return nextMask,true
end
function M.roll(inputs, maximum, storyUpper, random)
    assert(#inputs==3)
    local sum=0
    for _, input in ipairs(inputs) do sum=sum+input.boost end
    local base=sum//3
    -- Original Blueprint makes a fresh second draw if the cap check fails.
    local average
    if base+random(2,5)>=maximum then average=maximum
    else average=base+random(2,5) end
    -- Unreal RandRange returns Min for a non-positive range width.
    if storyUpper<average then return average,average end
    return random(average,storyUpper),average
end
-- Enumerate the Blueprint's independent cap-check and bonus draws without RNG.
function M.possible(inputs,maximum,storyUpper)
    assert(#inputs==3)
    local sum=0
    for _,input in ipairs(inputs)do sum=sum+input.boost end
    local base=sum//3
    local values={}
    for check=2,5 do
        for bonus=2,5 do
            local average=base+check>=maximum and maximum or base+bonus
            for raw=average,math.max(average,storyUpper)do values[raw]=true end
        end
    end
    local low,high
    for raw in pairs(values)do
        low=low and math.min(low,raw) or raw
        high=high and math.max(high,raw) or raw
    end
    return low,high,values
end
function M.signature(inputs, maximum, storyUpper)
    local parts={tostring(maximum),tostring(storyUpper)}
    for _,v in ipairs(inputs) do
        parts[#parts+1]=table.concat({v.id,v.boost,v.kind,v.rotation,v.display,v.tier or 0}, ':')
    end
    return table.concat(parts,'|')
end
return M
