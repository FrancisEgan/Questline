local Q, DB = Questline, QuestlineDB
local getn = table.getn
local path = "Interface\\AddOns\\Questline\\Textures\\"
function Q:StyleTextLink(button)
  local enter,leave,hide=button:GetScript("OnEnter"),button:GetScript("OnLeave"),button:GetScript("OnHide")
  local function paint(widget,hovered)
    if hovered then
      widget.text:SetTextColor(.85,.95,1)
      widget.text:SetShadowColor(.25,.6,1,.65);widget.text:SetShadowOffset(1,-1)
    else
      widget.text:SetTextColor(.55,.8,1)
      widget.text:SetShadowColor(0,0,0,0);widget.text:SetShadowOffset(0,0)
    end
  end
  paint(button,false)
  button:SetScript("OnEnter",function() paint(this,true);if enter then enter() end end)
  button:SetScript("OnLeave",function() paint(this,false);if leave then leave() end end)
  button:SetScript("OnHide",function() paint(this,false);if hide then hide() end end)
end
local function font(parent, size, red, green, blue)
  local text = parent:CreateFontString(nil, "OVERLAY")
  text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
  text:SetTextColor(red or 0.9, green or 0.88, blue or 0.8)
  text:SetJustifyH("LEFT"); text:SetJustifyV("TOP")
  return text
end
function Q:MakeBadge(parent, size)
  local badge=CreateFrame("Button",nil,parent)
  badge:SetWidth(size);badge:SetHeight(size)
  badge.glow=badge:CreateTexture(nil,"BACKGROUND");badge.glow:SetTexture(path.."circle-glow-v2")
  badge.glow:SetPoint("CENTER",badge,"CENTER",0,0);badge.glow:Hide()
  badge.texture=badge:CreateTexture(nil,"ARTWORK");badge.texture:SetAllPoints(badge)
  badge.text=font(badge,12,1,0.85,0.4);badge.text:SetJustifyH("CENTER");badge.text:SetJustifyV("MIDDLE")
  self:SizeBadge(badge,size,1)
  return badge
end
function Q:SizeBadge(badge,size,scale)
  badge.textScale=scale
  badge:SetWidth(size*scale);badge:SetHeight(size*scale)
  badge.glow:SetWidth((size+14)*scale);badge.glow:SetHeight((size+14)*scale)
  badge.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12*scale,"")
  badge.text:ClearAllPoints()
  -- Optical correction for the numeral bearings in the client's serif font.
  badge.text:SetPoint("CENTER",badge,"CENTER",-0.7*scale,0)
  badge.text:SetWidth(size*scale);badge.text:SetHeight(size*scale)
  badge.text:SetShadowColor(0,0,0,0.9);badge.text:SetShadowOffset(0,-0.6*scale)
end
function Q:PaintBadge(badge, entry, selected)
  badge.texture:SetTexture(path .. (selected and "circle-selected-v2" or "circle-v2"))
  local label=entry.complete and "?" or tostring(entry.number)
  badge.text:SetText(label)
  badge.text:ClearAllPoints()
  -- The narrow standalone 1 needs a little more optical correction.
  badge.text:SetPoint("CENTER",badge,"CENTER",(label=="1" and -1.3 or -0.7)*(badge.textScale or 1),0)
  if selected then
    badge.glow:Show();badge.text:SetTextColor(0.19,0.11,0.025)
    badge.text:SetShadowColor(1,0.93,0.62,0.4)
  else
    badge.glow:Hide();badge.text:SetTextColor(1,0.86,0.52)
    badge.text:SetShadowColor(0,0,0,0.9)
  end
