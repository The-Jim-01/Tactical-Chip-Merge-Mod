-- The game's chip widget supplies its artwork, text, materials and native layout.
local M={}
-- ESlateVisibility: 3 ignores this widget AND all children; 4 ignores self only.
-- Never change visibility/enabled state of the game's menu ancestors.
local Visibility={Visible=0,Collapsed=1,Hidden=2,HitTestInvisible=3,SelfHitTestInvisible=4}
local sides={[0]='Left',[1]='Up',[2]='Right',[3]='Down'}
-- Horizontal and vertical enums both reserve zero for Fill.
local HAlign={Fill=0,Left=1,Center=2,Right=3}
local VAlign={Fill=0,Top=1,Center=2,Bottom=3}
local align={[0]={HAlign.Left,VAlign.Center},[1]={HAlign.Center,VAlign.Top},
             [2]={HAlign.Right,VAlign.Center},[3]={HAlign.Center,VAlign.Bottom}}
local bright={R=.18,G=1,B=.42,A=1}
local dim={R=.025,G=.23,B=.075,A=1}
local locked={R=.008,G=.065,B=.02,A=.35}
function M.hit(x,y)
    if x<0 or y<0 or x>1 or y>1 then return nil end
    if x<=.24 and y>=.34 and y<=.66 then return 0 end
    if y<=.24 and x>=.34 and x<=.66 then return 1 end
    if x>=.76 and y>=.34 and y<=.66 then return 2 end
    if y>=.76 and x>=.34 and x<=.66 then return 3 end
end
function M.writeChipText(chip,percentage,valid,get)
    local value=percentage and tostring(percentage)..'%' or '--'
    -- Use the same UStaticText updater as the chip's Blueprint. Writing every
    -- concrete block bypasses native normal/shadow routing and overlays glyphs.
    -- UE4SS consumes text arguments: construct a fresh FText for each wrapper.
    for _,name in ipairs({'WB_StaticText_Value','WB_StaticText_ValueWithImage'})do
        local text=get(chip,name)
        if valid(text)then text:SetText(FText(value))end
    end
end
-- Initialize reflected font fields before the label gets a Slate widget.
-- UE4SS 3.0.1 cannot reliably marshal SetFont's SlateFontInfo parameter.
function M.makeLabel(make,source,valid,get,log)
    local label=make('TextBlock')
    local ok,err=pcall(function()
        local holder=get(source,'WB_StaticText_Value')
        assert(valid(holder),'Existing chip text unavailable')
        local block=holder:GetTextBlockNoWrap()
        local sourceFont=get(block,'Font')
        local targetFont=get(label,'Font')
        assert(sourceFont and targetFont and valid(sourceFont.FontObject),'Existing chip font unavailable')
        targetFont.FontObject=sourceFont.FontObject
        targetFont.Size=holder:GetFontSize()
        targetFont.TypefaceFontName=sourceFont.TypefaceFontName
        if valid(sourceFont.FontMaterial)then targetFont.FontMaterial=sourceFont.FontMaterial end
        log('Percentage label initialized before Slate attachment: '..sourceFont.FontObject:GetFullName()..'; size='..holder:GetFontSize())
    end)
    if not ok then log('Percentage label font initialization failed: '..tostring(err))end
    local colored,colorError=pcall(function()
        local color=get(label,'ColorAndOpacity')
        assert(color,'Percentage label color unavailable')
        color.ColorUseRule=0
        color.SpecifiedColor.R=0;color.SpecifiedColor.G=0;color.SpecifiedColor.B=0;color.SpecifiedColor.A=1
    end)
    if not colored then log('Percentage label color initialization failed: '..tostring(colorError))end
    label:SetJustification(1)
    label:SetVisibility(Visibility.HitTestInvisible)
    return label
end
function M:writeLabel(value)
    value=value or '--'
    if self.labelValue~=value and self.valid(self.label)then
        self.label:SetText(FText(value));self.labelValue=value
    end
    -- Hide native default-style text; artwork, materials and connectors remain.
    for _,name in ipairs({'WB_StaticText_Value','WB_StaticText_ValueWithImage'})do
        local text=self.get(self.chip,name)
        if self.valid(text)then text:SetVisibility(Visibility.Collapsed)end
    end
