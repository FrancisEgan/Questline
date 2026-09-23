local Q,DB=Questline,QuestlineDB
local function label(parent,text,x,y,width)
  local f=parent:CreateFontString(nil,"OVERLAY")
  f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
  f:SetTextColor(.9,.88,.8);f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);f:SetText(text)
  return f
end
local function button(parent,text,x,y,width,action)
  local b=CreateFrame("Button",nil,parent)
  b:SetWidth(width);b:SetHeight(24);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  b.text=label(b,text,0,0,width);b.text:SetTextColor(.55,.8,1)
  b:SetScript("OnClick",action)
  Q:StyleTextLink(b)
  return b
end
local function window(name,parent,title,width,height)
  local f=CreateFrame("Frame",name,parent)
  f:SetWidth(width);f:SetHeight(height);f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true)
  f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
  f:SetBackdropColor(.025,.045,.065,.98)
  f.title=label(f,title,16,-14,width-60);f.title:SetTextColor(1,.82,.32)
  local close=CreateFrame("Button",nil,f);f.close=close
  close:SetWidth(18);close:SetHeight(18);close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-16,-12)
  -- Same native artwork and crop used by Bagshui; no addon dependency.
  local up=close:CreateTexture(nil,"ARTWORK");up:SetAllPoints(close)
  up:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up");up:SetTexCoord(.2,.75,.25,.75)
  local down=close:CreateTexture(nil,"ARTWORK");down:SetAllPoints(close)
  down:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down");down:SetTexCoord(.2,.75,.25,.75)
  local hover=close:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints(close)
  hover:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight");hover:SetTexCoord(.2,.75,.25,.75);hover:SetBlendMode("ADD")
  close:SetNormalTexture(up);close:SetPushedTexture(down);close:SetHighlightTexture(hover)
  close:SetScript("OnClick",function() this:GetParent():Hide() end)
  f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function() this:StartMoving() end)
  f:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
  f.rows={};f.page=1;return f
end
function Q:GetCompletionList(query,manualOnly)
  local list={};query=self:Normalize(query or "")
  for id,done in pairs(QuestlineSettings.completedQuests) do if done then
    local data=DB.quests[id];local source=QuestlineSettings.completionSources[id] or "Existing"
    if source=="Automatic" then source="Completed" end
    local title=data and data.title or ("Unknown quest "..id)
    if (not manualOnly or source=="Manual") and (query=="" or string.find(self:Normalize(title),query,1,true) or tostring(id)==query) then
      table.insert(list,{id=id,title=title,source=source})
    end
  end end
  table.sort(list,function(a,b) if a.title~=b.title then return a.title<b.title end;return a.id<b.id end)
  return list
end
function Q:RefreshOptions()
  local f=self.optionsPanel;if not f then return end
  local list=self:GetCompletionList(f.search:GetText(),f.manualOnly)
  f.pages=math.max(1,math.ceil(table.getn(list)/8));f.page=math.max(1,math.min(f.page,f.pages))
  f.count:SetText(table.getn(list).." records  -  Page "..f.page.." / "..f.pages)
  f.filter.text:SetText(f.manualOnly and "Show all records" or "Show manual only")
  f.tracker.text:SetText(QuestlineSettings.tracker and "Hide tracker" or "Show tracker")
  f.mapTracker.text:SetText(QuestlineSettings.mapTracker~=false and "Hide map tracker" or "Show map tracker")
  f.spawns.text:SetText(QuestlineSettings.worldMapSpawns~=false and "Hide world-map spawn markers" or "Show world-map spawn markers")
  if f.section~="completed" then return end
  for i=1,8 do
    local row=f.rows[i];local item=list[(f.page-1)*8+i]
    if item then
      row.id=item.id;row.fullTitle=item.title;row.title:SetText(item.title.."  (#"..item.id..")")
      row.source:SetText(item.source);row:Show()
    else row.id=nil;row:Hide() end
  end