end
function Q:ShowQuestTooltip(owner, entry, target)
  local tip = WorldMapFrame:IsVisible() and WorldMapTooltip or GameTooltip
  tip:SetOwner(owner,"ANCHOR_LEFT")
  tip:SetText(self:QuestTitle(entry),1,0.85,0.4)
  if target then tip:AddLine(target.name,0.7,0.85,1) end
  if entry.complete then tip:AddLine("Ready for turn-in",1,0.9,0.4)
  elseif entry.failed then tip:AddLine("Quest failed",1,0.3,0.3)
  else for index,objective in ipairs(entry.objectives) do
    local lines=self:PartyObjectiveLines(entry,index,objective.text,objective.done,"")
    for _,line in ipairs(lines) do
      if line.done then tip:AddLine(line.text,0.35,1,0.4,true)
      else tip:AddLine(line.text,0.88,0.88,0.82,true) end
    end
  end end
  if entry.complete or entry.failed or getn(entry.objectives)==0 then
    local lines=self:PartyStatusLines(entry,"  ")
    if getn(lines)>0 then tip:AddLine("Party",.8,.85,.9) end
    for _,line in ipairs(lines) do tip:AddLine(line.text,line.done and .4 or .88,line.done and .9 or .88,line.done and .45 or .82,true) end
  end
  if not entry.id then tip:AddLine(entry.reason=="ambiguous" and "Multiple database matches; map location unresolved." or "Quest not found in the English database.",1,0.55,0.3,true) end
  if entry.id and not entry.failed and not self:HasLocations(entry) then tip:AddLine("No remaining mapped locations for this quest.",1,0.55,0.3,true) end
  tip:Show()
  self.partyQuestTooltip={owner=owner,key=entry.key,target=target,tip=tip}
end
local function hideTooltip() GameTooltip:Hide();WorldMapTooltip:Hide() end
local function sizeKey(panel) return panel.isMap and "mapSize" or "trackerSize" end
local function saveSize(panel)
  QuestlineSettings[sizeKey(panel)]={width=panel:GetWidth(),height=panel:GetHeight()}
end
local function finishResize(panel,hidden)
  if not panel.resizing then return end
  panel.resizing=nil;panel:StopMovingOrSizing();saveSize(panel)
  local position={x=panel:GetLeft(),y=panel:GetTop()}
  if panel.isMap then QuestlineSettings.mapPosition=position else QuestlineSettings.trackerPosition=position end
  panel.grip.texture:Hide()
  if not hidden then Q:RefreshTrackers() end
end
local function makeRow(panel)
  local row=CreateFrame("Button",nil,panel)
  row:SetWidth(238)
  row.shade=row:CreateTexture(nil,"BACKGROUND");row.shade:SetAllPoints(row);row.shade:SetTexture(0.08,0.3,0.5,0.65)
  row.badge=Q:MakeBadge(row,23);row.badge:SetPoint("TOPLEFT",row,"TOPLEFT",1,0)
  row.title=font(row,12,1,0.82,0.32);row.title:SetPoint("TOPLEFT",row,"TOPLEFT",29,-3);row.title:SetWidth(205)
  row.detail=font(row,11);row.detail:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-4);row.detail:SetWidth(203)
  row:RegisterForClicks("LeftButtonUp","RightButtonUp");row.badge:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row:SetScript("OnClick",function() Q:TrackerClick(this.entry,arg1) end)
  row.badge:SetScript("OnClick",function() Q:TrackerClick(this:GetParent().entry,arg1) end)
  row:SetScript("OnEnter",function() if this.entry then Q:ShowQuestTooltip(this,this.entry) end end)
  row:SetScript("OnLeave",hideTooltip)
  row.badge:SetScript("OnEnter",function() if this:GetParent().entry then Q:ShowQuestTooltip(this,this:GetParent().entry) end end)
  row.badge:SetScript("OnLeave",hideTooltip)
  return row
