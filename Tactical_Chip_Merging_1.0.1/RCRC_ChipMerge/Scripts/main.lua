-- Tactical Chip Merging 1.0.1 -- GOG 1.0.2.1. Native preview and isolated side buttons.
local source=debug.getinfo(1,'S').source:gsub('^@','')
local directory=source:match('^(.*[/\\])') or './'
local core=dofile(directory..'core.lua')
local UI=dofile(directory..'ui.lua')
local Percentage=dofile(directory..'percentage.lua')
local states, hooks = {}, {}
local pending=false
local boardPath='/Game/UI/Menu/Intranet/WeaponUpgrade/Boards/WB_PCBBoard_ChipMerging.WB_PCBBoard_ChipMerging_C'
local slotNames={'WB_PCBBoardSlot_Slot1','WB_PCBBoardSlot_Slot2','WB_PCBBoardSlot_Slot3'}
local sequence=0
local function log(message)
    print('[Tactical Chip Merging] '..message..'\n')
    local f=io.open(directory..'RCRC_ChipMerge.log','a')
    if f then f:write(os.date('%Y-%m-%d %H:%M:%S')..' '..message..'\n');f:close() end
end
local function safe(fn) local ok,value=pcall(fn);if ok then return value end end
local function valid(o) return o~=nil and safe(function()return o:IsValid()end)==true end
local function get(o,k) if valid(o) then return safe(function()return o:GetPropertyValue(k)end) end end
local function unwrap(p) return p and p:get() end
local function id(o) return o:GetFullName() end
local function same(a,b) return valid(a) and valid(b) and id(a)==id(b) end
local function isLiveBoard(o)
    if not valid(o) then return false end
    local name=id(o)
    return name:find('/Engine/Transient.',1,true)~=nil and not name:find('Default__',1,true)
end
local function stateFor(board)
    local key=id(board)
    if not states[key] then states[key]={board=board,phase='idle',selected=0} end
    return states[key]
end
local function shown(board)
    -- Check panel parents as well as the enclosing UserWidget/WidgetTree chain.
    local o=board
    for _=1,32 do
        if not valid(o) then break end
        local visible=safe(function()return o:IsVisible()end)
        if visible==false then return false end
        local parent=safe(function()return o:GetParent()end)
        if valid(parent) then o=parent else o=safe(function()return o:GetOuter()end) end
    end
    return true
