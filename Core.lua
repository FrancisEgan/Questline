-- Questline 0.1: original Vanilla (Lua 5.0) client, English quest text.
Questline = { version = "0.1.19", quests = {}, byKey = {}, titleIndex = {}, dirty = true }
local Q, DB = Questline, QuestlineDB
local getn, insert = table.getn, table.insert
local raceBits = { Human=1, Orc=2, Dwarf=4, NightElf=8, Scourge=16, Undead=16, Tauren=32, Gnome=64, Troll=128, Goblin=256, BloodElf=512 }
local classBits = { WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024 }
local function present(value) return value == true or value == 1 end
function Q:Print(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff8cccffQuestline:|r " .. message) end
end
function Q:Normalize(text)
  text = string.lower(text or "")
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "%s+", " ")
  text = string.gsub(text, "^%s*(.-)%s*$", "%1")
  return text
end
function Q:ExpandText(text)
  local name = UnitName("player") or ""
  local class = UnitClass("player") or ""
  local race = UnitRace("player") or ""
  text = string.gsub(text or "", "$[Nn]", function() return name end)
  text = string.gsub(text, "$[Cc]", function() return string.lower(class) end)
  text = string.gsub(text, "$[Rr]", function() return string.lower(race) end)
  text = string.gsub(text, "$[Bb]", " ")
  text = string.gsub(text, "$[Gg]([^:]*):([^;]*);", function(male, female)
    if UnitSex and UnitSex("player") == 3 then return female end
    return male
  end)
  return text
end
function Q:MaskAllows(mask, flag)
  if not mask or mask == 0 or not flag then return true end
  return math.mod(math.floor(mask / flag), 2) == 1
end
function Q:MeetsQuestRestrictions(data)
  local _,race=UnitRace("player");local _,class=UnitClass("player")
  return self:MaskAllows(data.raceMask,raceBits[race]) and self:MaskAllows(data.classMask,classBits[class])
    and (UnitLevel("player") or 0)>=(data.minLevel or 0)
end
function Q:QuestLevel(entry)
  local level=tonumber(entry.level or (entry.data and entry.data.level))
  if level and level>0 then return level end
end
function Q:SortQuests(entries)
  local order={}
  for index,entry in ipairs(entries) do order[entry]=index end
  table.sort(entries,function(a,b)
    local al,bl=Q:QuestLevel(a) or 10000,Q:QuestLevel(b) or 10000
    if al~=bl then return al<bl end
    return order[a]<order[b]
  end)
end
function Q:QuestTitle(entry)
  local level=self:QuestLevel(entry)
  if not level then return entry.title end
  local difficulty=GetQuestDifficultyColor or GetDifficultyColor
  local color=difficulty and difficulty(level)
  if not color then
    local difference=level-UnitLevel("player")
    if difference>=5 then color={r=1,g=.1,b=.1}
    elseif difference>=3 then color={r=1,g=.5,b=.25}
    elseif difference>=-2 then color={r=1,g=1,b=0}
    elseif difference>=-(GetQuestGreenRange and GetQuestGreenRange() or 5) then color={r=.25,g=.75,b=.25}
    else color={r=.5,g=.5,b=.5} end
  end
  -- Only the number is difficulty-colored. Reset before the bracket and title
  -- so each label keeps its usual gold/off-white text color.
  return "["..string.format("|cff%02x%02x%02x%d|r",math.floor(color.r*255),math.floor(color.g*255),math.floor(color.b*255),level).."] "..entry.title
end
function Q:BuildIndexes()
  for id, data in pairs(DB.quests) do
    local title = self:Normalize(data.title)
    self.titleIndex[title] = self.titleIndex[title] or {}
    insert(self.titleIndex[title], id)
  end
  self.zoneNames = {}
  for id, zone in pairs(DB.zones) do
    local key = self:Normalize(zone.name)
    local old = self.zoneNames[key]
    if not old or zone.coordinateCount > DB.zones[old].coordinateCount
      or (zone.coordinateCount == DB.zones[old].coordinateCount and id < old) then self.zoneNames[key] = id end
  end
