-- Strict WoW 1.12 UI/API simulation; this does not claim to render the game.
table.getn = table.getn or function(t) return #t end
math.mod = math.mod or math.fmod
unpack = unpack or table.unpack
-- Lua 5.0 uses ipairs itself as the iterator. Supplying ANY second argument
-- (even nil) performs an iteration step, unlike Fengari's newer Lua behavior.
-- Reference: https://www.lua.org/source/5.0/lbaselib.c.html#luaB_ipairs
function ipairs(t,...)
  assert(type(t)=="table","ipairs expects a table")
  if select("#",...)==0 then return ipairs,t,0 end
  local index=(tonumber((...)) or 0)+1
  local integer=math.modf(index)
  local value=rawget(t,integer)
  if value~=nil then return index,value end
end
local checks=0
function expect(test,message) checks=checks+1;if not test then error(message) end end
local widgets={}
local methods={}
local minimapIndoor,playerX,playerY,playerFacing=false,.522,.31,0
local minimapShape="ROUND"
local cvars={minimapZoom="0",minimapInsideZoom="0",rotateMinimap="0"}
local zoomWrites,mapResets=0,0
function GetCVar(name)
  if cvars[name]==nil then error("Couldn't find CVar named '"..name.."'") end
  return cvars[name]
end
function GetPlayerFacing() return playerFacing end
function GetPlayerMapPosition() return playerX,playerY end
function GetMinimapShape() return minimapShape end
function methods:GetZoom() return tonumber(cvars[minimapIndoor and "minimapInsideZoom" or "minimapZoom"]) end
function methods:SetZoom(value) cvars[minimapIndoor and "minimapInsideZoom" or "minimapZoom"]=tostring(value);zoomWrites=zoomWrites+1 end
function methods:SetResizable(v) self.resizable=v end
function methods:SetNormalTexture(texture) self.normalTexture=texture end
function methods:SetBlendMode(mode) self.blendMode=mode end
function methods:SetPushedTexture(texture) self.pushedTexture=texture end
function methods:SetHighlightTexture(texture) self.highlightTexture=texture end
function methods:SetParent(parent) self.parent=parent end
function methods:SetAutoFocus(value) self.autoFocus=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:ClearFocus() self.focused=false end
function methods:SetMinResize(w,h) self.minResize={w,h} end
function methods:SetMaxResize(w,h) self.maxResize={w,h} end
function methods:StartSizing(point) self.sizing=point end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width or (self.allPoints and self.allPoints:GetWidth()) or 100 end
function methods:GetHeight()
  if self.kind=="FontString" and not self.height then
    local text=string.gsub(self.text or "","|c%x%x%x%x%x%x%x%x","");text=string.gsub(text,"|r","")
    local lines=0
    for line in string.gmatch(text.."\n","(.-)\n") do lines=lines+math.max(1,math.ceil(string.len(line)*(self.fontSize or 12)*.5/self:GetWidth())) end
    return lines*(self.fontSize or 12)
  end
  return self.height or (self.allPoints and self.allPoints:GetHeight()) or 100
end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints(frame) self.allPoints=frame or self.parent end
function methods:Show() self.shown=true;self.fading=false;self.showCalls=(self.showCalls or 0)+1 end
function methods:FadeOut() self.fading=true end
function methods:Hide()
  local shown=self.shown;self.shown=false
  if shown and self.scripts.OnHide then
    local previous=this;this=self;self.scripts.OnHide();this=previous
  end
  if shown and self==GameTooltip and QuestlineMobTooltip then
    local previous=this;this=QuestlineMobTooltip;this.scripts.OnHide();this=previous
  end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function methods:GetParent() return self.parent end
function methods:SetOwner(owner) self.owner=owner end
function methods:GetLeft() return 20 end
function methods:GetTop() return 600 end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:SetFocus() self.focused=true end
function methods:Insert(text)
  local cursor=self.cursor or string.len(self.text or "")
  self.text=string.sub(self.text or "",1,cursor)..text..string.sub(self.text or "",cursor+1)
  self.cursor=cursor+string.len(text)
end
function methods:SetValue(value)
  self.value=value
  if self==QuestLogListScrollFrameScrollBar then QuestLogListScrollFrame.offset=math.floor(value/16) end
end
function methods:SetScript(event,script) self.scripts[event]=script end
function methods:GetScript(event) return self.scripts[event] end
function methods:SetTexture(...) self.textureValue={...} end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetShadowColor(...) self.shadowColor={...} end
function methods:SetShadowOffset(...) self.shadowOffset={...} end
function methods:SetFont(file,size,flags) self.fontSize=size end
function methods:SetText(text)
  self.text=tostring(text or "")
  if self==GameTooltip then
    for i=1,self:NumLines() do _G["GameTooltipTextLeft"..i]:Hide() end
    self.numLines=0;self:AddLine(self.text)
  end
end
function methods:GetText() return self.text end
function methods:GetStringWidth() return string.len(self.text or "")*(self.fontSize or 12)*.5 end
function methods:AddMessage(text) self.text=text end
function methods:NumLines() return self.numLines or 0 end
function methods:AddLine(text,...)
  self.text=(self.text or "").."\n"..text
  if self==GameTooltip then
    self.numLines=self:NumLines()+1
    local name="GameTooltipTextLeft"..self.numLines
    local line=_G[name] or self:CreateFontString(name,"OVERLAY")
    line:SetText(text);line:SetTextColor(...);line:Show()
  end
end
function methods:SetTextColor(...) self.color={...} end
for _,key in ipairs({"SetMovable","EnableMouse","SetClampedToScreen","SetFrameStrata","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","RegisterForDrag","EnableMouseWheel","SetJustifyH","SetJustifyV","StartMoving","StopMovingOrSizing"}) do methods[key]=function() end end
local function widget(kind,name,parent)
  local o=setmetatable({kind=kind,name=name,parent=parent,shown=true,scripts={},events={}}, {__index=function(_,k) if methods[k] then return methods[k] end end})
  if name then _G[name]=o end
  table.insert(widgets,o);return o
end
function methods:CreateTexture(name,layer) return widget("Texture",name,self) end
function methods:CreateFontString(name,layer) return widget("FontString",name,self) end
CreateFrame=widget
UIParent=widget("Frame","UIParent");UIParent:SetWidth(1440);UIParent:SetHeight(900)
WorldMapFrame=widget("Frame","WorldMapFrame",UIParent);WorldMapFrame:Hide()
WorldMapButton=widget("Button","WorldMapButton",WorldMapFrame);WorldMapButton:SetWidth(1002);WorldMapButton:SetHeight(668)
Minimap=widget("Minimap","Minimap",UIParent);Minimap:SetWidth(140);Minimap:SetHeight(140)
QuestWatchFrame=widget("Frame","QuestWatchFrame",UIParent)
QuestLogFrame=widget("Frame","QuestLogFrame",UIParent);QuestLogFrame:Hide()
QuestLogListScrollFrame=widget("Frame","QuestLogListScrollFrame",QuestLogFrame)
QuestLogListScrollFrameScrollBar=widget("Slider","QuestLogListScrollFrameScrollBar",QuestLogFrame)
ChatFrameEditBox=widget("EditBox","ChatFrameEditBox",UIParent);ChatFrameEditBox:Hide()
GameTooltip=widget("Frame","GameTooltip",UIParent)
WorldMapTooltip=widget("Frame","WorldMapTooltip",WorldMapFrame)
DEFAULT_CHAT_FRAME=widget("Frame",nil,UIParent)
SlashCmdList={}
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
local now=10
local shiftDown=false
function IsShiftKeyDown() return shiftDown end
function GetTime() return now end
local mouseoverName,mouseoverPlayer=nil,false
local npcName=nil
local playerLevel=12
function UnitLevel() return playerLevel end
function UnitName(unit) if unit=="mouseover" then return mouseoverName elseif unit=="npc" then return npcName end;return "Tester" end
function UnitIsPlayer(unit) return unit=="player" or (unit=="mouseover" and mouseoverPlayer) end
function getglobal(name) return _G[name] end
function UnitClass() return "Warrior","WARRIOR" end
function UnitRace() return "Orc","Orc" end
function UnitSex() return 2 end
local continent,zone=1,1
local playerZone="The Barrens"
function GetRealZoneText() return playerZone end
function GetZoneText() return playerZone end
function GetCurrentMapContinent() return continent end
function GetCurrentMapZone() return zone end
function GetMapZones(c) if c==1 then return "The Barrens","Durotar" else return "Elwynn Forest" end end
function GetMapContinents() return "Kalimdor","Eastern Kingdoms" end
function SetMapZoom(c,z) continent,zone=c,z end
function SetMapToCurrentZone()
  mapResets=mapResets+1
  if playerZone=="The Barrens" then continent,zone=1,1 elseif playerZone=="Durotar" then continent,zone=1,2 end
end
function ShowUIPanel(frame)
  frame:Show()
  if frame==QuestLogFrame then QuestLog_SetSelection(GetQuestLogSelection());QuestLog_Update() end
end
function HideUIPanel(frame) frame:Hide() end
function QuestWatch_Update() QuestWatchFrame:Show() end
local selection=1
local log={}
local function visible()
  local list={}
  for _,header in ipairs(log) do
    table.insert(list,header)
    if not header.closed then for _,quest in ipairs(header.quests) do table.insert(list,quest) end end
  end
  return list
end
function GetNumQuestLogEntries() return #visible() end
function GetQuestLogSelection() return selection end
function SelectQuestLogEntry(index) selection=index end
function QuestLog_SetSelection(index)
  assert(visible()[index] and not visible()[index].header,"quest log opened on a header or invalid entry")
  SelectQuestLogEntry(index);QuestLogFrame.selectedButtonID=index
end
function QuestLog_Update() QuestLogFrame.updateCount=(QuestLogFrame.updateCount or 0)+1 end
function GetQuestLogTitle(index)
  local q=visible()[index];if not q then return end
  return q.title,q.level,nil,q.header,q.closed,q.complete
end
function ExpandQuestHeader(index) visible()[index].closed=nil end
function CollapseQuestHeader(index) visible()[index].closed=true end
function GetQuestLogQuestText() local q=visible()[selection];return q.description or "",q.summary or "" end
function GetNumQuestLeaderBoards(index) return #(visible()[index].objectives or {}) end
function GetQuestLogLeaderBoard(i,index) local o=visible()[index].objectives[i];return o.text,o.kind,o.done end
function GetQuestLogRequiredMoney() return visible()[selection].money or 0 end
function GetMoney() return 100 end
function fire(name)
  event=name
  for _,w in ipairs(widgets) do if w.events[name] and w.scripts.OnEvent then this=w;w.scripts.OnEvent() end end
end
function tick(delta)
  now=now+delta;arg1=delta;this=QuestlineEvents;QuestlineEvents.scripts.OnUpdate()
end
function click(frame,button)
  button=button or "LeftButton"
  if button=="RightButton" then assert(frame.clicks and table.concat(frame.clicks,","):find("RightButtonUp"),"button has not registered right clicks") end
  this=frame;arg1=button;frame.scripts.OnClick()
end
local function quest(id,objectives,complete)
  local data=QuestlineDB.quests[id]
  return {id=id,title=data.title,level=data.level,summary=data.summary,description=data.description,objectives=objectives or {},complete=complete}
end