end
function M.new(slot,valid,get,log,inputs,initialChip)
    log=log or function()end
    local box=get(slot,'SizeBoxChip')
    assert(valid(box),'Native output chip size box unavailable')
    local function make(name)
        local cls=StaticFindObject('/Script/UMG.'..name)
        assert(valid(cls),'UMG class unavailable: '..name)
        return StaticConstructObject(cls,slot,0,0x40)
    end
    log('DIAG UI: create native chip widget')
    local factory=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    local cls=StaticFindObject('/Game/UI/Menu/Intranet/WeaponUpgrade/WB_PCBChip.WB_PCBChip_C')
    local chip=factory:Create(slot,cls,slot:GetOwningPlayer())
    assert(valid(chip),'Cannot create native silhouette widget')
    local input=initialChip or get(get(inputs[1].slot,'ChipWidget'),'Chip')
    assert(valid(input),'Input chip unavailable for native artwork')
    log('DIAG UI: native InitWithItem')
    chip:InitWithItem(input)
    log('DIAG UI: native artwork initialized')
    local root=make('Overlay')
    root:SetVisibility(Visibility.Collapsed)
    local art=root:AddChildToOverlay(chip)
    art:SetHorizontalAlignment(HAlign.Fill);art:SetVerticalAlignment(VAlign.Fill)
    chip:SetVisibility(Visibility.HitTestInvisible) -- Artwork never intercepts the side buttons.
    local ui={root=root,box=box,chip=chip,slot=slot,buttons={},images={},valid=valid,get=get,
              log=log,
              node=get(slot,'NodeObject'),visible=false,originalContent=box:GetContent(),
              originalBoxVisibility=box:GetVisibility()}
    ui.label=M.makeLabel(make,get(inputs[1].slot,'ChipWidget'),valid,get,log)
    -- Keep the native font size; Slate scales down only when the range needs it.
    -- Confine the label to the chip body, leaving the connector areas free.
    local textBody=make('SizeBox')
    textBody:SetWidthOverride(64);textBody:SetHeightOverride(32)
    textBody:SetVisibility(Visibility.HitTestInvisible)
    local fit=make('ScaleBox')
    fit:SetStretch(2) -- EStretch.ScaleToFit
    fit:SetStretchDirection(1) -- EStretchDirection.DownOnly
    fit:SetVisibility(Visibility.HitTestInvisible)
    fit:SetContent(ui.label);textBody:SetContent(fit)
    local textPlacement=root:AddChildToOverlay(textBody)
    textPlacement:SetHorizontalAlignment(HAlign.Center);textPlacement:SetVerticalAlignment(VAlign.Center)
    for side=0,3 do
        ui.images[side]=get(chip,sides[side])
        assert(valid(ui.images[side]),'Native chip side image missing: '..sides[side])
        local target=make('SizeBox')
        target:SetWidthOverride(side%2==0 and 20 or 28)
        target:SetHeightOverride(side%2==0 and 28 or 20)
        local button=make('Button')
        button:SetBackgroundColor({R=0,G=0,B=0,A=0})
        -- MouseDown click mode does not capture the cursor. Keep keyboard focus
        -- with the game, and observe IsPressed on the game thread.
        button:SetClickMethod(1)
        button:SetPropertyValue('IsFocusable',false)
        button:SetVisibility(Visibility.Visible)
        target:SetVisibility(Visibility.SelfHitTestInvisible)
        target:SetContent(button)
        local placement=root:AddChildToOverlay(target)
        placement:SetHorizontalAlignment(align[side][1]);placement:SetVerticalAlignment(align[side][2])
        ui.buttons[side]=button
    end
    log('Side target alignment: Left=(1,2), Top=(2,1), Right=(3,2), Bottom=(2,3); artwork fills preview')
    log('Side targets ready: preview visibility=4 (self only), artwork=3 (all children); no ancestor overrides')
    return setmetatable(ui,{__index=M})