end
local function makePanel(name,parent,isMap)
  local panel=CreateFrame("Frame",name,parent)
  panel:SetWidth(258);panel:SetHeight(180);panel:SetMovable(true);panel:EnableMouse(true);panel:SetClampedToScreen(true)
  panel:SetResizable(true);panel:SetMinResize(258,140);panel:SetMaxResize(700,900)
  panel:SetFrameStrata(isMap and "FULLSCREEN" or "MEDIUM")
  if isMap then panel:SetFrameLevel(WorldMapFrame:GetFrameLevel()+40) end
  panel:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
  panel:SetBackdropColor(0.025,0.045,0.065,0.90);panel:SetBackdropBorderColor(0.35,0.30,0.16,0.85)
  panel.isMap=isMap;panel.rows={};panel.page=1
  panel.header=CreateFrame("Button",nil,panel);panel.header:SetPoint("TOPLEFT",panel,"TOPLEFT",7,-5);panel.header:SetWidth(218);panel.header:SetHeight(23)
  panel.heading=font(panel.header,13,1,0.82,0.32);panel.heading:SetPoint("LEFT",panel.header,"LEFT",5,0)
  if not isMap then
    panel.header:SetWidth(143)
    panel.heading:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
    panel.mode=CreateFrame("Button",nil,panel);panel.mode:SetWidth(73);panel.mode:SetHeight(23)
    panel.mode:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-30,-5)
    panel.mode.text=font(panel.mode,11,0.55,0.8,1);panel.mode.text:SetAllPoints(panel.mode)
    panel.mode.text:SetJustifyH("CENTER");panel.mode.text:SetJustifyV("MIDDLE")
    panel.mode:SetScript("OnClick",function()
      hideTooltip();Q:SetTrackerMode(QuestlineSettings.trackerMode=="zone" and "world" or "zone")
    end)
    panel.mode:SetScript("OnEnter",function()
      local _,name=Q:GetPlayerZone()
      GameTooltip:SetOwner(this,"ANCHOR_LEFT")
      GameTooltip:SetText(QuestlineSettings.trackerMode=="zone" and "Show all quests" or ("Show quests in "..name),1,0.85,0.4)
      GameTooltip:Show()
    end)
    panel.mode:SetScript("OnLeave",hideTooltip)
    Q:StyleTextLink(panel.mode)
    panel.header:SetScript("OnEnter",function()
      GameTooltip:SetOwner(this,"ANCHOR_LEFT");GameTooltip:SetText(this:GetParent().headingText,1,0.85,0.4)
      GameTooltip:AddLine("Drag to move the tracker",0.55,0.8,1);GameTooltip:Show()
    end)
    panel.header:SetScript("OnLeave",hideTooltip)
  end
  panel.header:RegisterForDrag("LeftButton")
  panel.header:SetScript("OnDragStart",function() this:GetParent():StartMoving() end)
  panel.header:SetScript("OnDragStop",function()
    local p=this:GetParent();p:StopMovingOrSizing()
    local position={x=p:GetLeft(),y=p:GetTop()}
    if p.isMap then QuestlineSettings.mapPosition=position else QuestlineSettings.trackerPosition=position end
  end)
  panel.toggle=CreateFrame("Button",nil,panel);panel.toggle:SetWidth(22);panel.toggle:SetHeight(22);panel.toggle:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-5)
  panel.toggle.text=font(panel.toggle,16,1,0.8,0.3);panel.toggle.text:SetAllPoints(panel.toggle);panel.toggle.text:SetJustifyH("CENTER")
  panel.toggle:SetScript("OnClick",function()
    local p=this:GetParent();local key=p.isMap and "mapCollapsed" or "collapsed"
    finishResize(p,true)
    QuestlineSettings[key]=not QuestlineSettings[key];Q:RefreshTrackers()
  end)
  panel.rule=panel:CreateTexture(nil,"ARTWORK");panel.rule:SetTexture(0.85,0.63,0.14,0.65);panel.rule:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-29);panel.rule:SetWidth(234);panel.rule:SetHeight(1)
  panel.empty=font(panel,11,0.75,0.8,0.85);panel.empty:SetPoint("TOPLEFT",panel,"TOPLEFT",14,-38);panel.empty:SetWidth(229)
  panel.footer=font(panel,10,0.57,0.66,0.72);panel.footer:SetPoint("BOTTOM",panel,"BOTTOM",0,9)
  panel.previous=CreateFrame("Button",nil,panel);panel.previous:SetWidth(28);panel.previous:SetHeight(22);panel.previous:SetPoint("RIGHT",panel.footer,"LEFT",-8,0)
  panel.previous.text=font(panel.previous,16,1,0.82,0.32);panel.previous.text:SetAllPoints(panel.previous);panel.previous.text:SetText("<")
  panel.next=CreateFrame("Button",nil,panel);panel.next:SetWidth(28);panel.next:SetHeight(22);panel.next:SetPoint("LEFT",panel.footer,"RIGHT",8,0)
  panel.next.text=font(panel.next,16,1,0.82,0.32);panel.next.text:SetAllPoints(panel.next);panel.next.text:SetText(">")
  panel.previous.text:SetJustifyH("CENTER");panel.previous.text:SetJustifyV("MIDDLE")
  panel.next.text:SetJustifyH("CENTER");panel.next.text:SetJustifyV("MIDDLE")
  panel.previous:SetScript("OnClick",function() local p=this:GetParent();p.page=math.max(1,p.page-1);Q:RefreshTrackers() end)
  panel.next:SetScript("OnClick",function() local p=this:GetParent();p.page=math.min(p.pages or 1,p.page+1);Q:RefreshTrackers() end)
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel",function() this.page=math.max(1,math.min(this.pages or 1,this.page-(arg1 or 0)));Q:RefreshTrackers() end)
  panel.grip=CreateFrame("Button",nil,panel);panel.grip:SetWidth(16);panel.grip:SetHeight(16)
  panel.grip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-3,3)
  panel.grip.texture=panel.grip:CreateTexture(nil,"OVERLAY");panel.grip.texture:SetAllPoints(panel.grip)
  panel.grip.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up");panel.grip.texture:Hide()
  panel.grip:SetScript("OnEnter",function() this.texture:Show() end)
  panel.grip:SetScript("OnLeave",function() if not this:GetParent().resizing then this.texture:Hide() end end)
  panel.grip:SetScript("OnMouseDown",function()
    if arg1~="LeftButton" then return end
    local p=this:GetParent();hideTooltip()
    local x,y=p:GetLeft(),p:GetTop();p:ClearAllPoints();p:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
    p.resizing=true;p:StartSizing("BOTTOMRIGHT")
  end)
  panel.grip:SetScript("OnMouseUp",function() if arg1=="LeftButton" then finishResize(this:GetParent()) end end)
  panel:SetScript("OnHide",function() finishResize(this,true) end)
  panel:SetScript("OnSizeChanged",function()
    if this.resizing and not this.layoutBusy then saveSize(this);Q:RefreshTrackers() end
  end)
  return panel