local function completionHistoryTests(Q)
  local original=Q.quests
  local history,sources=QuestlineSettings.completedQuests,QuestlineSettings.completionSources
  QuestlineSettings.completedQuests={};QuestlineSettings.completionSources={};Q:SetEntries({})
  for i=1,12 do QuestlineDB.quests[991000+i]={title="History quest "..i,level=1,minLevel=1,objectives={},prerequisites={},blockedBy={}} end
  expect(Q:SetQuestCompleted(991001,"Manual") and not Q:IsQuestAvailable(991001),"manual history suppresses available quests")
  expect(QuestlineSettings.completionSources[991001]=="Manual","manual source is saved separately from compatibility history")
  Q.npcOffers["test npc"]={time=GetTime(),quests={{title="History quest 1",level=1}}}
  expect(#Q:GetAvailableNPCQuests("Test NPC",{991001})==0,"observed offers cannot resurrect a hidden completed quest")
  Q:RestoreCompletedQuest(991001)
  expect(Q:IsQuestAvailable(991001) and not QuestlineSettings.completionSources[991001],"restoring removes history and metadata and allows eligibility")
  QuestlineDB.quests[991001].repeatable=true
  Q:SetQuestCompleted(991001,"Automatic");expect(Q:IsQuestAvailable(991001),"automatic completion retains repeatable offers")
  Q:SetQuestCompleted(991001,"Manual");expect(not Q:IsQuestAvailable(991001),"manual completion hides even repeatable offers until restored")
  local active={key="991002",id=991002,title="History quest 2",level=1,objectives={}}
  Q:SetEntries({active})
  expect(not Q:SetQuestCompleted(991002,"Manual"),"cannot manually mark a live quest completed")
  Q:ObserveQuestCompletion("History quest 2 completed.")
  expect(QuestlineSettings.completionSources[991002]=="Automatic","confirmed completion records automatic provenance")
  Q:SetEntries({});Q:InitializeNPCQuests()
  expect(QuestlineSettings.completedQuests[991001] and QuestlineSettings.completionSources[991001]=="Manual","initialization preserves manual history")
  for i=3,12 do Q:SetQuestCompleted(991000+i,"Manual") end
  QuestlineSettings.completedQuests[991013]=true
  expect(#Q:GetCompletionList("991001",true)==1 and #Q:GetCompletionList("history quest",false)==12,"history supports ID/title search and manual filtering")
  expect(Q:GetCompletionList("991013",false)[1].source=="Existing","old completion records keep unknown provenance rather than invented sources")
  Q:Command("");local f=Q.optionsPanel
  expect(f.section=="home" and f.home:IsShown() and not f.history:IsShown() and not f.settings:IsShown(),"slash menu starts on clean home page")
  expect(not f.mode,"main menu has no World/Zone control")
  click(f.optionsLink)
  expect(f.section=="options" and f.settings:IsShown() and not f.home:IsShown(),"options link opens separate settings page")
  Q:ShowOptionsSection("home");click(f.completedLink)
  expect(f and f:IsShown() and f.pages==2,"bare slash command opens paginated options/history panel")
  f.page=2;Q:RefreshOptions();expect(f.rows[1]:IsShown(),"later history page is reachable")
  click(f.filter);expect(f.manualOnly and f.page==1,"manual-only filter resets history page")
  f.search:SetText("991001");this=f.search;f.search.scripts.OnTextChanged()
  expect(f.rows[1].id==991001 and not f.rows[2]:IsShown(),"search narrows the displayed completion records")
  click(f.rows[1].restore);expect(not f.rows[1]:IsShown(),"restore button refreshes the open list immediately")
  expect(not Q:GetGiverPin(1,true).scripts.OnClick,"minimap markers have no completion click action")
  local pin=Q:GetGiverPin(1,false)
  for _,other in ipairs(Q.mapGivers) do other:Hide() end
  pin.giver={id=991101,name="Test NPC",quests={{id=991001,title="History quest 1"},{title="Ambiguous offer"}},points={}}
  pin.giverX=0;pin.giverY=0;pin:Show()
  click(pin,"RightButton")
  expect(Q.completionMenu:IsShown() and #Q.completionMenu.items==1,"right-click offers only uniquely identified available quests")
  Q:ShowCompletionMenu(pin,false)
  expect(Q.completionMenu:GetParent()==WorldMapFrame and Q.completionMenu:GetFrameLevel()==WorldMapFrame:GetFrameLevel()+60,"map context pane is elevated above map artwork like tracker")
  local menu=Q.completionMenu
  expect(menu:GetHeight()<100 and not menu.count:IsShown() and not menu.next:IsShown(),"one-quest menu is compact without page controls")
  expect(menu.rows[1].text:GetText()=="History quest 1","context rows contain only quest names")
  expect(menu.close:GetFrameLevel()>menu:GetFrameLevel() and menu.dismiss:GetFrameLevel()<menu:GetFrameLevel(),"close and menu controls stay above outside-click layer")
  this=menu.dismiss;menu.dismiss.scripts.OnMouseDown()
  expect(not menu:IsShown() and not menu.dismiss:IsShown(),"clicking outside closes menu and removes click catcher")
  Q:ShowCompletionMenu(pin,false);click(menu.close)
  expect(not menu:IsShown() and not menu.dismiss:IsShown(),"close button also dismisses menu and click catcher")
  Q:ShowCompletionMenu(pin,false)
  click(Q.completionMenu.rows[1])
  expect(not Q.completionMenu:IsShown() and QuestlineSettings.completionSources[991001]=="Manual","context action records manual completion and closes menu")
  Q:Command("");expect(not f:IsShown(),"slash command toggles options closed")
  f.search:SetText("");f.manualOnly=nil
  QuestlineSettings.completedQuests=history;QuestlineSettings.completionSources=sources
  for i=1,12 do QuestlineDB.quests[991000+i]=nil end
  Q:SetEntries(original);Q.npcOffers={};Q:InvalidateQuestAvailability()
end
local function trackerMapTests(Q)
  local original,mode=Q.quests,QuestlineSettings.trackerMode
  local a={key="double:objective",name="Test target",kind="unit",icon="sword"}
  local b={key="double:finisher",id=991112,name="Test giver",kind="unit",icon="turnin"}
  QuestlineDB.locations[a.key]={[14]={points={{50,50}},runs="",anchor={50,50}}}
  QuestlineDB.locations[b.key]={[17]={points={{50,50}},runs="",anchor={50,50}}}
  local entry={key="double:quest",id=991111,title="Map test",level=1,objectives={},data={objectives={a},finishers={b}}}
  Q:SetEntries({entry});Q:SetTrackerMode("world");playerZone="The Barrens";SetMapZoom(1,1);WorldMapFrame:Hide()
  local row=Q.tracker.rows[1]
  click(row);expect(not WorldMapFrame:IsShown() and Q:IsSelected(entry.key),"single click highlights without opening map")
  this=row;arg1="LeftButton";row.scripts.OnDoubleClick()
  expect(WorldMapFrame:IsShown() and Q:GetMapZone()==14 and Q:IsSelected(entry.key),"tracker double-click opens off-zone objective map and highlights quest")
  entry.complete=true;Q:SetEntries({entry})
  this=Q.tracker.rows[1].badge;arg1="LeftButton";this.scripts.OnDoubleClick()
  expect(Q:GetMapZone()==17,"badge double-click on completed quest opens turn-in zone")
  entry.complete=false;entry.objectives={{text="Test target: 1/1",done=true}}
  Q:SetEntries({entry});WorldMapFrame:Hide();Q:TrackerDoubleClick(entry,"LeftButton")
  expect(not WorldMapFrame:IsShown(),"completed objective locations are not used when nothing remains mapped")
  entry.objectives={};QuestlineDB.locations[a.key][17]=QuestlineDB.locations[b.key][17]
  Q:TrackerDoubleClick(entry,"LeftButton");expect(Q:GetMapZone()==17,"multi-zone quest prefers physical zone")
  shiftDown=true;WorldMapFrame:Hide();Q:TrackerDoubleClick(entry,"LeftButton");shiftDown=false
  expect(not WorldMapFrame:IsShown(),"shift double-click preserves chat-link gesture")
  Q:TrackerDoubleClick(entry,"RightButton");expect(not WorldMapFrame:IsShown(),"right double-click cannot trigger map navigation")
  Q:SetEntries({});Q:TrackerDoubleClick(entry,"LeftButton")
  expect(not WorldMapFrame:IsShown(),"stale tracker entry cannot open a quest map")
  QuestlineDB.locations[a.key]=nil;QuestlineDB.locations[b.key]=nil
  Q:SetEntries(original);Q:SetTrackerMode(mode);SetMapZoom(1,1)
end
local function trackerResizeTests(Q)
  local original,mode=Q.quests,QuestlineSettings.trackerMode
  local entries={}
  for i=1,12 do entries[i]={key="resize:"..i,title="Resize quest "..i,level=i,summary="",objectives={{text="Collect quest items: 0/8",done=false}}} end
  Q:SetEntries(entries);Q:SetTrackerMode("world");Q:Command("reset")
  local panel=Q.tracker
  expect(panel:GetWidth()==258 and panel.pages==3,"unresized tracker retains five quests per page")
  expect(not panel.grip.texture:IsShown(),"resize grip is invisible by default")
  this=panel.grip;panel.grip.scripts.OnEnter()
  expect(panel.grip.texture:IsShown(),"resize grip appears on corner hover")
  arg1="RightButton";panel.grip.scripts.OnMouseDown()
  expect(not panel.resizing,"right click does not resize")
  arg1="LeftButton";panel.grip.scripts.OnMouseDown()
  expect(panel.resizing and panel.sizing=="BOTTOMRIGHT" and panel.point[1]=="TOPLEFT","resize fixes the top-left corner and starts bottom-right sizing")
  panel:SetWidth(420);panel:SetHeight(600);this=panel;panel.scripts.OnSizeChanged()
  expect(panel.rows[1]:GetWidth()==400 and panel.rows[1].detail:GetWidth()==365,"rows and objective wrapping follow resized width")
  expect(panel.pages<3 and QuestlineSettings.trackerSize.height==600,"taller tracker fits more quests and saves dimensions")
  this=panel.grip;panel.grip.scripts.OnLeave()
  expect(panel.grip.texture:IsShown(),"grip remains visible while dragging outside the corner")
  panel.grip.scripts.OnMouseUp()
  expect(not panel.resizing and not panel.grip.texture:IsShown(),"releasing resize stops sizing and hides grip")
  expect(QuestlineSettings.trackerPosition.x==panel:GetLeft(),"resize saves the new top-left anchor")
  Q:RefreshTrackers();expect(panel:GetWidth()==420 and panel:GetHeight()==600,"ordinary refresh retains saved dimensions")
  expect(Q.mapTracker:GetWidth()==258 and not QuestlineSettings.mapSize,"HUD resize does not resize map tracker")
  click(panel.toggle);expect(panel:GetHeight()==33 and not panel.grip:IsShown(),"collapsed tracker hides resize handle")
  click(panel.toggle);expect(panel:GetWidth()==420 and panel:GetHeight()==600,"expansion restores expanded dimensions")
  QuestlineSettings.trackerSize={width=258,height=180};Q:RefreshTrackers()
  local seen={}
  for page=1,panel.pages do
    panel.page=page;Q:RefreshTrackers()
    for _,row in ipairs(panel.rows) do if row:IsShown() then
      expect(not seen[row.entry.key],"resized pagination does not duplicate quests");seen[row.entry.key]=true
    end end
  end
  for _,entry in ipairs(entries) do expect(seen[entry.key],"resized pagination keeps every quest reachable") end
  entries[1].objectives={{text=string.rep("Long objective text ",70),done=false}}
  panel.page=1;Q:RefreshTrackers()
  expect(panel:GetHeight()>=37+panel.rows[1]:GetHeight()+28,"single oversized quest expands panel rather than clipping objectives")
  local map=Q.mapTracker
  this=map.grip;arg1="LeftButton";map.grip.scripts.OnMouseDown()
  map:SetWidth(350);map:SetHeight(400);this=map;map.scripts.OnSizeChanged();map.scripts.OnHide()
  expect(not map.resizing and QuestlineSettings.mapSize.width==350,"hiding map during resize finalizes its independent size")
  Q:Command("reset")
  expect(not QuestlineSettings.trackerSize and not QuestlineSettings.mapSize and panel:GetWidth()==258,"reset restores automatic tracker sizing")
  Q:SetEntries(original);Q:SetTrackerMode(mode)
end
local function trackerModeTests(Q)
  local original,selected=Q.quests,QuestlineSettings.selected
  local targets={}
  for _,id in ipairs({14,17}) do
    local key="test-zone:"..id
    QuestlineDB.locations[key]={[id]={runs="",points={},anchor={50,50}}}
    targets[id]={key=key,name="Objective",kind="unit"}
  end
  local entries={}
  for i=1,14 do
    local target=targets[i<=6 and 14 or 17]
    entries[i]={key="test-quest:"..i,id=990000+i,title="Quest "..i,summary="",objectives={},
      complete=i==14,data={objectives={target},finishers={targets[14]}}}
  end
  entries[13].data=nil;entries[13].id=nil -- Unmapped quests still belong in World mode.
  Q:SetTrackerMode("world")
  Q:SetEntries(entries)
  WorldMapFrame:Hide();Q:RefreshTrackers()
  expect(Q.tracker:IsVisible(),"normal tracker shown outside the map")
  expect(QuestlineSettings.trackerMode=="world" and Q.tracker.heading:GetText()=="Quests - World","explicit World mode shows all quests")
  expect(Q.tracker.mode.text:GetText()=="Show Zone" and #Q:GetTrackerEntries()==14,"World offers Show Zone and includes unmapped quests")
  Q.tracker.page=3;Q:RefreshTrackers();Q:Select(entries[12].key);expect(Q.tracker.page==3 and Q.tracker.rows[2].entry==entries[12],"single selection preserves page three and level sorting")
  click(Q.tracker.mode)
  expect(QuestlineSettings.trackerMode=="zone" and Q.tracker.heading:GetText()=="Quests - The Barrens","mode click uses physical zone and saves preference")
  expect(Q.tracker.mode.text:GetText()=="Show World" and Q.tracker.page==1,"mode switch resets pagination and offers Show World")
  expect(#Q:GetTrackerEntries()==6 and Q.tracker.rows[1].entry.number==7,"Zone preserves shared quest numbers and excludes completed quests with off-zone turn-ins")
  expect(QuestlineSettings.selected==entries[12].key,"mode switch preserves highlighted quest")
  Q:Select(entries[12].key)
  expect(Q.tracker.page==1 and Q.tracker.rows[1].entry==entries[7],"single selection leaves filtered level order unchanged")

  WorldMapFrame:Show();Q:RefreshMap()
  Q:RefreshTrackers();expect(Q.tracker:IsVisible() and Q.mapTracker:IsVisible(),"both trackers remain visible with a windowed world map")
  click(Q.mapPins[1])
  expect(QuestlineSettings.selected==entries[7].key and Q.tracker.page==1,"map click selects and pages correctly in Zone mode")
  Q:Select(entries[12].key)

  WorldMapFrame:Show();SetMapZoom(1,2);fire("WORLD_MAP_UPDATE");Q:RefreshMap()
  expect(Q:GetMapZone()==14 and Q:GetPlayerZone()==17,"browsed map and physical zone remain independent")
  expect(Q.tracker.heading:GetText()=="Quests - The Barrens" and #Q:GetTrackerEntries()==6,"browsing another map leaves HUD scope unchanged")
  expect(Q.mapTracker.rows[1].entry==entries[1] and Q.mapTracker.pages==2,"map tracker continues filtering the displayed map")
  Q:Select(entries[14].key)
  click(Q.mapTracker.next);expect(Q.mapTracker.rows[2].badge.text:GetText()=="?","completed quest retains its level-sorted position")
  expect(Q.tracker.page==1 and #Q:GetTrackerEntries()==6,"selecting an off-zone map quest preserves HUD filter and resets its page")

  playerZone="Durotar";fire("ZONE_CHANGED_NEW_AREA")
  expect(Q.tracker.heading:GetText()=="Quests - Durotar" and Q.tracker.page==1,"travel updates zone heading and resets page")
  expect(#Q:GetTrackerEntries()==7,"new zone includes active objectives and completed turn-ins")
  click(Q.tracker.next);fire("ZONE_CHANGED_INDOORS")
  expect(Q.tracker.page==2,"moving indoors in the same zone preserves pagination")
  entries[1].objectives={{text="Objective: 1/1",done=true}};Q:SetEntries(entries)
  expect(#Q:GetTrackerEntries()==6,"finished objectives stop contributing to the zone list")
  click(Q.tracker.mode)
  expect(#Q:GetTrackerEntries()==14 and Q.tracker.heading:GetText()=="Quests - World","World restores every quest")
  expect(Q.mapTracker.page==2 and Q.mapTracker.rows[1].entry==entries[14],"HUD mode toggle preserves map filtering and page")

  WorldMapFrame:Hide();Q:RefreshTrackers()
  click(Q.tracker.toggle);click(Q.tracker.mode)
  expect(QuestlineSettings.collapsed and Q.tracker.mode:IsVisible(),"mode remains available on the collapsed tracker")
  playerZone="An Unmapped Zone With A Very Long Name";fire("ZONE_CHANGED")
  expect(Q.tracker.heading:GetText()=="Quests - Zone","long zone names leave room for header controls")
  expect(Q.tracker.headingText=="Quests - "..playerZone,"header retains full zone name for tooltip")
  click(Q.tracker.toggle)
  expect(#Q:GetTrackerEntries()==0 and Q.tracker.empty:IsShown(),"unknown zone does not fall back to the browsed map")
  expect(Q.tracker.empty:GetText():find("Click Show World"),"empty zone offers an escape to all quests")
  WorldMapFrame:Show();Q:RefreshMap();click(Q.mapPins[1])
  expect(QuestlineSettings.selected==entries[2].key and #Q:GetTrackerEntries()==0,"map selection works when physical zone has no database ID")
  fire("PLAYER_ENTERING_WORLD")
  expect(QuestlineSettings.trackerMode=="zone","world-entry refresh preserves saved mode")
  click(Q.tracker.mode)
  expect(#Q:GetTrackerEntries()==14,"World remains usable in an unmapped zone")

  playerZone="The Barrens";SetMapZoom(1,1)
  QuestlineDB.locations[targets[14].key]=nil;QuestlineDB.locations[targets[17].key]=nil
  QuestlineSettings.selected=selected;Q:SetEntries(original);Q:RefreshMap()
end

local function mobTooltipTests(Q)
  expect(GameTooltip.GetOwner==nil,"Vanilla tooltip tests run without the unavailable GetOwner method")
  local savedLog,savedSelection=log,selection
  local ribs=quest(426,{{text="Blackened Skull: 0/3",kind="item"},{text="Notched Rib: 0/5",kind="item"}})
  local kills=quest(380,{{text="Night Web Spider slain: 3/8",kind="monster"},{text="Young Night Web Spider slain: 2/10",kind="monster"}})
  log={{title="Tirisfal Glades",header=true,closed=true,quests={ribs,kills}}}
  Q:ScanLog();Q:SetTrackerMode("zone");Q:Select("380")
  expect(Q.byKey["426"] and Q.byKey["380"],"tooltip fixtures resolve from the real imported quests")
  local function hover(name)
    mouseoverName=name;mouseoverPlayer=false
    GameTooltip:SetOwner(UIParent,"ANCHOR_NONE")
    GameTooltip:SetText(name);GameTooltip:AddLine("Level 7 Undead");GameTooltip:Show()
    this=QuestlineMobTooltip;arg1=.2;this.scripts.OnUpdate()
  end
  hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==4 and GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[426]),"mob tooltip includes the relevant quest heading")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","mob tooltip indents its quest item's live count")
  expect(GameTooltipTextLeft2:GetText()=="Level 7 Undead","existing tooltip details retained")
  expect(log[1].closed and QuestlineSettings.selected=="380","tooltip reads collapsed quests without changing shared selection")
  for i=1,5 do Q:RefreshMobTooltip() end
  expect(GameTooltip:NumLines()==4,"repeated tooltip updates never append duplicate headings or progress")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls
  for i=1,5 do Q:RefreshMobTooltip() end
  expect(GameTooltipTextLeft3:IsShown() and GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","quest heading and item progress persist after leaving the mob")
  expect(GameTooltip:NumLines()==4 and GameTooltip.fading and GameTooltip.showCalls==shows,"lingering quest details neither duplicate lines nor restart the tooltip fade")
  expect(not Q.updatingMobTooltip,"leaving the mob does not lock future tooltip refreshes")
  mouseoverName="Night Web Spider";Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 0/5","moving toward a different mob keeps the original tooltip intact until it is replaced")
  hover("Night Web Spider")
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[380]) and GameTooltipTextLeft4:GetText()=="  Night Web Spider - 3/8","replacement mob tooltip shows only the new mob's quest")
  mouseoverName=nil;GameTooltip:Hide()
  expect(Q.mobTooltipName==nil and Q.mobTooltipOwner==nil and #Q.mobTooltipLines==0,"hiding the tooltip ends its remembered unit lifetime")
  GameTooltip:SetText("Night Web Spider");GameTooltip:Show();Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"a new non-unit tooltip with the same title cannot resurrect old quest details")
  hover("Rattlecage Soldier");mouseoverName=nil
  GameTooltip:SetText("A bag item");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1 and Q.mobTooltipName==nil,"replacing a fading tooltip with an item clears its unit association")
  hover("Rattlecage Soldier");mouseoverName=nil
  GameTooltip:SetText("Rattlecage Soldier");GameTooltip:AddLine("A different tooltip with the same title");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==2 and Q.mobTooltipName==nil,"same-title content replacement is detected when the original quest lines are gone")
  -- Also check the optional owner safeguard on clients that provide a getter.
  GameTooltip.GetOwner=function(tooltip) return tooltip.owner end
  hover("Rattlecage Soldier");mouseoverName=nil;GameTooltip:SetOwner(Q.tracker,"ANCHOR_RIGHT");Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown(),"changing tooltip owners cannot retain the previous unit's quest lines")
  GameTooltip.GetOwner=nil
  hover("Rattlecage Soldier")
  ribs.objectives[2].text="Notched Rib: 1/5";now=now+1;fire("QUEST_LOG_UPDATE");tick(.2);Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 1/5" and GameTooltip:NumLines()==4,"quest-log events update counters while still hovering")
  hover("Cracked Skull Soldier")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 1/5","other recorded drop sources show the same collection progress")
  hover("Darkeye Bonecaster")
  expect(GameTooltipTextLeft4:GetText()=="  Blackened Skull (40%) - 0/3","a different mob gets only its own relevant item objective")
  hover("Young Night Web Spider")
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(QuestlineDB.quests[380]) and GameTooltipTextLeft4:GetText()=="  Young Night Web Spider - 2/10","kill counters appear under their quest and match names rather than database objective order")
  hover("Night Web Spider")
  expect(GameTooltipTextLeft4:GetText()=="  Night Web Spider - 3/8","similar mob names do not mix kill counters")

  ribs.objectives[2].text="Notched Rib: 5/5";ribs.objectives[2].done=1;Q:ScanLog();hover("Rattlecage Soldier")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5" and GameTooltipTextLeft4.color[2]>GameTooltipTextLeft4.color[1],"completed objectives show full progress in green")
  ribs.complete=1;Q:ScanLog();Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5","completed quest progress remains available until turn-in")
  ribs.complete=-1;Q:ScanLog();Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown(),"failed quest removes its heading and counter while hovering")
  ribs.complete=nil;Q:ScanLog();Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:IsShown() and GameTooltip:NumLines()==4,"cleared tooltip slots are reused")
  hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==4,"rebuilding a tooltip for the same mob restores exactly one quest group")

  -- Two accepted quests can need the exact same item/count, while one also needs
  -- another drop from this mob. Preserve both groups and live objective ordering.
  local mills,spiders=Q.byKey["426"],Q.byKey["380"]
  local shared={key="test:shared-ribs",id=990001,level=1,title="Supplies for Brill",summary="",
    data={objectives={{kind="item",key="item:2589",name="Linen Cloth"},{kind="item",key="item:3162",name="Notched Rib"}},finishers={}},
    objectives={{text="Notched Rib: 5/5",kind="item",done=true},{text="Linen Cloth: 1/10",kind="item"}}}
  Q:SetEntries({shared,mills,spiders});hover("Rattlecage Soldier")
  expect(GameTooltip:NumLines()==7 and GameTooltipTextLeft3:GetText()==Q:QuestTitle(shared) and GameTooltipTextLeft6:GetText()==Q:QuestTitle(mills),"shared mobs show quest groups in level order")
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5" and GameTooltipTextLeft5:GetText()=="  Linen Cloth (30%) - 1/10","multiple relevant objectives share one heading in live log order")
  expect(GameTooltipTextLeft7:GetText()=="  Notched Rib (40%) - 5/5","identical counters remain visible under each quest")
  shared.objectives[1]={text="Notched Rib: 3/7",kind="item"};Q:SetEntries({shared,mills,spiders});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 3/7" and GameTooltipTextLeft7:GetText()=="  Notched Rib (40%) - 5/5","quests sharing an item retain independent current and required counts")
  GameTooltip:SetText("Rattlecage Soldier")
  GameTooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r "..mills.title)
  GameTooltip:AddLine("|cffaaaaaa- |rNotched Rib: 5/5 |cff555555[40%]|r");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==6 and GameTooltipTextLeft4:GetText()==Q:QuestTitle(shared),"an existing quest group does not suppress another quest using the same item")
  expect(GameTooltipTextLeft5:GetText()=="  Notched Rib (40%) - 3/7" and GameTooltipTextLeft6:GetText()=="  Linen Cloth (30%) - 1/10","new group keeps its own counters beside pfQuest content")
  hover("Rattlecage Soldier");Q:SetEntries({shared,spiders});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(shared) and not GameTooltipTextLeft6:IsShown() and not GameTooltipTextLeft7:IsShown(),"removing one quest clears only its group")
  Q:ScanLog();hover("Rattlecage Soldier")

  GameTooltip:SetText("Rattlecage Soldier")
  GameTooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r The Mills Overrun")
  GameTooltip:AddLine("|cffaaaaaa- |rNotched Rib: 5/5 |cff555555[40%]|r")
  GameTooltip:AddLine("Another addon's detail");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==4 and GameTooltipTextLeft4:GetText()=="Another addon's detail","existing matching pfQuest group is not duplicated or overwritten")
  GameTooltip:SetText("Rattlecage Soldier");GameTooltip:AddLine("Notched Rib: 5/5");Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()==Q:QuestTitle(mills) and GameTooltipTextLeft4:GetText()=="  Notched Rib (40%) - 5/5","unlabelled external progress cannot hide the requested quest grouping")
  hover("Cow");expect(GameTooltip:NumLines()==2,"unrelated mobs have no quest progress")
  mouseoverName="Rattlecage Soldier";mouseoverPlayer=true;GameTooltip:SetText(mouseoverName);Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"player tooltips are ignored")
  mouseoverPlayer=false;GameTooltip:SetText("Some bag item");Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==1,"item tooltip is not decorated just because a mob is under the cursor")
  Q:ScanLog();hover("Rattlecage Soldier")
  log[1].quests={kills};Q:ScanLog();Q:RefreshMobTooltip()
  expect(not GameTooltipTextLeft3:IsShown() and not GameTooltipTextLeft4:IsShown() and #Q:GetMobProgress("Rattlecage Soldier")==0,"abandoning or turning in a quest clears its heading and cached progress")
  log=savedLog;selection=savedSelection;mouseoverName=nil
  Q:SetTrackerMode("world");Q:ScanLog();GameTooltip:Hide()
end

local function trackerClickTests(Q)
  local function row(id)
    for page=1,Q.tracker.pages do
      Q.tracker.page=page;Q:RefreshTrackers()
      for _,r in ipairs(Q.tracker.rows) do if r:IsShown() and r.entry.id==id then return r end end
    end
    error("Missing visible tracker quest "..id)
  end
  local savedLog,savedSelection=log,selection
  local savedCompat=pfQuestCompat
  local beaks=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}})
  local hooves=quest(845,{{text="Zhevra Hooves: 0/4",kind="item"}})
  log={{title="The Barrens",header=true,closed=true,quests={beaks,hooves}},
    {title="Tirisfal Glades",header=true,closed=true,quests={quest(426)}},
    {title="Durotar",header=true,quests={quest(869,{},1)}}}
  selection=4;Q:ScanLog();Q:SetTrackerMode("world");Q:Select("869")
  WorldMapFrame:Hide();QuestLogFrame:Hide();Q:RefreshTrackers()
  local nativeCalls=0
  local function nativeLink(index)
    nativeCalls=nativeCalls+1
    local q=visible()[index];assert(q and not q.header,"native quest link given invalid index")
    return "|cffffff00|Hquest:"..q.id..":"..q.level.."|h["..q.title.."]|h|r"
  end
  GetQuestLinkForLogIndex=nativeLink
  shiftDown=true;ChatFrameEditBox:Show();ChatFrameEditBox:SetText("Before  after");ChatFrameEditBox.cursor=7
  click(row(844))
  expect(ChatFrameEditBox:GetText()=="Before |cffffff00|Hquest:844:"..beaks.level.."|h["..beaks.title.."]|h|r after","shift-click inserts the client's native quest link at the chat cursor")
  expect(nativeCalls==1 and ChatFrameEditBox.focused,"uses the same link API as Octo's Blizzard quest log")
  expect(selection==4 and log[1].closed and log[2].closed,"linking restores collapsed categories and quest-log selection")
  expect(QuestlineSettings.selected=="869" and not QuestLogFrame:IsShown(),"linking preserves highlighted quest and does not open the log")
  ChatFrameEditBox:Hide();click(row(845).badge)
  expect(QuestlineSettings.selected=="845" and not ChatFrameEditBox:IsShown() and nativeCalls==1,"shift-click with chat closed keeps normal selection behavior")
  ChatFrameEditBox:Show();local draft=ChatFrameEditBox:GetText()
  click(row(844).badge,"RightButton")
  expect(QuestLogFrame:IsShown() and visible()[selection].id==844,"right-click on a tracker circle opens that quest")
  expect(not log[1].closed and log[2].closed and ChatFrameEditBox:GetText()==draft,"right-click expands only the needed category and wins over Shift")
  expect(QuestlineSettings.selected=="845","opening the log preserves the highlighted map quest")
  shiftDown=false;log[1].closed=true;log[2].closed=true;selection=4
  click(row(426),"RightButton")
  expect(selection==3 and visible()[selection].id==426 and log[1].closed and not log[2].closed,"restoring earlier collapsed categories remaps the destination index correctly")

  SetMapZoom(1,1);WorldMapFrame:Show();Q.mapDirty=true;Q:RefreshMap()
  click(Q.mapTracker.rows[2],"RightButton")
  expect(not WorldMapFrame:IsShown() and QuestLogFrame:IsShown() and visible()[selection].id==845,"map tracker right-click reveals the quest log instead of leaving it behind the map")
  shiftDown=true;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0
  click(Q.mapTracker.rows[1].badge)
  expect(ChatFrameEditBox:GetText():find("|Hquest:844:"),"map tracker badges also support chat links")
  GetQuestLinkForLogIndex=nil;GetQuestLink=nativeLink
  ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(845))
  expect(ChatFrameEditBox:GetText():find("|Hquest:845:"),"standard GetQuestLink is supported when the Octo API is absent")
  GetQuestLink=nil
  pfQuestCompat={InsertQuestLink=function(id,title) ChatFrameEditBox:Insert("pfQuest:"..id..":"..title) end}
  ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(844))
  expect(ChatFrameEditBox:GetText()=="pfQuest:844:"..beaks.title,"pfQuest's configured link format remains a fallback")
  pfQuestCompat=nil;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0;click(row(844))
  expect(ChatFrameEditBox:GetText()=="["..beaks.title.."]","unmodified Vanilla falls back to the quest title")

  shiftDown=false;QuestLogFrame:Hide()
  log[1].quests={hooves};selection=2 -- Quest removed before the next tracker refresh.
  click(row(844),"RightButton")
  expect(not QuestLogFrame:IsShown() and selection==2,"stale tracker entry cannot open a different quest")
  local custom={id=999995,title="Uncatalogued Delivery",level=12,summary="Custom objective",description="Custom details",objectives={}}
  log={{title="Custom",header=true,closed=true,quests={custom}}};selection=1;Q:ScanLog()
  click(Q.tracker.rows[1],"RightButton")
  expect(visible()[selection]==custom and not Q.quests[1].id,"quests without a database match still open from their live text")
  GetQuestLinkForLogIndex=nativeLink;shiftDown=true;ChatFrameEditBox:SetText("");ChatFrameEditBox.cursor=0
  click(Q.tracker.rows[1]);expect(ChatFrameEditBox:GetText():find("|Hquest:999995:"),"unknown database quests still get native chat links")
  shiftDown=false;GetQuestLinkForLogIndex=nil
  log[1].quests={custom,custom};log[1].closed=true;selection=1;QuestLogFrame:Hide()
  click(Q.tracker.rows[1],"RightButton")
  expect(not QuestLogFrame:IsShown() and log[1].closed,"ambiguous live entries are not guessed")

  local many={};for _,id in ipairs({844,845,895,900,869,426,380,903}) do table.insert(many,quest(id)) end
  log={{title="Mixed",header=true,closed=true,quests=many}};selection=1;Q:ScanLog();Q:Select("903")
  click(row(903),"RightButton")
  expect(visible()[selection].id==903 and QuestLogListScrollFrameScrollBar.value==48,"right-click scrolls the destination quest into the visible log list")
  pfQuestCompat=savedCompat;log=savedLog;selection=savedSelection
  ChatFrameEditBox:Hide();QuestLogFrame:Hide();Q:ScanLog()