end
function M:show(percentage,selected,available,ready)
    if not self.visible then
        if self.valid(self.node)then self.nodeVisibility=self.node:GetVisibility();self.node:SetVisibility(Visibility.Hidden)end
        self.box:SetContent(self.root)
        self.box:SetVisibility(Visibility.Visible)
    end
    self.visible=true;self.root:SetVisibility(Visibility.SelfHitTestInvisible)
    -- Native refresh writes the percentage using the game's existing font and text widgets.
    for side=0,3 do
        local allowed=available & (1<<side)~=0
        local on=selected & (1<<side)~=0
        self.buttons[side]:SetIsEnabled(ready and allowed)
        self.images[side]:SetVisibility(Visibility.HitTestInvisible)
        self.images[side]:SetColorAndOpacity(not allowed and locked or (on and bright or dim))
    end
    self:writeLabel(type(percentage)=='number' and (tostring(percentage)..'%') or percentage)
end
function M:showResult(chip,percentage,selected)
    self.chip:InitWithItem(chip)
    for side=0,3 do
        local on=selected & (1<<side)~=0
        self.buttons[side]:SetVisibility(Visibility.Collapsed)
        self.buttons[side]:SetIsEnabled(false)
        self.images[side]:SetVisibility(on and Visibility.HitTestInvisible or Visibility.Hidden)
        self.images[side]:SetColorAndOpacity(bright)
    end
    self.box:SetContent(self.root);self.box:SetVisibility(Visibility.Visible)
    self.root:SetVisibility(Visibility.HitTestInvisible)
    self.visible=true
    self:writeLabel(type(percentage)=='number' and (tostring(percentage)..'%') or percentage)
end
-- Native menu refreshes can replace SizeBox content or reveal the default
-- text without changing the result actor or its ChipStrength/shape fields.
-- Audit presentation only; never call InitWithItem or rewrite unchanged text.
function M:ensureResultPresentation(slot)
    local box=self.get(slot,'SizeBoxChip')
    assert(self.valid(box) and self.valid(self.root) and self.valid(self.label),'Result presentation objects unavailable')
    local changed=false
    if not self.valid(self.box) or self.box:GetFullName()~=box:GetFullName()then
        self.slot=slot;self.box=box
        self.originalContent=box:GetContent();self.originalBoxVisibility=box:GetVisibility()
        changed=true
    end
    local content=box:GetContent()
    if not self.valid(content) or content:GetFullName()~=self.root:GetFullName()then box:SetContent(self.root);changed=true end
    if box:GetVisibility()~=Visibility.Visible then box:SetVisibility(Visibility.Visible);changed=true end
    if self.root:GetVisibility()~=Visibility.HitTestInvisible then self.root:SetVisibility(Visibility.HitTestInvisible);changed=true end
    if self.label:GetVisibility()~=Visibility.HitTestInvisible then self.label:SetVisibility(Visibility.HitTestInvisible);changed=true end
    for _,name in ipairs({'WB_StaticText_Value','WB_StaticText_ValueWithImage'})do
        local text=self.get(self.chip,name)
        if self.valid(text) and text:GetVisibility()~=Visibility.Collapsed then text:SetVisibility(Visibility.Collapsed);changed=true end
    end
    self.visible=true
    return changed
end
function M:hide(resultReady)
    if self.valid(self.root)then self.root:SetVisibility(Visibility.Collapsed)end
    if self.visible and self.valid(self.box) then
        local content=resultReady and self.get(self.slot,'ChipWidget') or self.originalContent
        if self.valid(content)then self.box:SetContent(content)end
        self.box:SetVisibility(resultReady and Visibility.Visible or self.originalBoxVisibility)
        if self.valid(self.node) and self.nodeVisibility~=nil then self.node:SetVisibility(resultReady and Visibility.Hidden or self.nodeVisibility)end
    end
    self.visible=false
end
function M:pressedSide()
    if not self.visible or not self.valid(self.root)then return nil end
    for side=0,3 do if self.valid(self.buttons[side]) and self.buttons[side]:IsPressed()then return side end end
end
function M:dispose(resultReady)
    self:hide(resultReady)
    if self.valid(self.chip)then self.chip:RemoveFromParent()end
    if self.valid(self.root)then self.root:RemoveFromParent()end
end
return M