end
function Q:PositionTrackers()
  for _,panel in ipairs({self.tracker,self.mapTracker}) do
    panel:ClearAllPoints()
    local saved
    if panel.isMap then saved=QuestlineSettings.mapPosition else saved=QuestlineSettings.trackerPosition end
    if saved then panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",saved.x,saved.y)
    elseif panel.isMap then panel:SetPoint("TOPRIGHT",WorldMapFrame,"TOPRIGHT",-25,-82)
    else panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-45,-240) end
  end
end
function Q:CreateTrackers()
  if self.tracker then return end
  self.tracker=makePanel("QuestlineTracker",UIParent,false)
  self.mapTracker=makePanel("QuestlineMapTracker",WorldMapFrame,true)
  self:PositionTrackers()
end
local function detailText(entry)
  if entry.complete then return "|cffffdf70Ready for turn-in|r" end
  if entry.failed then return "|cffff6060Quest failed|r" end
  local lines={}
  for _,o in ipairs(entry.objectives) do table.insert(lines,(o.done and "|cff69d979- " or "|cffe0ddd1- ")..o.text.."|r") end
  if getn(lines)==0 then table.insert(lines,Q:ExpandText(entry.summary)) end
  if not entry.id then table.insert(lines,"|cffdbaa78Location unavailable|r") end
  if entry.id and not Q:HasLocations(entry) then table.insert(lines,"|cffdbaa78No remaining mapped locations|r") end
  return table.concat(lines,"\n")