end

local function npcQuestTests(Q)
  local DB=QuestlineDB
  local original,history,level=Q.quests,QuestlineSettings.completedQuests,playerLevel
  QuestlineSettings.completedQuests={};Q:SetEntries({});Q.npcOffers={};Q.recentQuests={}
  local name="Deathguard Dillinger"
  local function has(groups,title)
    for _,g in ipairs(groups) do if g.title==title then return g end end
  end
  local function entry(id,objectives,complete)
    local e=quest(id,objectives,complete);e.key=tostring(id);e.data=DB.quests[id];return e
  end
  local function hover(npc)
    mouseoverName=npc;mouseoverPlayer=false;GameTooltip:SetText(npc);GameTooltip:AddLine("Level 55");GameTooltip:Show();Q:RefreshMobTooltip()
  end
  local sections=Q:GetNPCSections(name)
  expect(has(sections[1].groups,"A Putrid Task") and not has(sections[1].groups,"The Mills Overrun"),"NPC offers the first quest, not its locked follow-up")
  playerLevel=3;expect(not Q:IsQuestAvailable(404),"quests below their minimum level are hidden")
  playerLevel=12
  hover(name)
  expect(GameTooltipTextLeft3:GetText()=="Available" and GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[404]),"NPC tooltip groups eligible offers under Available")
  expect(GameTooltip:NumLines()==4,"empty NPC status sections are omitted")
  local task=entry(404,{{text="Putrid Claw: 7/10",kind="item"}})
  Q:SetEntries({task});hover(name);sections=Q:GetNPCSections(name)
  expect(#sections[1].groups==0 and #sections[2].groups==1,"accepting moves the quest from Available to In Progress")
  expect(GameTooltipTextLeft3:GetText()=="In Progress" and GameTooltipTextLeft5:GetText()=="    Putrid Claw - 7/10","NPC progress appears under an indented quest title")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls;Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()=="In Progress" and GameTooltipTextLeft5:IsShown() and GameTooltipTextLeft5:GetText()=="    Putrid Claw - 7/10","NPC sections and indented quest counters persist during fade")
  expect(GameTooltip.fading and GameTooltip.showCalls==shows,"NPC details leave the normal fade timing intact")
  mouseoverName=name
  task.objectives[1]={text="Putrid Claw: 10/10",kind="item",done=true};task.complete=true;Q:SetEntries({task});Q:RefreshMobTooltip()
  expect(GameTooltipTextLeft3:GetText()=="Complete" and GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[404]) and not GameTooltipTextLeft5:IsShown(),"ready-to-turn-in quest replaces progress without leaving old counters")
  expect(not Q:IsQuestAvailable(426),"finishing objectives alone does not unlock the next quest")
  Q:SetEntries({});expect(not QuestlineSettings.completedQuests[404] and Q:IsQuestAvailable(404),"removing or abandoning a quest does not record a turn-in")
  arg1="A Putrid Task completed.";fire("CHAT_MSG_SYSTEM")
  expect(QuestlineSettings.completedQuests[404] and Q:IsQuestAvailable(426) and not Q:IsQuestAvailable(404),"completion message after log removal records the recent quest and unlocks its successor")
  hover(name);expect(GameTooltipTextLeft4:GetText()=="  "..Q:QuestTitle(QuestlineDB.quests[426]),"NPC tooltip advances to the unlocked quest")
  local oldFormat=ERR_QUEST_COMPLETE_S;ERR_QUEST_COMPLETE_S="Completed [%s]!"
  local mills=entry(426,{{text="Notched Rib: 2/5",kind="item"},{text="Blackened Skull: 1/3",kind="item"}})
  Q:SetEntries({mills});hover(name)
  expect(GameTooltipTextLeft5:GetText()=="    Notched Rib - 2/5" and GameTooltipTextLeft6:GetText()=="    Blackened Skull - 1/3","questgiver lists every live objective in log order")
  arg1="Completed [The Mills Overrun]!";fire("CHAT_MSG_SYSTEM");ERR_QUEST_COMPLETE_S=oldFormat
  expect(QuestlineSettings.completedQuests[426],"completion parsing honors the client's localized format and pattern punctuation")
  Q:SetEntries({});Q.recentQuests={};QuestlineSettings.completedQuests[404]=nil
  arg1="A Putrid Task completed.";fire("CHAT_MSG_SYSTEM")
  expect(not QuestlineSettings.completedQuests[404],"unrelated or expired completion names cannot mark unknown quests completed")

  local oldImported,oldPf=QuestlineSettings.importedQuestHistory,pfQuest_history
  pfQuest_history={[860]={123,12},[404]={123,12},[999999]=false};QuestlineSettings.importedQuestHistory=nil
  Q:InitializeNPCQuests()
  expect(QuestlineSettings.completedQuests[860] and not QuestlineSettings.completedQuests[999999],"login imports valid local pfQuest history")
  expect(pfQuest_history[860][1]==123,"history import leaves pfQuest settings untouched")
  pfQuest_history=oldPf;QuestlineSettings.importedQuestHistory=oldImported
  local synthetic={title="Restricted offer",level=12,minLevel=10,raceMask=2,classMask=1,prerequisites={},blockedBy={}}
  DB.quests[990011]=synthetic
  expect(Q:IsQuestAvailable(990011),"matching race/class can receive an unrestricted quest")
  synthetic.raceMask=1;expect(not Q:IsQuestAvailable(990011),"opposite race quest is hidden")
  synthetic.raceMask=2;synthetic.classMask=128;expect(not Q:IsQuestAvailable(990011),"other class quest is hidden")
  synthetic.classMask=1;synthetic.prerequisites={404,999999};expect(Q:IsQuestAvailable(990011),"alternative prerequisites unlock when any supported predecessor is completed")
  synthetic.blockedBy={404};expect(not Q:IsQuestAvailable(990011),"completed mutually exclusive quest prevents offer")
  synthetic.blockedBy={};synthetic.event=25;expect(not Q:IsQuestAvailable(990011),"seasonal quests require a server offer")
  synthetic.event=nil;synthetic.skill="Cooking";Q.npcSkills=nil
  local oldSkills,oldSkill=GetNumSkillLines,GetSkillLineInfo
  GetNumSkillLines=function() return 1 end;GetSkillLineInfo=function() return "Cooking",nil,nil,0 end
  expect(not Q:IsQuestAvailable(990011),"unlearned profession quests are hidden")
  GetSkillLineInfo=function() return "Cooking",nil,nil,25 end;fire("SKILL_LINES_CHANGED")
  expect(Q:IsQuestAvailable(990011),"learning a profession unlocks its quests")
  QuestlineSettings.completedQuests[990011]=true;expect(not Q:IsQuestAvailable(990011),"completed one-time quests stay hidden")
  synthetic.repeatable=true;expect(Q:IsQuestAvailable(990011),"explicit repeatable quests can be offered again")
  QuestlineSettings.completedQuests[990011]=nil;DB.quests[990011]=nil;GetNumSkillLines=oldSkills;GetSkillLineInfo=oldSkill;Q.npcSkills=nil

  local oldGossip=GetGossipAvailableQuests;npcName=name
  GetGossipAvailableQuests=function() return "A holiday surprise",12,"A server-only quest",13 end
  fire("GOSSIP_SHOW");sections=Q:GetNPCSections(name)
  expect(#sections[1].groups==2 and sections[1].groups[2].title=="A server-only quest","actual Vanilla gossip title/level pairs override predicted offers")
  GetGossipAvailableQuests=function() end;fire("GOSSIP_SHOW")
  expect(#Q:GetNPCSections(name)[1].groups==0,"an explicitly empty server offer list suppresses stale predictions")
  QuestlineSettings.completedQuests[404]=nil;now=now+61
  expect(has(Q:GetNPCSections(name)[1].groups,"A Putrid Task"),"temporary gossip observations expire")
  local oldNum,oldTitle,oldLevel=GetNumAvailableQuests,GetAvailableTitle,GetAvailableLevel
  GetNumAvailableQuests=function() return 1 end;GetAvailableTitle=function() return "Greeting offer" end;GetAvailableLevel=function() return 12 end
  fire("QUEST_GREETING");expect(Q:GetNPCSections(name)[1].groups[1].title=="Greeting offer","non-gossip quest greetings also supply actual offers")
  GetGossipAvailableQuests=oldGossip;GetNumAvailableQuests=oldNum;GetAvailableTitle=oldTitle;GetAvailableLevel=oldLevel;npcName=nil;Q.npcOffers={}

  local travel=entry(80209,{{text="Speak to Magistrix Ishalah: 0/1",kind="event"},{text="Portal used: 0/1",kind="event"}})
  Q:SetEntries({travel});hover("Magistrix Ishalah")
  local group=has(Q:GetNPCSections("Magistrix Ishalah")[2].groups,travel.title)
  expect(group and #group.objectives==1 and group.objectives[1].text=="Talk to Magistrix Ishalah - 0/1","a conversation objective is identified without treating the NPC as a giver or finisher")
  expect(GameTooltipTextLeft3:GetText()=="In Progress","talk-to quest uses the In Progress section")
  travel.complete=true;Q:SetEntries({travel})
  local s=Q:GetNPCSections("Magistrix Ishalah");expect(not s or (#s[2].groups==0 and #s[3].groups==0),"finished talk objective is not advertised as a turn-in at the wrong NPC")
  local unknown={key="unknown:talk",title="A new conversation",summary="",objectives={{text="Talk with A Helpful Stranger: 0/1",kind="event"}}}
  Q:SetEntries({unknown});expect(Q:GetNPCSections("A Helpful Stranger")[2].groups[1].objectives[1].text=="Talk to A Helpful Stranger - 0/1","explicit live conversation objectives work for quests absent from the database")
  unknown.summary="Speak to A Helpful Stranger.";unknown.data={objectives={{kind="unit",name="A Helpful Stranger",key="unit:990012"}},finishers={}}
  unknown.objectives={{text="A Helpful Stranger slain: 0/1",kind="monster"}};Q:SetEntries({unknown})
  expect(Q:GetNPCSections("A Helpful Stranger")==nil,"a kill objective is not relabeled as conversation because the summary also says speak")
  QuestlineSettings.completedQuests=history;playerLevel=level;Q:SetEntries(original)
  Q:InvalidateQuestAvailability();mouseoverName=nil;GameTooltip:Hide()
end

local function giverMapTests(Q)
  local history,original=QuestlineSettings.completedQuests,Q.quests
  QuestlineSettings.completedQuests={[860]=true};Q:SetEntries({});Q.npcOffers={};Q:InvalidateQuestAvailability()
  playerZone="The Barrens";SetMapZoom(1,1);WorldMapFrame:Show();Q:RefreshQuestGivers()
  local function find(pool,id)
    for _,pin in ipairs(pool) do if pin:IsShown() and pin.giver.id==id then return pin end end
  end
  local pin=find(Q.mapGivers,3338)
  expect(pin and math.abs(pin.point[4]-.522*1002)<.001 and math.abs(pin.point[5]+.31*668)<.001,"available Sergra Darkthorn marker is placed at her imported Barrens position")
  expect(#pin.giver.quests==1 and pin.giver.quests[1].title=="Plainstrider Menace","giver pin lists only eligible quests")
  this=pin;pin.scripts.OnEnter();expect(WorldMapTooltip:GetText():find("Available") and WorldMapTooltip:GetText():find("Plainstrider Menace"),"map marker hover identifies NPC and available quest")
  WorldMapButton.scale=4;Q:RefreshQuestGivers();expect(pin.width==3.5,"smaller giver icon retains screen size under map zoom")
  WorldMapButton.scale=1
  SetMapZoom(1,2);Q:RefreshQuestGivers();expect(not find(Q.mapGivers,3338),"browsing another zone removes Barrens questgivers")
  local resets=mapResets;Q:RefreshQuestGivers();expect(mapResets==resets and Q:GetMapZone()==14,"minimap never resets a map the player is browsing")
  WorldMapFrame:Hide();playerX,playerY=.522,.31;Q:RefreshQuestGivers()
  expect(Q:GetMapZone()==17 and mapResets==resets+1,"closing an off-zone map restores player coordinates before minimap drawing")
  pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.001 and math.abs(pin.point[5])<.001,"nearby questgiver appears at minimap center when beside the NPC")
  expect(not find(Q.mapGivers,3338),"hidden world map releases visible marker state")
  local size=QuestlineDB.zones[17].mapSize
  WorldMapFrame:Show();Q:RefreshQuestGivers()
  expect(find(Q.minimapGivers,3338) and find(Q.mapGivers,3338),"opening current-zone map keeps minimap questgivers visible")
  playerX=.522-50/size[1];Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-15)<.01,"minimap markers still follow movement while the world map is open")
  SetMapZoom(1,2);resets=mapResets;playerX,playerY=.05,.95;Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-15)<.01,"browsing another zone retains last valid minimap position instead of interpreting other-zone coordinates")
  expect(mapResets==resets and Q:GetMapZone()==14,"retaining minimap markers does not change the browsed map")
  playerZone="Durotar";SetMapZoom(2,1);Q:RefreshQuestGivers()
  expect(not find(Q.minimapGivers,3338),"crossing a physical zone boundary cannot reuse the previous zone's cached position")
  playerZone="The Barrens";SetMapZoom(1,1);playerX,playerY=.522,.31;Q:RefreshQuestGivers()
  expect(find(Q.minimapGivers,3338),"returning to current-zone view resumes live positioning")
  WorldMapFrame:Hide()
  playerX=.522-100/size[1];Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"minimap translates one hundred yards to thirty pixels at outdoor zoom zero")
  Minimap:SetZoom(3);Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-52.5)<.01,"minimap marker follows zoom changes")
  Minimap:SetZoom(5);Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"out-of-range giver is clipped rather than pinned beyond the minimap")
  Minimap:SetZoom(0);cvars.rotateMinimap="1";playerFacing=math.pi/2;Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.01 and math.abs(pin.point[5]+30)<.01,"rotation applies player facing when the client supports it")
  cvars.rotateMinimap=nil
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"missing rotation CVar falls back to north-up even with facing API")
  local savedGetCVar,savedFacing=GetCVar,GetPlayerFacing
  GetCVar=function(name) if name=="rotateMinimap" then return nil end;return savedGetCVar(name) end
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01 and math.abs(pin.point[5])<.01,"nil rotation setting also uses north-up")
  GetCVar=savedGetCVar;GetPlayerFacing=nil
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01,"minimap markers work without facing API or rotation CVar")
  GetPlayerFacing=savedFacing;cvars.rotateMinimap="1"
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4])<.01 and math.abs(pin.point[5]+30)<.01,"available rotation setting is still read after fallback")
  cvars.rotateMinimap="0";playerFacing=0
  minimapIndoor=true;cvars.minimapInsideZoom="0";Q.minimapDiameterKey=nil;local writes=zoomWrites
  Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-46.6667)<.01 and Minimap:GetZoom()==0,"indoor radius is detected and user's zoom is restored")
  Q:RefreshQuestGivers();expect(zoomWrites==writes+2,"indoor detection probe is cached, not repeated every update")
  minimapIndoor=false;fire("ZONE_CHANGED_INDOORS");Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and math.abs(pin.point[4]-30)<.01,"crossing indoors/outdoors invalidates radius even when both zoom settings match")
  local p={(.522+180/size[1])*100,(.31-180/size[2])*100}
  expect(not Q:MinimapGiverPosition(p,.522,.31,size,466.6667),"round minimap clips diagonal corners")
  minimapShape="SQUARE";expect(Q:MinimapGiverPosition(p,.522,.31,size,466.6667),"square minimap retains visible corner markers");minimapShape="ROUND"
  local accepted=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}});accepted.key="844";accepted.data=QuestlineDB.quests[844]
  Q:SetEntries({accepted});Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"accepting the giver's only available quest immediately removes its minimap marker")
  accepted.complete=true;Q:SetEntries({accepted});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.texture.textureValue[1]=="Interface\\GossipFrame\\ActiveQuestIcon","ready quest creates a matching gold question mark on the minimap")
  expect(#pin.giver.turnins==1 and #pin.giver.quests==0,"turn-in marker appears even without available pickup quests")
  this=pin;pin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Ready for turn-in",1,true) and GameTooltip:GetText():find("Plainstrider Menace",1,true),"turn-in hover lists the ready quest")
  local delivery=quest(842,{},1);delivery.key="842";delivery.data=QuestlineDB.quests[842];delivery.complete=true
  Q:SetEntries({accepted,delivery});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and #pin.giver.turnins==2,"multiple completed quests share the NPC's question mark")
  local onlyFinisher={id=990022,key="990022",title="Delivery only",complete=true,objectives={},data={objectives={},finishers={{kind="unit",id=990023,name="A turn-in-only NPC",key="turnin:unit:3338"}}}}
  Q:SetEntries({accepted,onlyFinisher});Q:RefreshQuestGivers()
  local finishPin=find(Q.minimapGivers,990023)
  expect(finishPin and finishPin.texture.textureValue[1]:find("ActiveQuestIcon",1,true),"finishers absent from the pickup-NPC index still receive a question mark")
  this=finishPin;finishPin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Delivery only",1,true) and GameTooltip:GetText():find("Plainstrider Menace",1,true),"clustered turn-in tooltips include neighboring NPCs and ready quests")
  onlyFinisher.failed=true;Q:SetEntries({accepted,onlyFinisher});Q:RefreshQuestGivers()
  expect(not find(Q.minimapGivers,990023),"failed quests never create turn-in question marks")
  Q:SetEntries({accepted});Q:RefreshQuestGivers()
  Q.npcOffers[Q:Normalize("Sergra Darkthorn")]={time=GetTime(),quests={{title="Another available quest",level=12}}}
  Q:InvalidateQuestAvailability();Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and #pin.giver.quests==1 and pin.texture.textureValue[1]:find("ActiveQuestIcon",1,true),"turn-in question mark wins when the NPC also offers another quest")
  this=pin;pin.scripts.OnEnter()
  expect(GameTooltip:GetText():find("Another available quest",1,true) and GameTooltip:GetText():find("Ready for turn-in",1,true),"combined tooltip retains both pickup and turn-in information")
  local count=0;for _,p in ipairs(Q.minimapGivers) do if p:IsShown() and p.giver.id==3338 then count=count+1 end end
  expect(count==1,"one NPC never receives stacked pickup and turn-in minimap icons")
  accepted.complete=false;Q:SetEntries({accepted});Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.texture.textureValue[1]:find("AvailableQuestIcon",1,true),"reused marker switches back to exclamation when turn-in readiness is lost")
  Q.npcOffers={};Q:InvalidateQuestAvailability()
  QuestlineSettings.completedQuests[844]=true;Q:SetEntries({});Q:InvalidateQuestAvailability();Q:RefreshQuestGivers();pin=find(Q.minimapGivers,3338)
  expect(pin and pin.giver.quests[1].title=="The Zhevra","turn-in unlocks next offer and restores the giver marker")
  playerX,playerY=0,0;Q:RefreshQuestGivers();expect(not find(Q.minimapGivers,3338),"invalid player coordinates hide minimap pins")
  playerX,playerY=.522,.31;QuestlineSettings.completedQuests=history;Q:SetEntries(original);Q:InvalidateQuestAvailability()
  WorldMapFrame:Hide();Q:RefreshQuestGivers()
