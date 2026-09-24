local Q,DB=Questline,QuestlineDB
local getn,insert=table.getn,table.insert

function Q:InvalidateQuestAvailability()
  self.giverCache={};self.mapDirty=true
end
function Q:ImportCompletedQuests()
  local history=QuestlineSettings.completedQuests
  local added=0
  for id,done in pairs(pfQuest_history or {}) do
    id=tonumber(id)
    if id and done and done~=0 and not history[id] then history[id]=true;QuestlineSettings.completionSources[id]="Imported";added=added+1 end
  end
  QuestlineSettings.importedQuestHistory=true
  return added
end
function Q:UpdateNPCQuestState()
  local repaired=false
  local pending=self.pendingTurnIn
  if pending then
    if GetTime()-pending.time>30 then self.pendingTurnIn=nil
    elseif not self.byKey[tostring(pending.id)] then
      self.pendingTurnIn=nil;self:SetQuestCompleted(pending.id,"Automatic")
    end
  end
  self.recentQuests=self.recentQuests or {}
  local keys={}
  for _,entry in ipairs(self.quests) do
    insert(keys,entry.key)
    if entry.id and entry.data and not entry.data.repeatable and QuestlineSettings.completedQuests and
      QuestlineSettings.completedQuests[entry.id] and not QuestlineSettings.completionSources[entry.id] then
      QuestlineSettings.completedQuests[entry.id]=nil
      repaired=true
    end
    if entry.id then self.recentQuests[entry.id]={title=self:Normalize(entry.title),time=GetTime()} end
  end
  for id,record in pairs(self.recentQuests) do if GetTime()-record.time>10 then self.recentQuests[id]=nil end end
  table.sort(keys)
  local signature=table.concat(keys,";")
  if signature~=self.npcLogSignature then
    self.npcOffers={};self.npcLogSignature=signature;self:InvalidateQuestAvailability()
  end
  if repaired then self:InvalidateQuestAvailability();if self.RefreshOptions then self:RefreshOptions() end end
end
function Q:InitializeNPCQuests()
  QuestlineSettings.completedQuests=QuestlineSettings.completedQuests or {}
  QuestlineSettings.completionSources=QuestlineSettings.completionSources or {}
  if not QuestlineSettings.importedQuestHistory then
    self:ImportCompletedQuests()
  end
  self.npcOffers={};self:InvalidateQuestAvailability()
  if GetQuestReward and not self.rewardHooked then
    local original=GetQuestReward
    GetQuestReward=function(choice)
      -- Snapshot before the native call can remove this quest and offer its successor.
      Q:CaptureTurnIn()
      if Q.turnInDialog then Q.pendingTurnIn={id=Q.turnInDialog.id,title=Q.turnInDialog.title,time=GetTime()} end
      return original(choice)
    end
    self.rewardHooked=true
  end
  if AbandonQuest and not self.abandonHooked then
    local original=AbandonQuest
    AbandonQuest=function() Q.pendingTurnIn=nil;return original() end
    self.abandonHooked=true
  end
end
function Q:CaptureTurnIn()
  self.turnInDialog=nil
  if not GetTitleText then return end
  local title=self:Normalize(GetTitleText());local found,count=nil,0
  for _,entry in ipairs(self.quests) do
    if entry.id and entry.complete and not entry.failed and self:Normalize(entry.title)==title then found=entry.id;count=count+1 end
  end
  if count==1 then self.turnInDialog={id=found,title=title} end
end
function Q:SetQuestCompleted(id,source)
  id=tonumber(id)
  if not id or not DB.quests[id] then return false end
  if source=="Manual" and self.byKey[tostring(id)] then return false end
  QuestlineSettings.completedQuests[id]=true
  QuestlineSettings.completionSources[id]=source or "Automatic"
  self.npcOffers={};self:InvalidateQuestAvailability()
  if self.RefreshOptions then self:RefreshOptions() end
  return true