end
function Q:RenderTracker(panel,entries,zone,zoneName)
  if panel.layoutBusy then return end
  panel.layoutBusy=true
  local saved=QuestlineSettings[sizeKey(panel)]
  local width=saved and math.max(258,math.min(700,tonumber(saved.width) or 258)) or 258
  local requestedHeight=saved and math.max(140,math.min(900,tonumber(saved.height) or 180))
  panel:SetWidth(width)
  panel.header:SetWidth(width-(panel.isMap and 40 or 115))
  panel.rule:SetWidth(width-24);panel.empty:SetWidth(width-29)
  local closed=panel.isMap and QuestlineSettings.mapCollapsed or (not panel.isMap and QuestlineSettings.collapsed)
  if panel.isMap then
    panel.heading:SetText("Quests on this map")
  else
    local zoneMode=QuestlineSettings.trackerMode=="zone"
    local prefix="Quests - "
    panel.headingText=prefix..(zoneMode and zoneName or "World")
    panel.heading:SetText(panel.headingText)
    -- Keep long zone names out of the buttons; the header tooltip shows the full name.
    if panel.heading:GetStringWidth()>width-120 then panel.heading:SetText(prefix.."Zone") end
    panel.mode.text:SetText(zoneMode and "Show World" or "Show Zone")
  end
  panel.toggle.text:SetText(closed and "+" or "-")
  for _,row in ipairs(panel.rows) do row:Hide() end
  panel.empty:Hide();panel.footer:Hide();panel.previous:Hide();panel.next:Hide()
  if closed then panel.grip:Hide();panel:SetHeight(33);panel.layoutBusy=nil;return end
  panel.grip:Show()
  -- Measure at the chosen width before paginating; keep each quest together.
  local heights,starts={}, {1}
  local used,count=0,0
  if not panel.measure then panel.measure=makeRow(panel);panel.measure:Hide() end
  local measure=panel.measure
  measure.title:SetWidth(width-53);measure.detail:SetWidth(width-55)
  for i,entry in ipairs(entries) do
    measure.title:SetText(self:QuestTitle(entry));measure.detail:SetText(detailText(entry))
    heights[i]=math.max(25,measure.title:GetHeight()+measure.detail:GetHeight()+15)+4
    if count>0 and ((requestedHeight and used+heights[i]>requestedHeight-65) or (not requestedHeight and count==5)) then
      table.insert(starts,i);used=0;count=0
    end
    used=used+heights[i];count=count+1
  end
  panel.pages=getn(starts);panel.page=math.max(1,math.min(panel.pages,panel.page))
  local first,last=starts[panel.page],(starts[panel.page+1] or (getn(entries)+1))-1
  local top=37
  for index=first,last do
    local slot=index-first+1
    if not panel.rows[slot] then panel.rows[slot]=makeRow(panel) end
    local row,entry=panel.rows[slot],entries[index]
    row:SetWidth(width-20);row.title:SetWidth(width-53);row.detail:SetWidth(width-55)
    row.entry=entry;row:ClearAllPoints();row:SetPoint("TOPLEFT",panel,"TOPLEFT",9,-top)
    row.title:SetText(self:QuestTitle(entry));row.detail:SetText(detailText(entry))
    local height=math.max(25,row.title:GetHeight()+row.detail:GetHeight()+15)
    row:SetHeight(height)
    local selected=self:IsSelected(entry.key)
    self:PaintBadge(row.badge,entry,selected)
    if selected then row.shade:Show() else row.shade:Hide() end
    row:Show();top=top+height+4
  end
  if getn(entries)==0 then
    local message="Your quest log is empty."
    if panel.isMap then
      message=zone and "No mapped objectives here. Select a quest in the main tracker." or "Choose a zone map to see quest locations."
    elseif QuestlineSettings.trackerMode=="zone" and getn(self.quests)>0 then
      message="No mapped objectives in "..zoneName..".\nClick Show World to show all quests."
      if not zone then message="No quest locations available for this zone.\nClick Show World to show all quests." end
    end
    panel.empty:SetText(message)
    panel.empty:Show();top=top+panel.empty:GetHeight()+8
  end
  panel:SetHeight(math.max(requestedHeight or 0,top+(panel.pages>1 and 28 or 19)))
  if panel.pages>1 then
    panel.footer:SetText("Page "..panel.page.." / "..panel.pages.."  -  scroll")
    panel.footer:Show();panel.previous:Show();panel.next:Show()
  end
  panel.layoutBusy=nil
end
function Q:RefreshTrackers()
  if not self.tracker then return end
  local zone=self:GetMapZone()
  local mapEntries={}
  for _,entry in ipairs(self.quests) do if self:HasZone(entry,zone) then table.insert(mapEntries,entry) end end
  mapEntries=self:PrioritizeSelected(mapEntries)
  local entries,playerZone,zoneName=self:GetTrackerEntries()
  if self.tracker.zoneName~=zoneName and QuestlineSettings.trackerMode=="zone" then self.tracker.page=1 end
  self.tracker.zoneName=zoneName
  self:RenderTracker(self.tracker,entries,playerZone,zoneName)
  self:RenderTracker(self.mapTracker,mapEntries,zone)
  if QuestlineSettings.tracker then self.tracker:Show() else self.tracker:Hide() end
  self.mapTracker:Show()
end