end
local function inputsOf(board)
    local inputs={}
    for _,name in ipairs(slotNames) do
        local slot=get(board,name)
        local widget=get(slot,'ChipWidget')
        local chip=get(widget,'Chip')
        if not valid(chip) then return nil end
        local boost,kind,rotation,display,tier=get(chip,'Boost'),get(widget,'ChipType'),get(widget,'Rotation'),get(widget,'ChipStrength'),get(chip,'ChipTier')
        if type(boost)~='number' or type(kind)~='number' or type(rotation)~='number' or type(display)~='number' or type(tier)~='number' then return nil end
        inputs[#inputs+1]={id=id(chip),boost=boost,kind=kind,rotation=rotation,display=display,tier=tier,slot=slot}
    end
    return inputs
end
local function libraries()
    local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
    local gameplay=StaticFindObject('/Script/Game.Default__GameplayScriptingFunctionLibrary')
    assert(valid(mathlib) and valid(gameplay),'Native libraries unavailable')
    return mathlib,gameplay
end
local function storyCap(board,gameplay)
    local prefix='/Game/Quests/'
    for _,v in ipairs({{'L19_PoliceStation_Quests/OB_L19_MQ_PoliceStation.OB_L19_MQ_PoliceStation_C',25},
                      {'L10_PoliceStation_Quests/OB_L10_MQ_PoliceStation.OB_L10_MQ_PoliceStation_C',20}}) do
        local objective=StaticFindObject(prefix..v[1])
        assert(valid(objective),'Objective class unavailable: '..v[1])
        if gameplay:GetObjectiveState(objective,board)==2 then return v[2] end
    end
    return 15
end
local function restore(s,committed)
    if s.ui then s.ui:hide() end
end
local function discardPreview(s)
    if s.ui then s.ui:dispose(valid(get(get(get(s.board,'WB_PCBBoardSlot_Result'),'ChipWidget'),'Chip')));s.ui=nil end
    s.ready=false;s.signature=nil;s.percentage=nil;s.raw=nil;s.average=nil
    s.rawLow=nil;s.rawHigh=nil;s.displayLow=nil;s.displayHigh=nil;s.possible=nil
    s.selected=0;s.available=0;s.inputs=nil;s.painted=false
    s.failedSignature=nil;s.failedSetup=nil;s.attemptedSignature=nil
end
local function paint(s)
    local slot=get(s.board,'WB_PCBBoardSlot_Result')
    if not s.ui or not valid(s.ui.root) then s.ui=UI.new(slot,valid,get,log,s.inputs) end
    s.ui:show(s.percentage,s.selected,s.available,s.ready)
    s.painted=true
    return true
end
-- Refresh the actual, visible result AFTER its Slate children have been built.
-- A separately styled label shows the range before Merge and actual result after.
local function refreshResultDisplay(s,f,widget)
    if f.ui then
        f.ui:showResult(f.chip or get(widget,'Chip'),f.percentage,f.selected)
    else UI.writeChipText(widget,f.percentage,valid,get)end
end

local function watchResult(s)
    local f=s.result
    if not f then return end
    local slot=get(s.board,'WB_PCBBoardSlot_Result')
    local widget=get(slot,'ChipWidget');local chip=get(widget,'Chip')
    if not same(chip,f.chip) then
        log(('Result #%d left merge slot; final base=%s'):format(f.number,tostring(get(f.chip,'Boost'))))
        if f.ui then f.ui:dispose(false);f.ui=nil end
        s.result=nil;return
    end
    local kind,rotation=core.configuration(f.selected)
    local actorMismatch=get(chip,'Boost')~=f.raw or get(chip,'ConnectionType')~=kind or get(chip,'RotationOffset')~=rotation
    local uiMismatch=get(widget,'ChipStrength')~=f.percentage or get(widget,'ChipType')~=kind or get(widget,'Rotation')~=rotation
    if actorMismatch then
        chip:SpecifyChipData(kind,f.raw,rotation,get(chip,'ChipTier'));chip:SetChipBoost(f.raw)
        log('Corrected a later native overwrite of result #'..f.number)
    end
    if actorMismatch or uiMismatch then widget:InitWithItem(chip)end
    if f.deferred or actorMismatch or uiMismatch then
        refreshResultDisplay(s,f,widget)
        assert(get(chip,'Boost')==f.raw and get(widget,'ChipStrength')==f.percentage,'Deferred result percentage mismatch')
        assert(core.mask(get(widget,'ChipType'),get(widget,'Rotation'))==f.selected,'Deferred result shape mismatch')
        log(('Visible result #%d: %d%%, base=%d, sides=%d; native preview reused as result; pre-styled percentage label'):format(f.number,f.percentage,f.raw,f.selected))
        f.deferred=false
    end
    if f.ui and (not valid(f.ui.root) or not valid(f.ui.label) or not valid(f.ui.chip))then
        f.ui:dispose(false)
        f.ui=UI.new(slot,valid,get,log,f.inputs,chip)
        refreshResultDisplay(s,f,widget)
        log('Rebuilt detached result presentation #'..f.number)
    end
    if f.ui and f.ui:ensureResultPresentation(slot)then
        log('Restored result presentation #'..f.number..' after native menu refresh; chip values unchanged')
    end
end
-- Native merge calls bypassed the old delete/create hooks in the supplied report.
-- Observe the completed output while the last full-input preview is still cached.
local function tryCommitResult(board,reason)
    if not isLiveBoard(board) then return false end
    local s=states[id(board)]
    if not s or not s.ready or not s.inputs then return false end
    local slot=get(board,'WB_PCBBoardSlot_Result')
    local widget=get(slot,'ChipWidget');local chip=get(widget,'Chip')
    if not valid(chip) then return false end
    for _,name in ipairs(slotNames)do
        if valid(get(get(get(board,name),'ChipWidget'),'Chip')) then return false end
    end
    local chipId=id(chip)
    for _,input in ipairs(s.inputs)do if input.id==chipId then return false end end
    if s.commitAttempted==chipId then return false end
    s.commitAttempted=chipId
    local f={selected=s.selected,available=s.available,number=s.number,inputs=s.inputs}
    local original={boost=get(chip,'Boost'),kind=get(chip,'ConnectionType'),rotation=get(chip,'RotationOffset'),tier=get(chip,'ChipTier')}
    local ok,err=xpcall(function()
        assert(f.selected>0 and (f.selected & f.available)==f.selected,'Invalid cached output shape')
        assert(type(original.boost)=='number' and type(original.kind)=='number' and type(original.rotation)=='number' and type(original.tier)=='number','Native result fields unavailable')
        assert(s.possible[original.boost],'Native result outside possible raw values')
        f.raw=original.boost -- Preserve the game roll made by pressing Merge.
        local kind,rotation=core.configuration(f.selected)
        -- Restore the actual result's native widget rather than the input silhouette.
        -- Retain the already constructed native preview for the pending result.
        chip:SpecifyChipData(kind,f.raw,rotation,original.tier)
        chip:SetChipBoost(f.raw)
        assert(get(chip,'Boost')==f.raw,'Result did not retain native boost')
        assert(core.mask(get(chip,'ConnectionType'),get(chip,'RotationOffset'))==f.selected,'Result shape differs from selection')
        -- Blueprint InitWithItem locates the real inventory slot and runs native
        -- artwork/percentage/font initialization. Never marshal Font structs in Lua.
        widget:InitWithItem(chip)
        widget:ContinuationAfterInit()
        local actual=get(widget,'ChipStrength')
        local mask=core.mask(get(widget,'ChipType'),get(widget,'Rotation'))
        assert(type(actual)=='number' and actual>=s.displayLow and actual<=s.displayHigh,'Native result outside preview range')
        f.percentage=actual
        assert(mask==f.selected,'Displayed result connectors differ from selection')
        f.chip=chip;f.ui=s.ui
        refreshResultDisplay(s,f,widget)
        s.ui=nil;f.deferred=true;s.result=f
        log(('Committed range preview #%d via %s: range=%s actual=%d%%, native base=%d, selected=%d result=%d, MATCH'):format(f.number,reason,s.percentage,actual,f.raw,f.selected,mask))
    end,function(e)return debug.traceback(tostring(e),2)end)
    if not ok then
        local rolledBack,rollbackError=pcall(function()
            chip:SpecifyChipData(original.kind,original.boost,original.rotation,original.tier)
            chip:SetChipBoost(original.boost)
            widget:InitWithItem(chip);widget:ContinuationAfterInit()
        end)
        log('MERGE ERROR: '..tostring(err)..'; original result restored='..tostring(rolledBack)..(rolledBack and '' or '; '..tostring(rollbackError)))
    end
    discardPreview(s)
    return ok
end
local function refresh(board)
    if not isLiveBoard(board) then return end
    local s=stateFor(board)
    if not shown(board)then
        if s.ui and s.painted then s.ui:hide();s.painted=false end
        return
    end
    if tryCommitResult(board,'result refresh') then return end
    local inputs=inputsOf(board)
    local output=get(get(board,'WB_PCBBoardSlot_Result'),'ChipWidget')
    if not inputs or not valid(output) or valid(get(output,'Chip')) then
        discardPreview(s)
        return
    end
    local setupKey=core.signature(inputs,get(board,'CurrentMaxRange') or 0,0)
    if s.failedSetup==setupKey then return end
    s.setupKey=setupKey
    if not s.diagnosticStarted then
        s.diagnosticStarted=true
        log('DIAG: three input chips recognized; preparing preview')
    end
    local mathlib,gameplay=libraries()
    if not s.capChecked then log('DIAG: story objective lookup begins') end
    local upper=storyCap(board,gameplay)
    if not s.capChecked then log('DIAG: story objective lookup complete, cap='..tostring(upper));s.capChecked=true end
    local maximum=get(board,'CurrentMaxRange')
    assert(type(maximum)=='number','CurrentMaxRange unavailable')
    local signature=core.signature(inputs,maximum,upper)
    if signature~=s.signature then
        if s.failedSignature==signature then return end
        discardPreview(s)
        log('Cleared previous preview; rebuilding for current inputs')
        local available=core.union(inputs)
        local selected=available
        s.available=available;s.selected=selected;s.inputs=inputs
        s.percentage=nil;s.ready=false;s.attemptedSignature=signature
        log('DIAG: UI creation begins')
        paint(s) -- Visible silhouette with -- while native validation is pending.
        local low,high,possible=core.possible(inputs,maximum,upper)
        local displayLow=Percentage.calculate(board,inputs,low,valid,get,log)
        local displayHigh=low==high and displayLow or Percentage.calculate(board,inputs,high,valid,get,log)
        assert(displayLow<=displayHigh,'Native display endpoints reversed')
        s.rawLow=low;s.rawHigh=high;s.possible=possible
        s.displayLow=displayLow;s.displayHigh=displayHigh
        s.percentage=('%d%% - %d%%'):format(displayLow,displayHigh)
        s.signature=signature;s.ready=true;s.painted=false;s.failedSignature=nil;s.attemptedSignature=nil
        sequence=sequence+1;s.number=sequence
        log(('Range preview #%d: %s (base %d-%d), allowed mask=%d; no random draws'):format(s.number,s.percentage,low,high,available))
    end
    if s.ready and (not s.painted or not s.ui or not valid(s.ui.root))then paint(s)end
end
local function guardedRefresh(board)
    local ok,err=xpcall(function()refresh(board)end,function(e)return debug.traceback(tostring(e),2)end)
    if not ok and valid(board) then
        local s=stateFor(board)
        s.ready=false;s.failedSetup=s.setupKey
        if s.attemptedSignature then
            s.failedSignature=s.attemptedSignature
            s.percentage=nil
            -- Do not repeat a failed construction and leave duplicate children.
            -- Keep the disabled silhouette with -- visible if percentage validation fails.
            -- It was already painted with ready=false before calculation.
        else safe(function()restore(s,false)end) end
        local message=tostring(err)
        if s.lastError~=message then s.lastError=message;log('Preview disabled: '..message) end
    end
end
local heldMouseButton=nil
local function pollButtons()
    -- A frame observer also covers a merge path that bypasses Blueprint hooks.
    for _,s in pairs(states)do
        if (s.ready or s.result) and isLiveBoard(s.board) and shown(s.board)then
            watchResult(s)
            tryCommitResult(s.board,'frame result observer')
        end
    end
    local active={}
    for _,s in pairs(states)do
        if valid(s.board) and s.phase=='idle' and s.ready and s.ui and s.ui.visible and shown(s.board)then
            local side=s.ui:pressedSide()
            if side~=nil then active[#active+1]={state=s,side=side}end
        end
    end
    if #active~=1 then heldMouseButton=nil;return end
    local s,side=active[1].state,active[1].side
    local press=id(s.ui.buttons[side])
    if heldMouseButton==press then return end
    heldMouseButton=press
    guardedRefresh(s.board)
    if not s.ready then return end
    local mask,changed,reason=core.toggle(s.selected,s.available,side)
    if not changed then log(reason);return end
    s.selected=mask
    paint(s)
    log(('Side %d toggled; selected mask=%d; range retained=%s'):format(side,mask,s.percentage))
end
local function installHooks()
    local function hook(name,pre,post)
        if hooks[name] then return end
        if not valid(StaticFindObject(name)) then return end
        local ok,a,b
        if post then ok,a,b=pcall(RegisterHook,name,pre,post)
        else ok,a,b=pcall(RegisterHook,name,pre) end
        if ok then hooks[name]={a,b};log('Hook ready: '..name) else log('Hook registration failed: '..name..' '..tostring(a)) end
    end
    -- UE4SS 3.0.1 dispatches Blueprint RegisterHook callbacks AFTER the
    -- script returns; this therefore sees the completed native merge result.
    hook(boardPath..':MergeChips',function(ctx)
        local board=unwrap(ctx)
        local ok,err=pcall(function()tryCommitResult(board,'MergeChips post')end)
        if not ok then log('Merge completion error: '..tostring(err))end
    end)
end
-- Mouse input only. No keyboard/menu shortcuts are registered.
local mousePollPending=false
LoopAsync(16,function()
    if mousePollPending then return end
    mousePollPending=true
    ExecuteInGameThread(function()
        local ok,err=pcall(pollButtons)
        if not ok then log('Mouse UI error: '..tostring(err))end
        mousePollPending=false
    end)
end)
LoopAsync(250,function()
    if pending then return false end
    pending=true
    ExecuteInGameThread(function()
        local ok,err=pcall(function()
            installHooks()
            local live={}
            for _,board in ipairs(FindAllOf('WB_PCBBoard_ChipMerging_C') or {})do
                if isLiveBoard(board)then live[id(board)]=true;guardedRefresh(board)end
            end
            -- Drop stale references without calling into destroyed menu objects.
            for key in pairs(states)do if not live[key]then states[key]=nil end end
        end)
        if not ok then log('Observer error: '..tostring(err)) end
        pending=false
    end)
    return false
end)
log('Tactical Chip Merging 1.0.1 loaded. Automatic possible-result range; click preview sides. Visible result binding, deferred display refresh and percentage verification; no ancestor overrides, mouse capture or keyboard shortcuts.')