end
function Q:ToggleOptions()
  if self.optionsPanel and self.optionsPanel:IsShown() then self.optionsPanel:Hide();return end
  if not self.optionsPanel then
    local f=window("QuestlineOptions",UIParent,"Questline",550,510);self.optionsPanel=f
    f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    f.home=CreateFrame("Frame",nil,f);f.home:SetAllPoints(f)
    label(f.home,"Your questing companion",18,-55,490)
    f.completedLink=button(f.home,"Completed quests",18,-98,230,function() Q:ShowOptionsSection("completed") end)
    f.optionsLink=button(f.home,"Options",18,-138,230,function() Q:ShowOptionsSection("options") end)
    f.settings=CreateFrame("Frame",nil,f);f.settings:SetAllPoints(f)
    button(f.settings,"< Home",18,-46,120,function() Q:ShowOptionsSection("home") end)
    f.tracker=button(f.settings,"",18,-90,230,function() Q:Command(QuestlineSettings.tracker and "tracker off" or "tracker on");Q:RefreshOptions() end)
    f.mapTracker=button(f.settings,"",18,-130,260,function() Q:Command(QuestlineSettings.mapTracker~=false and "maptracker off" or "maptracker on");Q:RefreshOptions() end)
    f.spawns=button(f.settings,"",18,-170,320,function()
      QuestlineSettings.worldMapSpawns=QuestlineSettings.worldMapSpawns==false
      Q.mapDirty=true;Q:RefreshMap();Q:RefreshOptions()
    end)
    button(f.settings,"Reset tracker layout",18,-210,230,function() Q:Command("reset") end)
    button(f.settings,"Show addon status in chat",18,-250,300,function() Q:Command("status") end)
    f.history=CreateFrame("Frame",nil,f);f.history:SetAllPoints(f)
    local h=f.history
    button(h,"< Home",18,-46,120,function() Q:ShowOptionsSection("home") end)
    label(h,"Completed quests",18,-83,220)
    label(h,"Restore removes the local record; normal eligibility rules still apply.",18,-105,514)
    label(h,"Search title / ID:",18,-137,125)
    f.search=CreateFrame("EditBox",nil,h);f.search:SetWidth(200);f.search:SetHeight(24)
    f.search:SetPoint("TOPLEFT",f,"TOPLEFT",145,-132);f.search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
    f.search:SetAutoFocus(false);f.search:SetMaxLetters(100)
    f.search:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    f.search:SetBackdropColor(.1,.13,.16,1)
    f.search:SetScript("OnTextChanged",function() f.page=1;Q:RefreshOptions() end)
    f.search:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    f.filter=button(h,"",360,-137,170,function() f.manualOnly=not f.manualOnly;f.page=1;Q:RefreshOptions() end)
    f.filter:ClearAllPoints();f.filter:SetPoint("TOPRIGHT",h,"TOPRIGHT",-18,-137);f.filter.text:SetJustifyH("RIGHT")
    for i=1,8 do
      local row=CreateFrame("Frame",nil,h);row:SetWidth(514);row:SetHeight(34);row:SetPoint("TOPLEFT",f,"TOPLEFT",18,-169-(i-1)*35)
      row.title=label(row,"",0,0,395);row.title:SetHeight(16)
      row.source=label(row,"",0,-17,395);row.source:SetTextColor(.6,.65,.7)
      row.restore=button(row,"Restore",420,-5,85,function() Q:RestoreCompletedQuest(this:GetParent().id) end)
      row.restore:ClearAllPoints();row.restore:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,-5);row.restore.text:SetJustifyH("RIGHT")
      row:EnableMouse(true)
      row:SetScript("OnEnter",function()
        if not this.id then return end
        GameTooltip:SetOwner(this,"ANCHOR_RIGHT");GameTooltip:SetText(this.fullTitle,1,.85,.4)
        GameTooltip:AddLine("Quest #"..this.id.." - "..this.source:GetText(),.8,.85,.9);GameTooltip:Show()
      end)
      row:SetScript("OnLeave",function() GameTooltip:Hide() end)
      f.rows[i]=row
    end
    f.count=label(h,"",115,-459,330)
    f.count:ClearAllPoints();f.count:SetPoint("BOTTOM",h,"BOTTOM",0,34);f.count:SetHeight(12);f.count:SetJustifyH("CENTER")
    f.previous=button(h,"<",18,-459,35,function() f.page=math.max(1,f.page-1);Q:RefreshOptions() end)
    f.next=button(h,">",497,-459,35,function() f.page=math.min(f.pages,f.page+1);Q:RefreshOptions() end)
    f.previous:ClearAllPoints();f.previous:SetPoint("LEFT",h,"BOTTOMLEFT",18,40)
    f.next:ClearAllPoints();f.next:SetPoint("RIGHT",h,"BOTTOMRIGHT",-18,40)
    f.previous.text:ClearAllPoints();f.previous.text:SetAllPoints(f.previous);f.previous.text:SetJustifyV("MIDDLE")
    f.next.text:ClearAllPoints();f.next.text:SetAllPoints(f.next);f.next.text:SetJustifyV("MIDDLE");f.next.text:SetJustifyH("RIGHT")
    h:EnableMouseWheel(true);h:SetScript("OnMouseWheel",function() f.page=math.max(1,math.min(f.pages,f.page-(arg1 or 0)));Q:RefreshOptions() end)
  end
  self:ShowOptionsSection("home");self.optionsPanel:Show()