end
function Q:ResolveQuest(index, title, level, description, summary)
  if GetQuestLink then
    local ok, link = pcall(GetQuestLink, index)
    if ok and link then
      local _, _, id = string.find(link, "quest:(%d+)")
      id = tonumber(id)
      if id then
        if DB.quests[id] then return id end
        return nil, "unknown-id"
      end
    end
  end
  local candidates = self.titleIndex[self:Normalize(title)] or {}
  local _, race = UnitRace("player")
  local _, class = UnitClass("player")
  local best, score, tied = nil, -1, false
  for _, id in ipairs(candidates) do
    local data = DB.quests[id]
    if self:MaskAllows(data.raceMask, raceBits[race]) and self:MaskAllows(data.classMask, classBits[class]) then
      local rank = 0
      if data.level == level then rank = rank + 4 end
      if summary and summary ~= "" and self:Normalize(self:ExpandText(data.summary)) == self:Normalize(summary) then rank = rank + 16 end
      if description and description ~= "" and self:Normalize(self:ExpandText(data.description)) == self:Normalize(description) then rank = rank + 32 end
      if rank > score then best, score, tied = id, rank, false elseif rank == score then tied = true end
    end
  end
  if not tied then return best end
  return nil, "ambiguous"
end
function Q:ObjectiveDone(entry, target)
  if entry.complete then return true end
  local name = self:Normalize(target.name)
  if name == "" then return false end
  -- Match names, not array positions: pfQuest groups targets by type, not log order.
  local found, allDone = false, true
  for _, objective in ipairs(entry.objectives) do
    local text = self:Normalize(objective.text)
    text = string.gsub(text, ":%s*%d+%s*/%s*%d+.*$", "")
    text = string.gsub(text, "%s+slain$", "")
    text = string.gsub(text, "%s+killed$", "")
    if text == name then
      found = true
      if not objective.done then allDone = false end
    end
  end
  return found and allDone
end
function Q:Targets(entry)
  local result = {}
  if not entry.data or entry.failed then return result end
  if entry.complete then return entry.data.finishers end
  for _, target in ipairs(entry.data.objectives) do
    if not self:ObjectiveDone(entry, target) then insert(result, target) end
  end
  return result
end
function Q:HasZone(entry, zone)
  if not zone then return false end
  for _, target in ipairs(self:Targets(entry)) do
    if DB.locations[target.key] and DB.locations[target.key][zone] then return true end
  end
  return false
end
function Q:HasLocations(entry)
  for _,target in ipairs(self:Targets(entry)) do
    if DB.locations[target.key] and next(DB.locations[target.key]) then return true end
  end
  return false
end
function Q:GetMapZone()
  local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
  if not continent or continent <= 0 or not zone or zone <= 0 then return nil end
  self.mapNames = self.mapNames or {}
  if not self.mapNames[continent] then self.mapNames[continent] = { GetMapZones(continent) } end
  return self.zoneNames[self:Normalize(self.mapNames[continent][zone])]
end
function Q:GetPlayerZone()
  -- The physical zone stays valid while the player browses a different map.
  local name=GetRealZoneText and GetRealZoneText()
  if not name or name=="" then name=GetZoneText and GetZoneText() end
  if not name or name=="" then return nil,"Zone" end
  return self.zoneNames[self:Normalize(name)],name
end
function Q:GetTrackerEntries()
  local zone,name=self:GetPlayerZone()
  local entries={}
  for _,entry in ipairs(self.quests) do
    if QuestlineSettings.trackerMode~="zone" or self:HasZone(entry,zone) then insert(entries,entry) end
  end
  return self:PrioritizeSelected(entries),zone,name
end
function Q:IsSelected(key)
  -- A missing set preserves the single-selection settings of older versions.
  if type(QuestlineSettings.selectedKeys)=="table" then return QuestlineSettings.selectedKeys[key]==true end
  return QuestlineSettings.selected==key
end
function Q:PrioritizeSelected(entries)
  if type(QuestlineSettings.selectedKeys)~="table" then return entries end
  -- Input is already in level order. Keep quest numbers stable while moving
  -- highlighted entries to the front of each filtered tracker.
  local result={}
  for _,entry in ipairs(entries) do if self:IsSelected(entry.key) then insert(result,entry) end end
  for _,entry in ipairs(entries) do if not self:IsSelected(entry.key) then insert(result,entry) end end
  return result