end
function Q:BeginServerQuestHistoryImport()
  local query=self.serverQuestHistoryQuery
  if query and query.active then return false end
  if not SendChatMessage then
    self:Print("This client cannot request quest history from the server.")
    return false
  end
  if not query then
    query=CreateFrame("Frame")
    self.serverQuestHistoryQuery=query
    query:SetScript("OnEvent",function()
      if arg1~="TWQUEST" or not query.active then return end
      query.received=true
      for token in string.gmatch(arg2 or "","%d+") do
        local id=tonumber(token)
        if id and DB.quests[id] then query.ids[id]=true end
      end
    end)
    query:SetScript("OnUpdate",function()
      if query.active and GetTime()>=query.deadline then Q:FinishServerQuestHistoryImport() end
    end)
  end
  query.active=true;query.received=false;query.ids={};query.deadline=GetTime()+3
  query:RegisterEvent("CHAT_MSG_ADDON")
  self:RefreshOptions()
  local ok=pcall(SendChatMessage,".queststatus","GUILD")
  if not ok then
    query.active=false;query:UnregisterEvent("CHAT_MSG_ADDON")
    self:RefreshOptions()
    self:Print("Could not send the quest history request.")
    return false
  end
  return true
end
function Q:FinishServerQuestHistoryImport()
  local query=self.serverQuestHistoryQuery
  if not query or not query.active then return end
  query.active=false;query:UnregisterEvent("CHAT_MSG_ADDON")
  local added=0
  if query.received then
    QuestlineSettings.completedQuests=QuestlineSettings.completedQuests or {}
    QuestlineSettings.completionSources=QuestlineSettings.completionSources or {}
    for id in pairs(query.ids) do
      if not QuestlineSettings.completedQuests[id] then
        QuestlineSettings.completedQuests[id]=true
        QuestlineSettings.completionSources[id]="Imported"
        added=added+1
      end
    end
    self:InvalidateQuestAvailability()
    self:RefreshQuestGivers()
    if added==0 then self:Print("Completed quests are up to date.")
    else self:Print(added..(added==1 and " quest" or " quests").." marked as completed.") end
  else
    self:Print("No response to the quest history request. Check that you are in a guild and try again.")
  end
  self:RefreshOptions()
end
function Q:RestoreCompletedQuest(id)
  QuestlineSettings.completedQuests[id]=nil;QuestlineSettings.completionSources[id]=nil
  self.npcOffers={};self:InvalidateQuestAvailability()
  if self.RefreshOptions then self:RefreshOptions() end
end
local function escapePattern(text) return string.gsub(text,"([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1") end
function Q:ObserveQuestCompletion(message)
  local format=ERR_QUEST_COMPLETE_S or "%s completed."
  local first,last=string.find(format,"%s",1,true)
  if not first then return end
  local pattern="^"..escapePattern(string.sub(format,1,first-1)).."(.-)"..escapePattern(string.sub(format,last+1)).."$"
  local _,_,title=string.find(message or "",pattern)
  if not title then return end
  title=self:Normalize(title)
  local pending=self.pendingTurnIn
  if pending and pending.title==title and GetTime()-pending.time<=30 then
    self.pendingTurnIn=nil;self:SetQuestCompleted(pending.id,"Automatic");return
  end
  local matches={}
  for _,entry in ipairs(self.quests) do if entry.id and self:Normalize(entry.title)==title then matches[entry.id]=true end end
  for id,record in pairs(self.recentQuests or {}) do if record.title==title and GetTime()-record.time<=10 then matches[id]=true end end
  local found,count=nil,0
  for id in pairs(matches) do found=id;count=count+1 end
  if count==1 then self:SetQuestCompleted(found,"Automatic") end
  self.npcOffers={};self:InvalidateQuestAvailability()