end

local function giverClusterTests(Q)
  local mapPool,miniPool=Q.mapGivers,Q.minimapGivers
  Q.mapGivers={};Q.minimapGivers={};WorldMapFrame:Show()
  local names={"A nearby giver","B nearby giver","C nearby giver","D distant giver","E hidden giver","B nearby giver"}
  local coords={{100,100},{109,100},{114,112},{200,100},{104,100},{108,101}}
  for i=1,6 do
    local pin=Q:GetGiverPin(i,false)
    pin.giver={id=i==6 and 2 or i,name=names[i],quests={{title=names[i].." quest one"},{title=names[i].." quest two"}}}
    pin.giverX=coords[i][1];pin.giverY=coords[i][2];pin:Show()
  end
  Q.mapGivers[5]:Hide()
  expect(#Q:GetNearbyGivers(Q.mapGivers[1],false)==3,"nearby giver hover combines three visible NPCs without duplicates, distant or hidden pins")
  this=Q.mapGivers[1];this.scripts.OnEnter();local text=WorldMapTooltip:GetText()
  for i=1,3 do
    expect(text:find(names[i].." quest one",1,true) and text:find(names[i].." quest two",1,true),"cluster tooltip includes each nearby NPC and all its quests")
  end
  expect(not text:find(names[4],1,true) and not text:find(names[5],1,true),"cluster tooltip excludes distant and hidden NPCs")
  expect(#Q:GetNearbyGivers(Q.mapGivers[2],false)==3,"hovering another overlapping giver still exposes its neighbors")
  for _,pin in ipairs(Q.mapGivers) do pin:SetWidth(3.5);pin:SetHeight(3.5) end
  expect(#Q:GetNearbyGivers(Q.mapGivers[1],false)==1,"world-map zoom separates clusters according to on-screen distance")
  for i=1,3 do
    local pin=Q:GetGiverPin(i,true);pin.giver=Q.mapGivers[i].giver
    pin.giverX=i==3 and 50 or (i-1)*8;pin.giverY=0;pin:Show()
  end
  this=Q.minimapGivers[1];this.scripts.OnEnter();text=GameTooltip:GetText()
  expect(text:find(names[1].." quest one",1,true) and text:find(names[2].." quest two",1,true) and not text:find(names[3],1,true),"minimap hover also combines nearby NPC names and quests")
  for _,pool in ipairs({Q.mapGivers,Q.minimapGivers}) do for _,pin in ipairs(pool) do pin:Hide() end end
  Q.mapGivers=mapPool;Q.minimapGivers=miniPool;WorldMapFrame:Hide();GameTooltip:Hide();WorldMapTooltip:Hide()
end

local function questLevelAndRateTests(Q)
  local savedLog,savedSelection,savedLevel=log,selection,playerLevel
  local selected=QuestlineSettings.selected
  local beaks,hooves,mills,raptors=quest(844),quest(845),quest(426),quest(869)
  log={{title="Mixed levels",header=true,closed=true,quests={hooves,mills,beaks,raptors}}};selection=1
  QuestlineSettings.selected="845";Q:ScanLog();Q:SetTrackerMode("world")
  expect(Q.quests[1].id==426 and Q.quests[2].id==844 and Q.quests[3].id==845 and Q.quests[4].id==869,"tracker quests sort from lowest level to highest with stable log-order ties")
  expect(log[1].quests[1]==hooves and log[1].closed and selection==1,"level sorting never rearranges or expands the actual quest log")
  expect(QuestlineSettings.selected=="845" and Q.byKey["845"].number==3,"level sorting preserves selected quest identity and updates shared numbering")
  expect(Q:Normalize(Q.tracker.rows[1].title:GetText())=="[8] the mills overrun","normal tracker displays quest level before its title after the highlighted quest")
  SetMapZoom(1,1);WorldMapFrame:Show();Q:RefreshMap()
  expect(Q.mapTracker.rows[1].entry.id==844 and Q.mapTracker.rows[2].entry.id==845,"zone-filtered map tracker prioritizes highlights before other quests")
  local mapped
  for _,pin in ipairs(Q.mapPins) do if pin:IsShown() and pin.entry.id==845 then mapped=pin end end
  expect(mapped and mapped.text:GetText()=="3","map circle uses the same sorted quest number as the tracker")
  playerLevel=12
  local expected={{18,"ff1919"},{15,"ff7f3f"},{12,"ffff00"},{8,"3fbf3f"},{1,"7f7f7f"}}
  for _,case in ipairs(expected) do
    expect(Q:QuestTitle({title="Keep this gold",level=case[1]})=="[|cff"..case[2]..case[1].."|r] Keep this gold","only the level number gets the expected fallback difficulty color")
  end
  expect(Q:QuestTitle({title="Unknown level"})=="Unknown level" and Q:QuestTitle({title="Unspecified",level=-1})=="Unspecified","unknown levels do not display invented numbers")
  local getter=GetDifficultyColor
  GetDifficultyColor=function(level) expect(level==8,"native Vanilla color API receives quest level");return {r=.2,g=.4,b=.6} end
  expect(Q:QuestTitle({title="Native colors",level=8})=="[|cff3366998|r] Native colors","native difficulty colors take precedence when provided by the client")
  GetDifficultyColor=getter
  playerLevel=14;arg1=14;fire("PLAYER_LEVEL_UP");tick(.2)
  expect(Q.tracker.rows[1].title:GetText():find("|cff7f7f7f8|r",1,true),"level-up events refresh difficulty colors in visible trackers")
  local unknown={title="Unknown",key="unknown",objectives={},summary=""}
  local lower={title="Lower",key="lower",level=2,objectives={},summary=""}
  Q:SetEntries({unknown,lower});expect(Q.quests[2]==unknown,"unidentified levels sort after numbered quests")

  local meat=quest(40535,{{text="Leg Meat: 1/2",kind="item"}})
  log={{title="Mulgore",header=true,quests={meat}}};selection=2;Q:ScanLog()
  local groups=Q:GetMobProgress("Adult Plainstrider")
  expect(groups[1].objectives[1].text=="Leg Meat (10%) - 1/2","mob progress rounds its drop percentage to the nearest whole number")
  expect(Q:GetMobProgress("Plainstrider")[1].objectives[1].text=="Leg Meat (17%) - 1/2","different mobs can show different rates for the same quest item")
  expect(Q.tooltipProgress['item:7097'][1].text=="Leg Meat - 1/2","per-mob display never mutates shared quest counters")
  local rates=QuestlineDB.mobDropRates['adult plainstrider'];local rate=rates['item:7097']
  rates['item:7097']=nil;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat - 1/2","unknown percentages are omitted without losing item progress")
  rates['item:7097']=100;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (100%) - 1/2","integer percentages have no trailing decimal zeros")
  rates['item:7097']=12.5;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (13%) - 1/2","half-percent values round upward")
  rates['item:7097']=12.49;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (12%) - 1/2","values below half a percent round downward")
  rates['item:7097']=.0065;expect(Q:GetMobProgress("Adult Plainstrider")[1].objectives[1].text=="Leg Meat (0%) - 1/2","small known rates follow the same nearest-whole-percent rounding")
  rates['item:7097']=rate
  mouseoverName="Adult Plainstrider";mouseoverPlayer=false
  GameTooltip:SetText(mouseoverName);GameTooltip:AddLine(Q:QuestTitle(Q.quests[1]));GameTooltip:AddLine("  Leg Meat (10%) - 1/2");GameTooltip:Show();Q:RefreshMobTooltip()
  expect(GameTooltip:NumLines()==3,"existing groups with colored level prefixes and percentage labels are not duplicated")
  log=savedLog;selection=savedSelection;playerLevel=savedLevel;QuestlineSettings.selected=selected;Q:ScanLog()
  mouseoverName=nil;GameTooltip:Hide();WorldMapFrame:Hide()
end

local function multiSelectionTests(Q)
  local original,oldSelected,oldKeys=Q.quests,QuestlineSettings.selected,QuestlineSettings.selectedKeys
  local oldControl,oldMode=IsControlKeyDown,QuestlineSettings.trackerMode
  local ctrl=false;IsControlKeyDown=function() return ctrl end
  local entries,targets={},{}
  local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
  local function coord(n) return alphabet:sub(math.floor(n/64)+1,math.floor(n/64)+1)..alphabet:sub(n%64+1,n%64+1) end
  for i=1,12 do
    local key="multi-target:"..i
    local zone=i==11 and 14 or 17
    local runs=""
    if i<9 then for y=100+i*12,103+i*12 do runs=runs..coord(y)..coord(100+i*15)..coord(110+i*15) end end
    QuestlineDB.locations[key]={[zone]={runs=runs,points=i>=9 and {{50,50}} or {},anchor={20+i*4,30}}}
    targets[i]={key=key,name="Objective "..i,kind="unit",icon="kill"}
    entries[i]={key="multi:"..i,id=980000+i,title="Multi "..i,level=math.ceil(i/2),summary="",objectives={},data={objectives={targets[i]},finishers={targets[9] or targets[i]}}}
  end
  entries[10].data.objectives={targets[9]} -- A shared point must not create duplicate icons.
  entries[12].data=nil;entries[12].id=nil;entries[12].level=nil
  QuestlineSettings.selectedKeys=nil;QuestlineSettings.selected="multi:1"
  SetMapZoom(1,1);playerZone="The Barrens";Q:SetEntries(entries);Q:SetTrackerMode("world");WorldMapFrame:Show();Q:RefreshMap()
  local function pin(i)
    for _,p in ipairs(Q.mapPins) do if p:IsShown() and p.entry.key=="multi:"..i then return p end end
    error("Missing map pin "..i)
  end
  local function row(panel,i)
    for page=1,panel.pages do
      panel.page=page;Q:RefreshTrackers()
      for _,r in ipairs(panel.rows) do if r:IsShown() and r.entry.key=="multi:"..i then return r end end
    end
    error("Missing tracker row "..i)
  end
  local function selectedCount()
    local n=0;for _,entry in ipairs(Q.quests) do if Q:IsSelected(entry.key) then n=n+1 end end;return n
  end
  local function visibleCount(pool)
    local n=0;for _,item in ipairs(pool) do if item:IsShown() then n=n+1 end end;return n
  end
  expect(Q:IsSelected("multi:1") and selectedCount()==1,"old single-selection settings work before the first Ctrl-click")
  ctrl=true;click(pin(8))
  expect(selectedCount()==2 and Q:IsSelected("multi:1") and Q:IsSelected("multi:8"),"Ctrl-click on a map circle extends the existing highlight")
  expect(Q.tracker.page==1 and Q.mapTracker.page==1 and Q.tracker.rows[2].entry.key=="multi:8","selection resets both trackers to highlighted quests on page one")
  expect(pin(1).glow:IsShown() and pin(8).glow:IsShown() and not pin(2).glow:IsShown(),"all selected map badges glow and other badges remain unselected")
  expect(visibleCount(Q.fills)==2,"two separated selected areas render together")
  click(row(Q.mapTracker,2).badge)
  expect(selectedCount()==3 and Q.tracker.rows[2].entry.key=="multi:2" and Q.tracker.rows[3].entry.key=="multi:8","map tracker Ctrl-click preserves level order within highlights, including tied levels")
  WorldMapFrame:Hide();click(row(Q.tracker,9))
  expect(selectedCount()==4 and Q:IsSelected("multi:9"),"outside-map tracker rows support Ctrl-click")
  click(row(Q.tracker,8).badge)
  expect(selectedCount()==3 and not Q:IsSelected("multi:8"),"Ctrl-click on an already selected tracker badge removes just that quest")
  WorldMapFrame:Show();Q:RefreshMap()
  expect(visibleCount(Q.fills)==2 and visibleCount(Q.objectivePins)==1,"remaining blue areas and a selected single-point action icon coexist")
  click(pin(10))
  expect(selectedCount()==4 and visibleCount(Q.objectivePins)==1,"shared single-point objectives use one action icon while both quest circles remain highlighted")
  for _,entry in ipairs(Q.quests) do expect(entry.number==tonumber(entry.key:sub(7)),"highlight changes preserve shared map and tracker numbers") end
  local layout=Q.areaLayoutKey;local widgetCount=#widgets
  Q.mapDirty=true;Q:RefreshMap()
  expect(Q.areaLayoutKey==layout and #widgets==widgetCount,"unchanged multi-selection reuses area layout and UI objects")
  for _,i in ipairs({8,7,6}) do click(pin(i)) end
  local ordered=Q:GetTrackerEntries()
  expect(selectedCount()==7 and ordered[1].key=="multi:1" and ordered[3].key=="multi:6" and ordered[7].key=="multi:10" and ordered[8].key=="multi:3","more than five highlights sort first by level before the remaining quests")
  click(Q.tracker.next)
  expect(Q.tracker.rows[1].entry.key=="multi:9" and Q.tracker.rows[1].shade:IsShown() and not Q.tracker.rows[3].shade:IsShown(),"highlighted overflow continues on page two ahead of unselected quests")
  click(row(Q.tracker,12))
  expect(Q:IsSelected("multi:12") and Q.tracker.rows[5].entry.key=="multi:8","unmapped quests can join a highlighted group and unknown levels sort last within it")
  click(row(Q.tracker,11))
  Q:SetTrackerMode("zone")
  local scoped=Q:GetTrackerEntries()
  expect(#scoped==10 and not Q:HasZone(Q.byKey["multi:11"],17) and Q:IsSelected("multi:11") and Q:IsSelected("multi:12"),"Zone mode filters off-zone and unmapped highlights without deselecting them")
  SetMapZoom(1,2);Q.mapDirty=true;Q:RefreshMap()
  expect(Q.mapTracker.rows[1].entry.key=="multi:11" and pin(11).glow:IsShown() and #Q:GetTrackerEntries()==10,"browsing another map displays its highlighted quests without changing the physical-zone tracker")
  SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap();Q:SetTrackerMode("world")
  local count=selectedCount();local oldAction=Q.QuestLogAction;local action
  Q.QuestLogAction=function(self,entry,open) action=open and "open" or "link" end
  shiftDown=true;ChatFrameEditBox:Show();click(row(Q.tracker,3))
  expect(action=="link" and selectedCount()==count and not Q:IsSelected("multi:3"),"Shift-chat linking takes precedence over Ctrl and preserves the highlighted set")
  click(row(Q.mapTracker,3),"RightButton")
  expect(action=="open" and selectedCount()==count,"right-click keeps opening the quest log without changing multiple highlights")
  Q.QuestLogAction=oldAction;shiftDown=false;ChatFrameEditBox:Hide()
  entries[9].complete=true;Q:SetEntries(entries);Q:RefreshMap()
  expect(Q:IsSelected("multi:9") and pin(9).text:GetText()=="?" and pin(9).glow:IsShown(),"quest completion preserves its highlight and uses the turn-in marker")
  local remaining={};for _,entry in ipairs(entries) do if entry.key~="multi:1" then table.insert(remaining,entry) end end
  Q:SetEntries(remaining);Q:RefreshMap()
  expect(not Q:IsSelected("multi:1") and Q:IsSelected("multi:2") and Q:IsSelected("multi:9"),"removing a selected quest prunes only that quest from saved highlights")
  local savedSet={};for key,value in pairs(QuestlineSettings.selectedKeys) do savedSet[key]=value end
  QuestlineSettings.selectedKeys=savedSet;QuestlineSettings.selected=nil;Q:SetEntries(remaining)
  expect(selectedCount()==count-1 and Q:IsSelected("multi:12"),"saved multi-selection restores by quest key on a fresh quest-log snapshot")
  Q:ShowQuestTooltip(row(Q.tracker,2),Q.byKey["multi:2"])
  ctrl=false;click(pin(3))
  expect(selectedCount()==1 and Q:IsSelected("multi:3") and Q:GetTrackerEntries()[1].key=="multi:2","normal map click replaces the group with one highlighted quest at the front")
  expect(not Q.partyQuestTooltip and not WorldMapTooltip:IsShown(),"moving tracker rows clears their stale tooltip and party hover refresh")
  ctrl=true;click(pin(8));ctrl=false;click(row(Q.mapTracker,7).badge)
  expect(selectedCount()==1 and Q:IsSelected("multi:7"),"normal map tracker click replaces a multi-selection")
  ctrl=true;click(pin(3));ctrl=false;WorldMapFrame:Hide();click(row(Q.tracker,10))
  expect(selectedCount()==1 and Q:IsSelected("multi:10"),"normal outside-map tracker click replaces a multi-selection")
  WorldMapFrame:Show();Q:RefreshMap();ctrl=true;click(Q.objectivePins[1])
  expect(selectedCount()==0 and visibleCount(Q.fills)==0 and visibleCount(Q.edges)==0 and visibleCount(Q.objectivePins)==0,"Ctrl-clicking the last selected action icon clears all highlights and map helpers")
  Q:SetEntries(remaining);Q:RefreshMap()
  expect(selectedCount()==0,"an intentionally empty selection survives quest-log updates")
  QuestlineSettings.selectedKeys={};QuestlineSettings.selected=nil;Q:SetEntries(remaining)
  expect(selectedCount()==0,"saved empty selection stays empty when restored")
  ctrl=false;click(pin(8))
  expect(selectedCount()==1 and Q:IsSelected("multi:8"),"normal click restores one highlight from an empty selection")
  Q.tracker.page=3;Q.mapTracker.page=2;Q:RefreshTrackers()
  local clicked=Q.tracker.rows[1].entry.key
  click(Q.tracker.rows[1])
  expect(Q:IsSelected(clicked) and Q.tracker.page==3 and Q.mapTracker.page==2 and Q.tracker.rows[1].entry.key==clicked,"normal tracker click on page three preserves both trackers' pages and row order")
  click(pin(7))
  expect(Q:IsSelected("multi:7") and Q.tracker.page==3 and Q.mapTracker.page==2,"normal map circle click preserves independently browsed tracker pages")
  clicked=Q.mapTracker.rows[1].entry.key;click(Q.mapTracker.rows[1].badge)
  expect(Q:IsSelected(clicked) and Q.mapTracker.page==2 and Q.tracker.page==3,"normal map tracker badge click keeps pagination unchanged")
  IsControlKeyDown=oldControl;QuestlineSettings.selected=oldSelected;QuestlineSettings.selectedKeys=oldKeys
  QuestlineSettings.trackerMode=oldMode
  for _,target in ipairs(targets) do QuestlineDB.locations[target.key]=nil end
  Q:SetEntries(original);Q:RefreshMap();WorldMapFrame:Hide();Q:RefreshTrackers()
end

local function partySyncTests(Q)
  local savedLog,savedSelection,savedParty=log,selection,Q.party
  local oldName,oldCount,oldRaid,oldConnected,oldShared,oldSend,oldMouse=UnitName,GetNumPartyMembers,GetNumRaidMembers,UnitIsConnected,IsUnitOnQuest,SendAddonMessage,MouseIsOver
  local roster={"Alice","Bob"};local connected={Alice=true,Bob=true,Tester=true};local who="Tester";local raid=0
  local sent={};local hovered
  UnitName=function(unit)
    if unit=="player" then return who end
    local _,_,index=string.find(unit,"^party(%d+)$")
    if index then return roster[tonumber(index)] end
    return oldName(unit)
  end
  GetNumPartyMembers=function() return #roster end;GetNumRaidMembers=function() return raid end
  UnitIsConnected=function(unit) return connected[UnitName(unit)] end
  IsUnitOnQuest=function(index,unit)
    local q=visible()[index];assert(q and not q.header,"shared quest lookup used a header or stale log index")
    return q.id==40535 or q.id==426
  end
  SendAddonMessage=function(p,message,channel) table.insert(sent,{prefix=p,message=message,channel=channel,time=now}) end
  MouseIsOver=function(frame) return frame==hovered end
  local function pump(seconds)
    for i=1,math.ceil(seconds/.3) do now=now+.3;Q:UpdatePartySync() end
  end
  local function receive(message,sender,channel,p)
    arg1=p or "QL_P1";arg2=message;arg3=channel or "PARTY";arg4=sender or "Alice";fire("CHAT_MSG_ADDON")
  end
  local function deliver(id,body,sequence,session)
    local messages=Q:PartyPackets(id,body,sequence,session or "alice-one")
    for _,message in ipairs(messages) do receive(message) end
  end
  local function remote(id,objectives,complete)
    return Q:PartyQuestBody({id=id,objectives=objectives,complete=complete})
  end
  local function findLine(text)
    for i=1,GameTooltip:NumLines() do local line=_G["GameTooltipTextLeft"..i];if line:IsShown() and line:GetText()==text then return line end end
  end
  local function hover(name)
    mouseoverName=name;mouseoverPlayer=false;GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");GameTooltip:SetText(name);GameTooltip:AddLine("Level 7");GameTooltip:Show();Q:RefreshMobTooltip()
  end
  local meat=quest(40535,{{text="Leg Meat: 1/2",kind="item"}})
  local mills=quest(426,{{text="Notched Rib: 0/5",kind="item"},{text="Blackened Skull: 1/3",kind="item"}})
  log={{title="Party quests",header=true,closed=true,quests={meat,mills}}};selection=1;Q.party=nil
  fire("PARTY_MEMBERS_CHANGED");Q:ScanLog();pump(3)
  local entry=Q.byKey["40535"]
  expect(entry.partyMembers.Alice and entry.partyMembers.Bob and log[1].closed and selection==1,"native shared-quest checks run against expanded live indices and preserve log state")
  expect(#sent>=4 and sent[1].message:find("^H\t"),"joining a party sends a handshake followed by a quest snapshot")
  for index,message in ipairs(sent) do
    expect(message.prefix=="QL_P1" and message.channel=="PARTY" and #message.prefix+#message.message+1<=254,"wire messages use only the party channel and fit Vanilla's byte limit")
    if index>1 then expect(message.time-sent[index-1].time>=.25,"outgoing packets are throttled") end
  end
  local count=#sent;pump(3);expect(#sent==count,"unchanged quest logs produce no repeated counter traffic")

  -- A second endpoint receives actual emitted packets, using the same runtime.
  local senderState=Q.party;Q.party=nil
  local receiver=setmetatable({quests={},byKey={}}, {__index=Q});receiver:EnsurePartyState();Q.party=senderState
  who="Alice";roster={"Tester"}
  for _,message in ipairs(sent) do receiver:ReceivePartyMessage(message.message,message.channel,"Tester") end
  expect(receiver.party.peers.Tester.quests[40535].objectives['item\tleg meat'].current==1,"a second endpoint reconstructs the sender's quest counters")
  expect(receiver.party.peers.Tester.quests[426].objectives['item\tnotched rib'].required==5,"full snapshot includes every accepted identified quest")
  local queuedBody=receiver:PartyQuestBody({id=40535,objectives={{text="Leg Meat: 0/2",kind="item"}}})
  for _,message in ipairs(receiver:PartyPackets(0,"40535,426",30,senderState.session)) do receiver:ReceivePartyMessage(message,"PARTY","Tester") end
  for _,message in ipairs(receiver:PartyPackets(40535,queuedBody,29,senderState.session)) do receiver:ReceivePartyMessage(message,"PARTY","Tester") end
  expect(receiver.party.peers.Tester.quests[40535].objectives['item\tleg meat'].current==0,"a newer manifest does not discard an older queued update for an included quest")
  who="Tester";roster={"Alice","Bob"};Q:RefreshPartyRoster()

  local body=remote(40535,{{text="Leg Meat: 0/2",kind="item"}})
  receive("H\talice-one");deliver(0,"40535,426",1);deliver(40535,body,2)
  hover("Adult Plainstrider")
  expect(findLine("  Leg Meat (10%)") and findLine("    You: 1/2") and findLine("    Alice: 0/2"),"mob tooltip groups local and synchronized party counts beneath its item and drop rate")
  local savedColors=RAID_CLASS_COLORS
  RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
  Q:RefreshMobTooltip()
  expect(findLine("    |cffc79c6eAlice|r: 0/2"),"only a synchronized party member's name receives the native class color")
  local classLines=Q:PartyStatusLines(entry,"")
  expect(classLines[1].text=="|cffc79c6eAlice|r: In progress","overall party status uses the same class-colored name")
  RAID_CLASS_COLORS={};Q:RefreshMobTooltip()
  expect(findLine("    Alice: 0/2"),"unknown class colors fall back to a plain member name")
  RAID_CLASS_COLORS=savedColors
  expect(not findLine("    Bob: On this quest; progress unavailable"),"non-addon members are omitted from the tooltip")
  local lines=GameTooltip:NumLines();Q:RefreshMobTooltip();expect(GameTooltip:NumLines()==lines,"party progress refresh does not duplicate tooltip lines")
  deliver(40535,remote(40535,{{text="Leg Meat: 2/2",kind="item",done=true}},true),3);Q:RefreshMobTooltip()
  local completeLine=findLine("    Alice: 2/2")
  expect(completeLine and completeLine.color[2]>completeLine.color[1],"remote completed objectives show full counts in green while still hovering")
  mouseoverName=nil;GameTooltip:FadeOut();local shows=GameTooltip.showCalls;Q:RefreshMobTooltip()
  expect(findLine("    Alice: 2/2") and GameTooltip.fading and GameTooltip.showCalls==shows,"party details persist through the existing unit-tooltip fade")

  local long=string.rep("Explore this 100% place ",15)
  local multibody=remote(426,{{text="Blackened Skull: 3/3",kind="item",done=true},{text="Notched Rib: 4/5",kind="item"},{text=long,kind="event"}})
  local packets=Q:PartyPackets(426,multibody,4,"alice-one")
  expect(#packets>1,"long objective text is split into bounded packets")
  receive(packets[#packets]);expect(not Q.party.peers.Alice.quests[426],"partial quest update never exposes incomplete counters")
  for i=#packets-1,1,-1 do receive(packets[i]) end
  local sharedLines=Q:PartyObjectiveLines(Q.byKey['426'],1,"Notched Rib - 0/5",false,"")
  expect(sharedLines[3].text=="  Alice: 4/5","objectives match by type and text even when the other player's objective order differs")
  expect(Q.party.peers.Alice.quests[426].objectives['event\t'..Q:Normalize(long)],"escaped percent signs survive fragmented transport")
  local interrupted=Q:PartyPackets(426,multibody,5,"alice-one")
  receive(interrupted[1]);receive(interrupted[1])
  expect(Q.party.peers.Alice.pending[426].count==1,"duplicate fragments do not advance incomplete records")
  pump(16)
  expect(not Q.party.peers.Alice.pending[426] and Q.party.peers.Alice.revisions[426]==4,"interrupted fragments expire without replacing the last complete record")
  for _,message in ipairs(interrupted) do receive(message) end
  expect(Q.party.peers.Alice.revisions[426]==5,"a complete resend repairs an interrupted record")
  local oldQuest=Q.party.peers.Alice.quests[40535]
  receive(Q:PartyPackets(40535,body,2,"alice-one")[1]);expect(Q.party.peers.Alice.quests[40535]==oldQuest,"out-of-order older updates cannot replace newer progress")
  receive("D\tbogus\t0\t40535\t1\t99\tx")
  expect(Q.party.peers.Alice.session=="alice-one" and Q.party.peers.Alice.quests[40535]==oldQuest,"malformed headers cannot reset a valid peer session")
  local message=Q:PartyPackets(40535,body,5,"alice-one")[1]
  receive(message,"Stranger");receive(message,"Alice","RAID");receive(message,"Alice","PARTY","AnotherAddon")
  expect(not Q.party.peers.Stranger and Q.party.peers.Alice.quests[40535]==oldQuest,"non-members, non-party channels and other prefixes are ignored")
  expect(not Q:ParsePartyQuest("A\nitem\tfoo\tbad\t2\t1") and not Q:ParsePartyQuest("A\nitem\tfoo\t1\t0\t1"),"invalid counters and zero required counts are rejected")
  local duplicate=Q:ParsePartyQuest("A\nitem\tfoo\t1\t2\t0\nitem\tfoo\t2\t2\t1")
  expect(duplicate and duplicate.objectives['item\tfoo']==false,"ambiguous duplicate objective labels are not matched by position")
  deliver(40535,remote(40535,{{text="Leg Meat: 1/3",kind="item"}}),6)
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"different required counts are not presented as matching objectives")
  deliver(40535,body,7);now=now+91
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"expired counters quietly return to the compact local objective")
  deliver(40535,body,8)
  expect(Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")[3].text=="  Alice: 0/2","a fresh synchronization restores current counters")
  connected.Alice=false;Q:RefreshPartyRoster()
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"disconnected members do not add placeholder rows")
  connected.Alice=true;Q:RefreshPartyRoster()
  expect(#Q:PartyObjectiveLines(entry,1,"Leg Meat - 1/2",false,"")==1,"reconnecting does not revive counters from before disconnect")
  deliver(0,"40535,426",10);deliver(40535,body,11)
  deliver(0,"426",12)
  local members=Q:GetPartyQuestMembers(entry)
  expect(#members==0,"remote removal clears a quest even while native membership still reports it shared")
  deliver(40535,body,11);expect(not Q.party.peers.Alice.quests[40535],"old packets cannot resurrect a quest after its removal manifest")
  receive("H\talice-two");deliver(40535,remote(40535,{{text="Leg Meat: 2/2",kind="item",done=true}},true),1,"alice-two")
  expect(Q.party.peers.Alice.quests[40535].status=="C","addon reload begins a new session with fresh sequence numbers")
  deliver(40535,body,500,"alice-one")
  expect(Q.party.peers.Alice.session=="alice-two" and Q.party.peers.Alice.quests[40535].status=="C","late packets from a retired session are ignored")

  WorldMapFrame:Hide();GameTooltip:Hide();hovered=Q.tracker.rows[1]
  Q:ShowQuestTooltip(hovered,entry)
  expect(findLine("  Alice: 2/2") and findLine("  You: 1/2"),"tracker quest tooltip also shows synchronized objective counts")
  deliver(40535,body,2,"alice-two");pump(1.2)
  expect(findLine("  Alice: 0/2"),"party changes refresh an actively hovered tracker tooltip")
  hovered=nil;entry.complete=true;Q:ShowQuestTooltip(Q.tracker.rows[1],entry)
  expect(findLine("  Alice: In progress") and findLine("Party"),"turn-in tooltip shows other members' overall quest status")
  entry.complete=false;GameTooltip:Hide()

  sent={};Q.party.force=false;Q.party.fullAt=now+60;Q.party.outbox={};Q.party.order={};Q.party.hello=false
  meat.objectives[1].text="Leg Meat: 2/2";Q:ScanLog();Q:BuildPartyOutbox()
  meat.objectives[1].text="Leg Meat: 1/2";Q:ScanLog();Q:BuildPartyOutbox();pump(2)
  expect(#sent==1 and sent[1].message:find("\t40535\t",1,true),"rapid objective changes coalesce into one current quest update without resending unrelated quests")
  sent={};now=Q.party.fullAt+.1;Q:UpdatePartySync();pump(3)
  expect(#sent>=3,"periodic snapshots repair missed packets and renew freshness")
  log[1].quests={meat};Q:ScanLog();sent={};pump(2)
  expect(#sent>=1 and sent[1].message:find("\t0\t",1,true),"abandoning a local quest sends a new manifest")
  roster={"Bob"};Q:RefreshPartyRoster();expect(not Q.party.peers.Alice,"leaving party immediately discards that member's remote data")
  roster={};fire("PARTY_MEMBERS_CHANGED");sent={};pump(2)
  expect(#sent==0 and not next(Q.party.peers) and #Q.party.order==0,"solo play clears remote state and queued traffic")
  roster={"Alice"};raid=10;Q:RefreshPartyRoster();pump(1)
  expect(#Q.party.members==0 and #sent==0,"party synchronization does not broadcast into raid groups")
  UnitName=oldName;GetNumPartyMembers=oldCount;GetNumRaidMembers=oldRaid;UnitIsConnected=oldConnected;IsUnitOnQuest=oldShared;SendAddonMessage=oldSend;MouseIsOver=oldMouse
  Q.party=savedParty;Q.partyQuestTooltip=nil;log=savedLog;selection=savedSelection;Q:ScanLog();mouseoverName=nil;GameTooltip:Hide()
end

-- Files are loaded by the JS harness between the stub setup and test body.
function runTests()
  local q844=quest(844,{{text="Plainstrider Beak: 0/7",kind="item"}})
  local q845=quest(845,{{text="Zhevra Hooves: 0/4",kind="item"}})
  local q895=quest(895,{{text="Baron Longshore's Head: 0/1",kind="item"}})
  local q900=quest(900,{{text="Shut off Main Control Valve: 0/1",kind="object"}})
  log={{title="The Barrens",header=true,closed=true,quests={q844,q845,q895,q900}},{title="Durotar",header=true,quests={quest(869,{},1)}}}
  selection=3 -- second header's quest in the collapsed view
  playerZone="Mulgore";fire("PLAYER_LOGIN");tick(.2)
  local Q=Questline
  expect(Q.ready,"login initialized")
  expect(QuestlineSettings.trackerMode=="zone" and Q.tracker.heading:GetText()=="Quests - Mulgore","fresh characters start with their physical zone")
  playerZone="The Barrens";fire("ZONE_CHANGED_NEW_AREA")
  expect(#Q.quests==5,"collapsed headers included")
  expect(log[1].closed,"header collapse restored")
  expect(selection==3,"quest selection restored")
  expect(Q.byKey["900"]~=nil,"duplicate-title chain identified by quest text")
  expect(Q.byKey["844"]~=nil,"normal title resolved without GetQuestLink")
  expect(Q.byKey["869"].complete,"complete quest recognized")
  expect(not QuestWatchFrame:IsShown(),"legacy tracker suppressed")

  WorldMapFrame:Show();tick(.2);Q:Select("844")
  local visibleFills=0;for _,fill in ipairs(Q.fills) do if fill:IsShown() then visibleFills=visibleFills+1 end end
  expect(visibleFills>0,"Barrens area rendered")
  expect(#Q.mapPins>1,"clickable numbered markers created")
  expect(Q.mapPins[1].glow:IsShown() and not Q.mapPins[2].glow:IsShown(),"only selected quest badge glows")
  expect(Q.mapPins[1].texture.textureValue[1]:find("circle%-selected%-v2"),"selected badge uses gold-filled texture")
  expect(Q.mapPins[1].text.point[1]=="CENTER" and Q.mapPins[1].text.point[4]<Q.mapPins[2].text.point[4],"standalone 1 gets extra optical correction without shifting other numerals")
  click(Q.mapPins[2]);expect(QuestlineSettings.selected==Q.mapPins[2].entry.key,"map click changes shared selection")
  click(Q.mapTracker.rows[1].badge);expect(QuestlineSettings.selected==Q.mapTracker.rows[1].entry.key,"tracker circle changes selection")

  Q:Select("895")
  for _,fill in ipairs(Q.fills) do expect(not fill:IsShown(),"single target clears previous area") end
  expect(Q.objectivePins[1]:IsShown(),"single target action icon visible")
  expect(Q.objectivePins[1].point[4]~=Q.mapPins[3].point[4],"selector does not cover action icon")
  Q:Select("869")
  local completedPin
  for _,pin in ipairs(Q.mapPins) do if pin.entry.id==869 then completedPin=pin end end
  expect(completedPin and completedPin.text:GetText()=="?","completed quest gets question mark")
  for _,pin in ipairs(Q.objectivePins) do expect(not pin:IsShown(),"completed quest has only turn-in selectors") end
  SetMapZoom(1,0);Q.mapDirty=true;Q:RefreshMap()
  for _,pin in ipairs(Q.mapPins) do expect(not pin:IsShown(),"continent map clears pins") end
  SetMapZoom(1,1);Q.mapDirty=true;Q:RefreshMap()
  WorldMapButton.scale=4;Q:RefreshMap()
  expect(Q.mapPins[1]:GetWidth()==6.25,"Magnify zoom keeps map markers a constant screen size")
  expect(Q.mapPins[1].glow:GetWidth()==9.75,"Magnify zoom keeps halo a constant screen size")
  expect(Q.mapPins[1].text.point[4]==-1.3/4,"standalone 1 correction scales with map zoom")
  WorldMapButton.scale=1;Q:RefreshMap()

  -- Only the selected quest's unfinished target contributes shading.
  local target=QuestlineDB.quests[844].objectives[1]
  local e=Q.byKey["844"]
  e.objectives={{text=target.name..": 7/7",kind="item",done=true}}
  expect(#Q:Targets(e)==0,"finished item objectives excluded")
  e.failed=true;expect(#Q:Targets(e)==0,"failed quest has no objectives")
  e.failed=false
  local data=QuestlineDB.quests[844]
  QuestlineDB.quests[999991]=data
  table.insert(Q.titleIndex[Q:Normalize(data.title)],999991)
  expect(Q:ResolveQuest(1,data.title,data.level,data.description,data.summary)==nil,"ambiguous matches are not guessed")
  table.remove(Q.titleIndex[Q:Normalize(data.title)]);QuestlineDB.quests[999991]=nil
  GetQuestLink=function() return "|Hquest:999992:12|h[Plainstrider Menace]|h" end
  expect(Q:ResolveQuest(1,data.title,data.level,data.description,data.summary)==nil,"unknown explicit ID does not match different ID")
  GetQuestLink=nil
  q844.complete=-1;now=now+1;Q:ScanLog();expect(Q.byKey["844"].failed and not Q.byKey["844"].complete,"negative completion means failed")

  local rows=Q:AreaRows({target,target},17)
  local rectangles=Q:AreaRectangles(rows)
  expect(#rectangles>0,"scanlines unioned into rectangles")
  local corners=Q:ContourPatches({[10]={{10,11}}})
  local masks={};for _,p in ipairs(corners) do masks[p[5]]=true end
  expect(#corners==4 and masks[1] and masks[2] and masks[4] and masks[8],"single-cell contour uses four rounded corners")
  local solidRows={};for y=10,19 do solidRows[y]={{10,20}} end
  local compact=Q:ContourPatches(solidRows)
  expect(#compact==9,"solid rectangle compresses to one interior plus eight border pieces")
  local areaA=Q:ContourPatches(Q:AreaRows({target},17))
  local areaB=Q:ContourPatches(Q:AreaRows({target,target},17))
  expect(#areaA==#areaB,"overlapping objectives do not duplicate contour tiles")
  for i,p in ipairs(areaA) do for k=1,5 do assert(p[k]==areaB[i][k],"overlap changed tile") end end
  Q:DrawAreas({target},17,1002,668)
  for _,edge in ipairs(Q.edges) do if edge:IsShown() then
    assert(edge.textureValue[1]:find("area%-contours"),"edge is a contour tile")
    assert(edge.texCoords[1]>=0 and edge.texCoords[2]<=1 and edge.texCoords[3]>=0 and edge.texCoords[4]<=1,"atlas coordinates out of range")
    assert(edge.point[4]>=0 and edge.point[5]<=0,"area extends beyond map origin")
  end end
  for y,spans in pairs(rows) do for i=2,#spans do expect(spans[i][1]>spans[i-1][2],"scanline intervals never overlap") end end
  local before=#widgets;Q:Select("845");local highwater=#widgets;Q.mapDirty=true;Q:RefreshMap();expect(#widgets==highwater,"unchanged geometry reuses UI objects")
  expect(Q.fills[1]:IsShown(),"cached area remains visible after an unchanged map refresh")
  expect(highwater>=before,"pool growth bounded by new area")
  Q:Command("tracker off");expect(QuestWatchFrame:IsShown(),"old tracker restored")

  -- pfQuest pins: existing/future nodes, explicit restore, no saved config writes.
  Q.minimapBlipsApplied=nil
  Q:ApplyCompatibility()
  expect(not Q.minimapBlipsApplied,"clients without SetBlipTexture remain supported")
  local blipCalls=0
  Minimap.SetBlipTexture=function(self,texture)
    blipCalls=blipCalls+1
    expect(texture=="Interface\\AddOns\\Questline\\Textures\\minimap-blips","native atlas replaced with turn-in-free texture")
  end
  Q:ApplyCompatibility();Q:ApplyCompatibility()
  expect(blipCalls==1,"native atlas applied once without repeated overrides")
  Minimap.SetBlipTexture=nil
  pfQuest_config={showspawn="1"}
  pfMap={pins={CreateFrame("Button",nil,WorldMapButton)}}
  function pfMap:BuildNode(name,parent) local pin=CreateFrame("Button",name,parent);return pin end
  function pfMap:UpdateNodes() for _,pin in ipairs(self.pins) do pin:Show() end end
  Q:ApplyCompatibility();expect(not pfMap.pins[1]:IsShown(),"existing pfQuest pin hidden")
  local newpin=pfMap:BuildNode(nil,WorldMapButton);newpin:Show();expect(not newpin:IsShown(),"future pfQuest pin hidden")
  Q:Command("legacy on");expect(pfMap.pins[1]:IsShown(),"legacy pins restored")
  expect(pfQuest_config.showspawn=="1","pfQuest saved setting unchanged")
  QuestlineSettings.trackerPosition={x=30,y=500};QuestlineSettings.mapPosition=nil
  Q:PositionTrackers();expect(Q.mapTracker.point[1]=="TOPRIGHT","HUD position is not reused for unset map position")
  -- Real progress arriving during synthetic header events is eventually refreshed.
  q844.complete=1;now=now+6;tick(.2)
  expect(Q.byKey["844"].complete,"collapsed-header fallback refresh catches completion")
  Q:Command("tracker on");trackerModeTests(Q)
  mobTooltipTests(Q)
  trackerClickTests(Q)
  npcQuestTests(Q)
  giverMapTests(Q)
  giverClusterTests(Q)
  questLevelAndRateTests(Q)
  partySyncTests(Q)
  multiSelectionTests(Q)
  trackerResizeTests(Q)
  trackerMapTests(Q)
  completionHistoryTests(Q)
  Q:SetTrackerMode("world");Q.titleIndex={};fire("PLAYER_LOGIN");tick(.2)
  expect(QuestlineSettings.trackerMode=="world","login preserves an existing saved World preference")
  print("Runtime: "..checks.." assertions passed.")
end