end
function Q:SetTrackerMode(mode)
  QuestlineSettings.trackerMode=mode=="zone" and "zone" or "world"
  if self.tracker then self.tracker.page=1 end
  self:RefreshTrackers()
end
function Q:Select(key,toggle)
  if not self.byKey[key] then return end
  if toggle then
    if type(QuestlineSettings.selectedKeys)~="table" then
      QuestlineSettings.selectedKeys={}
      if self.byKey[QuestlineSettings.selected] then QuestlineSettings.selectedKeys[QuestlineSettings.selected]=true end
    end
    local selected=QuestlineSettings.selectedKeys
    if selected[key] then selected[key]=nil else selected[key]=true end
    QuestlineSettings.selected=nil
    for _,entry in ipairs(self.quests) do
      if selected[entry.key] then QuestlineSettings.selected=entry.key;break end
    end
  else
    QuestlineSettings.selectedKeys=nil
    QuestlineSettings.selected=key
  end
  if toggle then
    if self.tracker then self.tracker.page=1 end
    if self.mapTracker then self.mapTracker.page=1 end
  end
  -- Rows may move under the cursor; do not retain the previous row's tooltip.
  self.partyQuestTooltip=nil;GameTooltip:Hide();WorldMapTooltip:Hide()
  self.mapDirty = true
  if self.RefreshTrackers then self:RefreshTrackers() end
  if self.RefreshMap then self:RefreshMap() end
end
function Q:ReadQuest(index, title, level, complete)
  SelectQuestLogEntry(index)
  local description, summary = GetQuestLogQuestText()
  local id, reason = self:ResolveQuest(index, title, level, description, summary)
  local data = id and DB.quests[id]
  local entry = { id=id, data=data, title=title, level=level, objectives={}, summary=summary or "", description=description or "", reason=reason,
    complete=present(complete), failed=complete == -1 }
  entry.key = id and tostring(id) or (title .. ":" .. tostring(level) .. ":" .. (summary or ""))
  local count = GetNumQuestLeaderBoards(index) or 0
  for objective = 1, count do
    local text, kind, done = GetQuestLogLeaderBoard(objective, index)
    insert(entry.objectives, { text=text or "", kind=kind, done=present(done) })
  end
  local money = GetQuestLogRequiredMoney and GetQuestLogRequiredMoney() or 0
  if money and money > 0 and GetMoney and GetMoney() < money then
    entry.complete = false
    insert(entry.objectives, {text="Required money: " .. math.floor(money / 100) .. " silver", done=false})
  elseif not entry.failed and count == 0 and data and getn(data.objectives) == 0 then
    -- Delivery quests do not always set isComplete in Vanilla. Exploration does not qualify.
    entry.complete = true
  end
  if self.ReadPartyQuestMembership then self:ReadPartyQuestMembership(index,entry) end
  return entry
end
local function questLink(index)
  -- Octo's SuperAPI uses this first function for Blizzard quest-log chat links.
  if GetQuestLinkForLogIndex then
    local ok,link=pcall(GetQuestLinkForLogIndex,index)
    if ok and type(link)=="string" and link~="" then return link end
  end
  if GetQuestLink then
    local ok,link=pcall(GetQuestLink,index)
    if ok and type(link)=="string" and link~="" then return link end
  end