end
function Q:ObserveNPCOffers(gossip)
  local name=UnitName("npc")
  if not name then return end
  local offers={}
  if gossip and GetGossipAvailableQuests then
    -- Vanilla returns title/level pairs (not the tuples used by modern clients).
    local values={GetGossipAvailableQuests()}
    for index=1,getn(values),2 do insert(offers,{title=values[index],level=values[index+1]}) end
  elseif not gossip and GetNumAvailableQuests and GetAvailableTitle then
    for index=1,GetNumAvailableQuests() do insert(offers,{title=GetAvailableTitle(index),level=GetAvailableLevel and GetAvailableLevel(index)}) end
  else return end
  self.npcOffers[self:Normalize(name)]={quests=offers,time=GetTime()}
  self:InvalidateQuestAvailability()
end
function Q:IsQuestAvailable(id)
  local data=DB.quests[id]
  local completed=QuestlineSettings.completedQuests or {}
  if not data or data.deprecated or self.byKey[tostring(id)] or not self:MeetsQuestRestrictions(data) then return false end
  if completed[id] and (not data.repeatable or QuestlineSettings.completionSources[id]=="Manual") then return false end
  for _,other in ipairs(data.blockedBy or {}) do if completed[other] or self.byKey[tostring(other)] then return false end end
  if getn(data.prerequisites or {})>0 then
    local unlocked=false
    for _,previous in ipairs(data.prerequisites) do if completed[previous] then unlocked=true;break end end
    if not unlocked then return false end
  end
  -- Holiday availability needs an actual offer from the NPC, not a calendar guess.
  if data.event then return false end
  if data.skill then
    if not self.npcSkills then
      self.npcSkills={}
      if GetNumSkillLines and GetSkillLineInfo then for i=1,GetNumSkillLines() do
        local name,header,expanded,rank=GetSkillLineInfo(i)
        if name and not header and rank and rank>0 then self.npcSkills[name]=true end
      end end
    end
    if not self.npcSkills[data.skill] then return false end
  end
  return true
end
-- Shared by NPC tooltips and both maps. Recently observed server offers take
-- precedence over database predictions, including an explicitly empty list.
function Q:GetAvailableNPCQuests(name,ids)
  local available={}
  local offer=self.npcOffers and self.npcOffers[self:Normalize(name)]
  if offer and GetTime()-offer.time<=60 then
    for _,q in ipairs(offer.quests) do
      local found,count,known=nil,0,false
      for _,id in ipairs(ids or {}) do
        local data=DB.quests[id]
        if data and self:Normalize(data.title)==self:Normalize(q.title) then
          known=true
          local completed=QuestlineSettings.completedQuests[id] and
            (not data.repeatable or QuestlineSettings.completionSources[id]=="Manual")
          if not completed and not self.byKey[tostring(id)] and self:MeetsQuestRestrictions(data) and (not q.level or data.level==q.level) then found=id;count=count+1 end
        end
      end
      if count~=1 then found=nil end
      local hidden=found and QuestlineSettings.completedQuests[found] and
        (not DB.quests[found].repeatable or QuestlineSettings.completionSources[found]=="Manual")
      if not hidden and (not known or count>0) and not (found and self.byKey[tostring(found)]) then insert(available,{id=found,title=q.title,level=q.level,objectives={}}) end
    end
  else
    for _,id in ipairs(ids or {}) do
      if self:IsQuestAvailable(id) then insert(available,{id=id,title=DB.quests[id].title,level=DB.quests[id].level,objectives={}}) end
    end
  end
  self:SortQuests(available)
  return available
end
local function includes(list,id)
  for _,value in ipairs(list or {}) do if value==id then return true end end
  return false
end
local function talksTo(text,name)
  text=Q:Normalize(text)
  for _,verb in ipairs({"speak to ","speak with ","talk to ","talk with "}) do
    local start,finish=string.find(text,verb..name,1,true)
    if start and (start==1 or not string.find(string.sub(text,start-1,start-1),"%a"))
      and not string.find(string.sub(text,finish+1,finish+1),"%w") then return true end
  end
  return text==name.." spoken to"
