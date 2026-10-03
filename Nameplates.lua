local Q, DB = Questline, QuestlineDB
local getn = table.getn

function Q:NameplateQuests(name)
  local keys=DB.mobObjectives[self:Normalize(name or "")]
  if not keys then return {} end
  local wanted={}
  for _,key in ipairs(keys) do wanted[key]=true end
  local result={}
  for _,entry in ipairs(self.quests) do
    if not entry.complete and not entry.failed then
      for _,target in ipairs(self:Targets(entry)) do if wanted[target.key] then
        table.insert(result,entry);break
      end end
    end
  end
  return result
end

local function plateName(nameplate)
  local original=nameplate.original
  local name=original and original.name and original.name:GetText()
  if not name or name=="" then name=nameplate.name and nameplate.name:GetText() end
  return name
end

function Q:PaintNameplate(nameplate)
  if not nameplate then return end
  local name=plateName(nameplate)
  local entries=self:NameplateQuests(name)
  nameplate.questlineBadges=nameplate.questlineBadges or {}
  local anchor=nameplate.health or nameplate
  for index,entry in ipairs(entries) do
    local badge=nameplate.questlineBadges[index]
    if not badge then
      badge=self:MakeBadge(nameplate,18);badge:EnableMouse(false)
      nameplate.questlineBadges[index]=badge
    end
    self:SizeBadge(badge,18,.78)
    badge:ClearAllPoints()
    if index==1 then badge:SetPoint("LEFT",anchor,"RIGHT",5,0)
    else badge:SetPoint("LEFT",nameplate.questlineBadges[index-1],"RIGHT",2,0) end
    self:PaintBadge(badge,entry,self:IsSelected(entry.key));badge:Show()
  end
  for index=getn(entries)+1,getn(nameplate.questlineBadges) do nameplate.questlineBadges[index]:Hide() end
end

function Q:RefreshNameplates(changesOnly)
  if not GudaPlates or not GudaPlates.registry then return end
  for frame,nameplate in pairs(GudaPlates.registry) do
    if frame:IsShown() and nameplate:IsShown() then
      local name=plateName(nameplate)
      if not changesOnly or not nameplate.questlineVisible or nameplate.questlineName~=name then
        self:PaintNameplate(nameplate)
      end
      nameplate.questlineVisible=true;nameplate.questlineName=name
    else
      nameplate.questlineVisible=nil;nameplate.questlineName=nil
      if nameplate.questlineBadges then
        for _,badge in ipairs(nameplate.questlineBadges) do badge:Hide() end
      end
    end
  end
end

local updater=CreateFrame("Frame","QuestlineNameplateUpdater")
local elapsed=0
updater:SetScript("OnUpdate",function()
  elapsed=elapsed+arg1
  -- New/reused plates need badges on their first visible frame. Keep the
  -- more expensive quest-progress/selection repaint on the existing timer.
  local changesOnly=elapsed<.2
  if not changesOnly then elapsed=0 end
  Q:RefreshNameplates(changesOnly)
end)