end
function Q:QuestLogAction(entry,open)
  local chat=ChatFrameEditBox
  if not open and (not chat or not chat:IsVisible()) then return end
  -- Never retain a numeric log index: headers and accepted/abandoned quests move it.
  local selection,scanning=GetQuestLogSelection(),self.scanning
  self.scanning=true
  local collapsed,index,header,found,matches={},1,nil,nil,0
  local titleAPI=CT_QuestLevels_oldGetQuestLogTitle or GetQuestLogTitle
  while index<=GetNumQuestLogEntries() do
    local title,level,tag,isHeader,closed,complete=titleAPI(index)
    if isHeader then
      header=index
      if closed then insert(collapsed,index);ExpandQuestHeader(index) end
    elseif title==entry.title and level==entry.level then
      local candidate=self:ReadQuest(index,title,level,complete)
      if candidate.key==entry.key and (entry.id or candidate.description==entry.description) then
        matches=matches+1;found={index=index,header=header,link=not open and questLink(index)}
      end
    end
    index=index+1
  end
  for i=getn(collapsed),1,-1 do
    local collapsedIndex=collapsed[i]
    if not (open and matches==1 and found.header==collapsedIndex) then
      local before=GetNumQuestLogEntries()
      CollapseQuestHeader(collapsedIndex)
      if found and found.index>collapsedIndex then found.index=found.index-(before-GetNumQuestLogEntries()) end
    end
  end
  if open and matches==1 then SelectQuestLogEntry(found.index)
  elseif selection and selection>0 then SelectQuestLogEntry(selection) end
  self.scanning=scanning
  if getn(collapsed)>0 then self.ignoreLogUntil=GetTime()+0.3;self.rescanAt=GetTime()+5 end
  if matches~=1 then
    self.dirty=true
    self:Print(matches==0 and "That quest is no longer in your quest log." or "Could not uniquely identify that quest-log entry.")
    return
  end
  if open then
    if WorldMapFrame:IsVisible() then HideUIPanel(WorldMapFrame) end
    ShowUIPanel(QuestLogFrame)
    QuestLog_Update()
    if QuestLogListScrollFrameScrollBar then
      local offset=math.max(0,math.min(found.index-1,GetNumQuestLogEntries()-(QUESTS_DISPLAYED or 6)))
      QuestLogListScrollFrameScrollBar:SetValue(offset*(QUESTLOG_QUEST_HEIGHT or 16))
    end
    QuestLog_SetSelection(found.index);QuestLog_Update()
    self:RefreshTrackers()
  else
    if found.link then chat:Insert(found.link)
    elseif pfQuestCompat and pfQuestCompat.InsertQuestLink then pfQuestCompat.InsertQuestLink(entry.id,entry.title)
    else chat:Insert("["..entry.title.."]") end
    chat:SetFocus()
  end
end
function Q:TrackerClick(entry,button)
  if not entry then return end
  if button=="RightButton" then
    GameTooltip:Hide();WorldMapTooltip:Hide();self:QuestLogAction(entry,true)
  elseif IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
    self:QuestLogAction(entry,false)
  else self:Select(entry.key,IsControlKeyDown and IsControlKeyDown()) end
end
function Q:ScanLog()
  if self.scanning then return end
  self.scanning = true
  local selection = GetQuestLogSelection()
  local collapsed, entries = {}, {}
  local titleAPI = CT_QuestLevels_oldGetQuestLogTitle or GetQuestLogTitle
  local index = 1
  -- Expand only while taking the snapshot; restore headers and the user's selection.
  while index <= GetNumQuestLogEntries() do
    local title, level, tag, header, closed, complete = titleAPI(index)
    if header and closed then
      insert(collapsed, index)
      ExpandQuestHeader(index)
    elseif title and not header then insert(entries, self:ReadQuest(index, title, level, complete)) end
    index = index + 1
  end
  for i=getn(collapsed),1,-1 do CollapseQuestHeader(collapsed[i]) end
  if selection and selection > 0 then SelectQuestLogEntry(selection) end
  self.scanning = false
  if getn(collapsed) > 0 then self.ignoreLogUntil = GetTime() + 0.3 end
  self.rescanAt = getn(collapsed) > 0 and GetTime() + 5 or nil
  self:SetEntries(entries)
end
function Q:SetEntries(entries)
  self:SortQuests(entries)
  self.quests, self.byKey = entries, {}
  for i, entry in ipairs(entries) do entry.number=i; self.byKey[entry.key]=entry end
  if self.BuildTooltipProgress then self:BuildTooltipProgress() end
  if self.UpdateNPCQuestState then self:UpdateNPCQuestState() end
  if self.party then self.party.dirty=true end
  if type(QuestlineSettings.selectedKeys)=="table" then
    local selected=QuestlineSettings.selectedKeys
    for key,value in pairs(selected) do if value~=true or not self.byKey[key] then selected[key]=nil end end
    QuestlineSettings.selected=nil
    for _,entry in ipairs(entries) do if selected[entry.key] then QuestlineSettings.selected=entry.key;break end end
  elseif not self.byKey[QuestlineSettings.selected] then QuestlineSettings.selected = entries[1] and entries[1].key end
  self.mapDirty = true
  if self.RefreshTrackers then self:RefreshTrackers() end