end
local function talkObjectives(entry,name)
  local matches={};local related=false
  for index,objective in ipairs(entry.objectives) do
    local text=string.gsub(Q:Normalize(objective.text),":%s*%d+%s*/%s*%d+.*$","")
    if talksTo(text,name) then matches[index]=true;related=true end
  end
  if entry.data then for _,target in ipairs(entry.data.objectives) do
    if target.kind=="unit" and Q:Normalize(target.name)==name and talksTo(entry.summary,name) then
      for index,objective in ipairs(entry.objectives) do
        local label=string.gsub(Q:Normalize(objective.text),":%s*%d+%s*/%s*%d+.*$","")
        if label==name then matches[index]=true;related=true end
      end
      if getn(entry.objectives)==0 then related=true end
    end
  end end
  return related,matches
end
local function activeGroup(entry,name,talkOnly,talkMatches)
  local group={key=entry.key,title=entry.title,level=entry.level,number=entry.number,objectives={}}
  for index,objective in ipairs(entry.objectives) do
    if not talkOnly or talkMatches[index] then
      local _,_,label,current,required=string.find(objective.text,"^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
      local text=label and (label.." - "..current.."/"..required) or objective.text
      if talkMatches[index] then text="Talk to "..name..(current and (" - "..current.."/"..required) or "") end
      insert(group.objectives,{objectiveIndex=index,text=text,done=objective.done,name=Q:Normalize(label or text),current=tonumber(current),required=tonumber(required)})
    end
  end
  if getn(group.objectives)==0 then insert(group.objectives,{text=talkOnly and ("Talk to "..name) or Q:ExpandText(entry.summary)}) end
  return group
end
function Q:GetNPCSections(name)
  local key=self:Normalize(name)
  local profile=DB.npcQuests[key]
  local offer=self.npcOffers and self.npcOffers[key]
  if offer and GetTime()-offer.time>60 then offer=nil end
  local available,progress,complete={},{},{}
  local used,hasTalk={},false
  for _,entry in ipairs(self.quests) do
    local starter=profile and includes(profile.starters,entry.id)
    local finisher=profile and includes(profile.finishers,entry.id)
    local talk,matches=talkObjectives(entry,key)
    if talk then hasTalk=true end
    if not entry.failed then
      if entry.complete and finisher then insert(complete,{key=entry.key,title=entry.title,level=entry.level,objectives={}});used[entry.key]=true
      elseif not entry.complete and (starter or finisher or talk) then
        insert(progress,activeGroup(entry,name,not (starter or finisher),matches));used[entry.key]=true
      end
    end
  end
  if not profile and not hasTalk and not offer then return nil end
  available=self:GetAvailableNPCQuests(name,profile and profile.starters)
  -- A questgiver can also be an objective or item source for another active quest.
  for _,group in ipairs(self:GetMobProgress(name)) do
    local first=group.objectives[1];local entry=first and self.byKey[first.questKey]
    if entry and not entry.complete and not used[entry.key] then insert(progress,group);used[entry.key]=true end
  end
  table.sort(progress,function(a,b) return a.number<b.number end)
  return {{title="Available",groups=available},{title="In Progress",groups=progress},{title="Complete",groups=complete}}
end

local events=CreateFrame("Frame","QuestlineNPCEvents")
Q.npcEvents=events
for _,name in ipairs({"GOSSIP_SHOW","QUEST_GREETING","QUEST_COMPLETE","CHAT_MSG_SYSTEM","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED"}) do events:RegisterEvent(name) end
events:SetScript("OnEvent",function()
  if not Q.ready then return end
  if event=="GOSSIP_SHOW" then Q:ObserveNPCOffers(true)
  elseif event=="QUEST_GREETING" then Q:ObserveNPCOffers(false)
  elseif event=="QUEST_COMPLETE" then Q:CaptureTurnIn()
  elseif event=="CHAT_MSG_SYSTEM" then Q:ObserveQuestCompletion(arg1)
  else Q.npcOffers={};Q.npcSkills=nil end
  Q:InvalidateQuestAvailability()
  if event=="PLAYER_LEVEL_UP" then Q.dirty=true end
end)