end
function Q:ShowOptionsSection(section)
  local f=self.optionsPanel;f.section=section
  f.home:Hide();f.settings:Hide();f.history:Hide();f.search:ClearFocus();GameTooltip:Hide()
  if section=="completed" then f.history:Show();f:SetHeight(510);f.title:SetText("Questline - Completed quests")
  elseif section=="options" then f.settings:Show();f:SetHeight(300);f.title:SetText("Questline - Options")
  else f.home:Show();f:SetHeight(195);f.title:SetText("Questline") end
  self:RefreshOptions()
end
function Q:ShowCompletionMenu(pin,minimap)
  if minimap or not pin.giver then return end
  GameTooltip:Hide();WorldMapTooltip:Hide()
  if self.completionMenu then self.completionMenu:Hide() end
  local f=self.completionMenu
  if not f then
    f=window("QuestlineCompletionMenu",WorldMapFrame,"Mark quest completed",310,90);self.completionMenu=f
    f.dismiss=CreateFrame("Frame",nil,WorldMapFrame)
    f.dismiss:SetAllPoints(UIParent);f.dismiss:EnableMouse(true)
    f.dismiss:SetScript("OnMouseDown",function() f:Hide() end)
    f:SetScript("OnHide",function() f.dismiss:Hide() end)
    for i=1,6 do
      local b=button(f,"",22,-40,274,function()
        if Q:SetQuestCompleted(this.id,"Manual") then f:Hide();Q:RefreshQuestGivers() end
      end)
      f.rows[i]=b
    end
    f.count=label(f,"",50,-40,210);f.count:SetJustifyH("CENTER")
    f.previous=button(f,"<",14,-40,25,function() f.page=math.max(1,f.page-1);Q:RefreshCompletionMenu() end)
    f.next=button(f,">",271,-40,25,function() f.page=math.min(f.pages,f.page+1);Q:RefreshCompletionMenu() end)
    f.next.text:SetJustifyH("RIGHT")
  end
  local seen={};f.items={};f.page=1
  for _,giver in ipairs(self:GetNearbyGivers(pin,false)) do for _,quest in ipairs(giver.quests) do
    if quest.id and not seen[quest.id] and not self.byKey[tostring(quest.id)] then
      seen[quest.id]=true;table.insert(f.items,{id=quest.id,title=quest.title})
    end
  end end
  local level=WorldMapFrame:GetFrameLevel()+60
  f:SetFrameStrata("FULLSCREEN");f:SetFrameLevel(level)
  f.dismiss:SetFrameStrata("FULLSCREEN");f.dismiss:SetFrameLevel(level-1)
  -- Explicit child levels avoid stale levels after raising the pane above the map.
  f.close:SetFrameStrata("FULLSCREEN");f.close:SetFrameLevel(level+2)
  for _,row in ipairs(f.rows) do row:SetFrameStrata("FULLSCREEN");row:SetFrameLevel(level+1) end
  f.previous:SetFrameStrata("FULLSCREEN");f.previous:SetFrameLevel(level+1)
  f.next:SetFrameStrata("FULLSCREEN");f.next:SetFrameLevel(level+1)
  f:ClearAllPoints();f:SetPoint("TOPLEFT",pin,"BOTTOMRIGHT",0,0)
  self:RefreshCompletionMenu();f.dismiss:Show();f:Show()
end
function Q:RefreshCompletionMenu()
  local f=self.completionMenu;f.pages=math.max(1,math.ceil(table.getn(f.items)/6))
  local top=40
  for i=1,6 do
    local item=f.items[(f.page-1)*6+i];local row=f.rows[i]
    if item then
      row.id=item.id;row.text:SetText(item.title)
      local height=math.max(18,row.text:GetHeight())+6
      row:ClearAllPoints();row:SetPoint("TOPLEFT",f,"TOPLEFT",22,-top);row:SetHeight(height)
      top=top+height;row:Show()
    else row:Hide() end
  end
  f.count:Hide();f.previous:Hide();f.next:Hide()
  if table.getn(f.items)==0 or f.pages>1 then
    f.count:SetText(table.getn(f.items)==0 and "No identified quests to mark." or ("Page "..f.page.." / "..f.pages))
    f.count:ClearAllPoints();f.count:SetPoint("TOP",f,"TOP",0,-top);f.count:Show()
    if f.pages>1 then
      f.previous:ClearAllPoints();f.previous:SetPoint("TOPLEFT",f,"TOPLEFT",14,-top);f.previous:Show()
      f.next:ClearAllPoints();f.next:SetPoint("TOPRIGHT",f,"TOPRIGHT",-14,-top);f.next:Show()
    end
    top=top+24
  end
  f:SetHeight(top+10)
end