end
function Q:Command(message)
  local _,_,command,option=string.find(self:Normalize(message),"^(%S*)%s*(.-)$")
  if command=="tracker" then QuestlineSettings.tracker=option~="off"; self:RefreshTrackers(); self:ApplyCompatibility()
  elseif command=="legacy" then QuestlineSettings.legacy=option=="on"; self:ApplyCompatibility(); self:Print("pfQuest map pins " .. (QuestlineSettings.legacy and "shown." or "hidden."))
  elseif command=="reset" then
    QuestlineSettings.trackerPosition=nil; QuestlineSettings.mapPosition=nil; QuestlineSettings.collapsed=false; QuestlineSettings.mapCollapsed=false
    self:PositionTrackers(); self:RefreshTrackers()
  elseif command=="status" then
    local known=0;for _,q in ipairs(self.quests) do if q.id then known=known+1 end end
    self:Print("v"..self.version.." | "..DB.profile.." | "..known.."/"..getn(self.quests).." quests identified | build "..DB.build)
  else self:Print("/ql tracker on|off, /ql legacy on|off, /ql reset, /ql status. Click a quest to highlight it; Ctrl-click to add or remove highlights. In either tracker, Shift-click to link in open chat; right-click to open the quest log. Drag a tracker header to move it; use the arrows or mouse wheel to change pages.") end
end

local events=CreateFrame("Frame", "QuestlineEvents")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_UPDATE")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("WORLD_MAP_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:SetScript("OnEvent",function()
  if event=="PLAYER_LOGIN" or (event=="PLAYER_ENTERING_WORLD" and not Q.ready) then
    QuestlineSettings=QuestlineSettings or {}
    if QuestlineSettings.tracker==nil then QuestlineSettings.tracker=true end
    if QuestlineSettings.trackerMode~="zone" and QuestlineSettings.trackerMode~="world" then QuestlineSettings.trackerMode="zone" end
    Q:BuildIndexes();Q:CreateTrackers();Q:CreateMap();Q.ready=true;Q.dirty=true
    Q:InitializeNPCQuests()
    Q:ApplyCompatibility()
    Q:Print("Loaded. /ql shows commands.")
  elseif event=="WORLD_MAP_UPDATE" then Q.mapDirty=true
  elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" then
    Q.minimapDiameterKey=nil
    if Q.ready then Q:RefreshTrackers() end
  elseif event=="PLAYER_ENTERING_WORLD" then
    Q.minimapDiameterKey=nil
    Q.dirty=true
    if Q.ready then Q:RefreshTrackers() end
  elseif not Q.scanning and (not Q.ignoreLogUntil or GetTime()>Q.ignoreLogUntil) then Q.dirty=true end
end)
events:SetScript("OnUpdate",function()
  if not Q.ready then return end
  Q.elapsed=(Q.elapsed or 0)+(arg1 or 0)
  if Q.elapsed<0.15 then return end
  Q.elapsed=0
  -- Header expansion generates log events; this fallback catches a real change
  -- arriving during the short suppression window without creating an event loop.
  if Q.rescanAt and GetTime()>=Q.rescanAt then Q.rescanAt=nil;Q.dirty=true end
  if Q.dirty then Q.dirty=false; Q:ScanLog() end
  local shown=WorldMapFrame:IsVisible()
  if shown~=Q.mapShown then Q.mapShown=shown;Q.mapDirty=true;Q:RefreshTrackers() end
  if shown then Q:RefreshMap() end
  Q:RefreshQuestGivers()
  Q:UpdatePartySync()
end)
SLASH_QUESTLINE1="/ql"
SLASH_QUESTLINE2="/questline"
SlashCmdList["QUESTLINE"]=function(message) Q:Command(message) end
