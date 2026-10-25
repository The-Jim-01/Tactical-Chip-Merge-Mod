-- Detached display widget only: no actor spawning and no player chip setters.
local M={}
function M.calculate(board,inputs,raw,valid,get,log)
    local widget
    local snapshots={}
    local fields={'Boost','ConnectionType','RotationOffset','ChipTier','Price'}
    local function mark(s)if log then log('DIAG percentage: '..s)end end
    local ok,result=xpcall(function()
        local widgetClass=StaticFindObject('/Game/UI/Menu/Intranet/WeaponUpgrade/WB_PCBChip.WB_PCBChip_C')
        local factory=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
        assert(valid(widgetClass) and valid(factory),'Percentage widget classes unavailable')
        mark('create detached chip widget')
        widget=factory:Create(board,widgetClass,board:GetOwningPlayer())
        assert(valid(widget),'Cannot create detached percentage widget')
        local function display(input,boost)
            local chip=get(get(input.slot,'ChipWidget'),'Chip')
            assert(valid(chip),'Selected chip unavailable')
            local snapshot={chip=chip,values={}}
            for _,field in ipairs(fields)do snapshot.values[field]=get(chip,field)end
            snapshots[#snapshots+1]=snapshot
            mark('initialize detached widget with input '..input.id)
            -- Game blueprint resolves its own real inventory slot; no Lua struct conversion.
            widget:InitWithItem(chip)
            local initial=get(widget,'ChipStrength')
            assert(initial==input.display,('Detached Init mismatch: input %d, native %s'):format(input.display,tostring(initial)))
            mark('native initialization with proposed boost '..boost)
            -- Plain reflected field write: no item setter, event, save, or yield.
            -- Restore on every protected-call exit before reading/returning the result.
            local originalBoost=snapshot.values.Boost
            local computed,computeError=pcall(function()
                chip:SetPropertyValue('Boost',boost)
                widget:InitWithItem(chip)
            end)
            chip:SetPropertyValue('Boost',originalBoost)
            assert(get(chip,'Boost')==originalBoost,'Could not restore input boost')
            if not computed then error(computeError)end
            local value=get(widget,'ChipStrength')
            assert(type(value)=='number','Detached widget did not produce percentage')
            for _,field in ipairs(fields)do
                assert(get(chip,field)==snapshot.values[field],'Detached display changed selected chip '..field)
            end
            return value
        end
        local output
        for _,input in ipairs(inputs)do
            assert(display(input,input.boost)==input.display,'Bound SetChipStrength does not reproduce input percentage')
            local candidate=display(input,raw)
            if output==nil then output=candidate else
                assert(candidate==output,'Preview percentage depends on selected chip; cannot guarantee output')
            end
        end
        return output
    end,function(e)return debug.traceback(tostring(e),2)end)
    if valid(widget)then
        pcall(function()widget:ClearChip()end)
        pcall(function()widget:RemoveFromParent()end)
    end
    for _,snapshot in ipairs(snapshots)do
        for _,field in ipairs(fields)do
            assert(get(snapshot.chip,field)==snapshot.values[field],'Selected chip changed during display cleanup: '..field)
        end
    end
    if not ok then error(result)end
    mark('validated against all inputs; native preview validated; original boost restored; no actors spawned')
    return result
end
return M
