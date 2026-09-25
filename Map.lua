local Q, DB = Questline, QuestlineDB
local getn = table.getn
local texturePath = "Interface\\AddOns\\Questline\\Textures\\"
local actionTextures={
  loot=texturePath.."action-loot",kill=texturePath.."action-kill",
  interact=texturePath.."action-interact",explore=texturePath.."action-interact",
  talk="Interface\\GossipFrame\\GossipGossipIcon",
}
local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local digit={}
for i=1,string.len(alphabet) do digit[string.byte(alphabet,i)]=i-1 end
local function coordinate(text,index)
  return digit[string.byte(text,index)]*64+digit[string.byte(text,index+1)]
end
function Q:CreateMap()
  if self.overlay then return end
  -- Child of the actual map canvas, so Magnify scaling and scroll clipping apply.
  self.selectorLayer=CreateFrame("Frame","QuestlineMapSelectors",WorldMapButton)
  self.selectorLayer:SetAllPoints(WorldMapButton);self.selectorLayer:EnableMouse(false)
  self.selectorLayer:SetFrameLevel(WorldMapButton:GetFrameLevel()+5)
  self.overlay=CreateFrame("Frame","QuestlineMapAreas",WorldMapButton)
  self.overlay:SetAllPoints(WorldMapButton);self.overlay:EnableMouse(false)
  self.overlay:SetFrameLevel(WorldMapButton:GetFrameLevel()+4)
  self.pinLayer=CreateFrame("Frame","QuestlineMapPins",WorldMapButton)
  self.pinLayer:SetAllPoints(WorldMapButton);self.pinLayer:EnableMouse(false)
  self.pinLayer:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)
  self.fills={};self.edges={};self.mapPins={};self.objectivePins={}
end
-- Union already-built scanlines from unfinished objectives. No spawn data or
-- clustering is loaded by the client. Merging avoids darker overlaps.
function Q:AreaRows(targets,zone)
  local rows={}
  for _,target in ipairs(targets) do
    local data=DB.locations[target.key] and DB.locations[target.key][zone]
    if data then
      for i=1,string.len(data.runs),6 do
        local y=coordinate(data.runs,i)
        rows[y]=rows[y] or {}
        table.insert(rows[y],{coordinate(data.runs,i+2),coordinate(data.runs,i+4)})
      end
    end
  end
  for y,spans in pairs(rows) do
    table.sort(spans,function(a,b) return a[1]<b[1] end)
    local merged={}
    for _,span in ipairs(spans) do
      local previous=merged[getn(merged)]
      if previous and span[1]<=previous[2] then previous[2]=math.max(previous[2],span[2])
      else table.insert(merged,{span[1],span[2]}) end
    end
    rows[y]=merged
  end
  return rows
end
function Q:AreaRectangles(rows)
  local rectangles,active={},{}
  for y=0,DB.grid-1 do
    local nextActive={}
    for _,span in ipairs(rows[y] or {}) do
      local key=span[1]..":"..span[2]
      local rect=active[key]
      if rect then rect[4]=y+1 else rect={span[1],y,span[2],y+1};table.insert(rectangles,rect) end
      nextActive[key]=rect
    end
    active=nextActive
  end
  return rectangles
end
local function solid(pool,index,parent,red,green,blue,alpha)
  if not pool[index] then pool[index]=parent:CreateTexture(nil,"ARTWORK");pool[index]:SetTexture(red,green,blue,alpha) end
  return pool[index]
end
local function place(texture,x,y,width,height,mapWidth,mapHeight)
  texture:ClearAllPoints();texture:SetPoint("TOPLEFT",Q.overlay,"TOPLEFT",x/DB.grid*mapWidth,-y/DB.grid*mapHeight)
  texture:SetWidth(math.max(0.1,width/DB.grid*mapWidth));texture:SetHeight(math.max(0.1,height/DB.grid*mapHeight));texture:Show()
end
function Q:ContourPatches(rows)
  local patches,active={},{}
  local function contains(spans,x)
    for _,span in ipairs(spans or {}) do
      if x<span[1] then return false end
      if x<span[2] then return true end
    end
    return false
  end
  for y=-1,DB.grid-1 do
    local top,bottom=rows[y] or {},rows[y+1] or {}
    local breaks,seen={},{}
    -- Only inspect points where the four-corner mask can change. Large solid
    -- interiors and straight boundaries become single stretched rectangles.
    for _,spans in ipairs({top,bottom}) do for _,span in ipairs(spans) do
      for _,x in ipairs({span[1]-1,span[1],span[2]-1,span[2]}) do
        if not seen[x] then seen[x]=true;table.insert(breaks,x) end
      end
    end end
    table.sort(breaks)
    local nextActive={}
    for i=1,getn(breaks)-1 do
      local x,right=breaks[i],breaks[i+1]
      local mask=0
      if contains(top,x) then mask=mask+1 end
      if contains(top,x+1) then mask=mask+2 end
      if contains(bottom,x+1) then mask=mask+4 end
      if contains(bottom,x) then mask=mask+8 end
      if mask>0 then
        local key=mask..":"..x..":"..right
        local mergeable=mask==15 or mask==6 or mask==9
        local patch=mergeable and active[key]
        if patch then patch[4]=y+1.5
        else patch={x+.5,y+.5,right+.5,y+1.5,mask};table.insert(patches,patch) end
        if mergeable then nextActive[key]=patch end
      end
    end
    active=nextActive
  end
  return patches
end
function Q:DrawAreas(targets,zone,width,height)
  local parts={tostring(zone),tostring(width),tostring(height)}
  for _,target in ipairs(targets) do table.insert(parts,target.key) end
  local key=table.concat(parts,"|")
  -- Quest-log updates can arrive without changed objectives. Reuse the entire
  -- layout in that case, not just the texture allocations.
  if self.areaLayoutKey==key then return end
  self.areaLayoutKey=key
  local fills,edges=0,0
  for _,patch in ipairs(self:ContourPatches(self:AreaRows(targets,zone))) do
    local x,y=math.max(0,patch[1]),math.max(0,patch[2])
    local right,bottom=math.min(DB.grid,patch[3]),math.min(DB.grid,patch[4])
    if right>x and bottom>y then
      local texture
      if patch[5]==15 then
        fills=fills+1;texture=solid(self.fills,fills,self.overlay,0.10,0.43,1,0.30)
      else
        edges=edges+1
        if not self.edges[edges] then
          self.edges[edges]=self.overlay:CreateTexture(nil,"ARTWORK")
          self.edges[edges]:SetTexture(texturePath.."area-contours")
        end
        texture=self.edges[edges]
        local col,row=math.mod(patch[5],4),math.floor(patch[5]/4)
        local u1,u2=(x-patch[1])/(patch[3]-patch[1]),(right-patch[1])/(patch[3]-patch[1])
        local v1,v2=(y-patch[2])/(patch[4]-patch[2]),(bottom-patch[2])/(patch[4]-patch[2])
        texture:SetTexCoord((col*64+2+u1*60)/256,(col*64+2+u2*60)/256,(row*64+2+v1*60)/256,(row*64+2+v2*60)/256)
      end
      place(texture,x,y,right-x,bottom-y,width,height)
    end
  end
  for i=fills+1,getn(self.fills) do self.fills[i]:Hide() end
  for i=edges+1,getn(self.edges) do self.edges[i]:Hide() end
end
local function tooltipLeave() GameTooltip:Hide();WorldMapTooltip:Hide() end
function Q:GetPin(index,objective)
  local pool=objective and self.objectivePins or self.mapPins
  if not pool[index] then
    local pin
    if objective then
      pin=CreateFrame("Button",nil,self.pinLayer);pin:SetWidth(18);pin:SetHeight(18)
      pin.texture=pin:CreateTexture(nil,"ARTWORK");pin.texture:SetAllPoints(pin)
    else pin=self:MakeBadge(self.pinLayer,25) end
    pin:SetScript("OnClick",function() if this.entry then Q:Select(this.entry.key,IsControlKeyDown and IsControlKeyDown()) end end)
    pin:SetScript("OnEnter",function() if this.entry then Q:ShowQuestTooltip(this,this.entry,this.target) end end)
    pin:SetScript("OnLeave",tooltipLeave)
    pool[index]=pin
  end
  return pool[index]
end
function Q:PlacePin(pin,point,width,height)
  pin:ClearAllPoints();pin:SetPoint("CENTER",self.pinLayer,"TOPLEFT",point[1]/100*width,-point[2]/100*height);pin:Show()
end
function Q:SelectedSpawns(zone)
  local keys={tostring(zone)};local targets={}
  for _,entry in ipairs(self.quests) do if self:IsSelected(entry.key) and not entry.complete and not entry.failed then
    for _,target in ipairs(self:Targets(entry)) do
      table.insert(keys,entry.key..":"..target.key);table.insert(targets,{entry=entry,target=target})
    end
  end end
  local key=table.concat(keys,";")
  self.spawnCache=self.spawnCache or {}
  local cached=self.spawnCache[zone or 0]
  if cached and cached.key==key then return cached.points end
  local points,seen={},{}
  for _,item in ipairs(targets) do
    local location=DB.locations[item.target.key] and DB.locations[item.target.key][zone]
    local packed=location and location.spawnPoints or ""
    for i=1,string.len(packed),4 do
      local identity=item.target.key..":"..string.sub(packed,i,i+3)
      if not seen[identity] then
        seen[identity]=true
        local kind=location.spawnKinds and string.sub(location.spawnKinds,(i-1)/4+1,(i-1)/4+1)
        table.insert(points,{coordinate(packed,i)/40,coordinate(packed,i+2)/40,entry=item.entry,target=item.target,icon=kind=="g" and "interact" or (kind=="l" and "loot" or nil)})
      end
    end
  end
  -- Only keep the currently browsed and physical zones in memory.
  local playerZone=self:GetPlayerZone()
  for old in pairs(self.spawnCache) do if old~=zone and old~=playerZone then self.spawnCache[old]=nil end end
  self.spawnCache[zone or 0]={key=key,points=points};return points
end
function Q:SpawnPin(pool,index,parent,minimap)
  if not pool[index] then
    local pin=CreateFrame("Button",nil,parent);pool[index]=pin
    pin:SetFrameLevel(parent:GetFrameLevel()+1)
    pin.texture=pin:CreateTexture(nil,"ARTWORK");pin.texture:SetAllPoints(pin)
    pin:SetScript("OnEnter",function()
      local p=this.spawn
      local entry=p and Q.byKey[p.entry.key]
      if entry then Q:ShowQuestTooltip(this,entry,p.target) end
    end)
    pin:SetScript("OnLeave",tooltipLeave)
  end
  return pool[index]
end
function Q:RefreshSpawnMap(zone,width,height,inverseScale)
  self.mapSpawns=self.mapSpawns or {};local count=0
  if zone and QuestlineSettings.worldMapSpawns==true then
    for _,point in ipairs(self:SelectedSpawns(zone)) do
      count=count+1;local pin=self:SpawnPin(self.mapSpawns,count,self.pinLayer,false);pin.spawn=point
      pin.texture:SetTexture(actionTextures[point.icon or point.target.icon] or actionTextures.interact)
      pin:SetWidth(14*inverseScale);pin:SetHeight(14*inverseScale);self:PlacePin(pin,point,width,height)
    end
  end
  for i=count+1,getn(self.mapSpawns) do self.mapSpawns[i]:Hide() end
end
function Q:RefreshSpawnMinimap()
  self.minimapSpawns=self.minimapSpawns or {};local count=0;local c=self.minimapSpawnContext
  if c then for _,point in ipairs(self.minimapRenderData and self.minimapRenderData.spawns or self:SelectedSpawns(c.zone)) do
    local x,y=self:MinimapGiverPosition(point,c.x,c.y,c.size,c.diameter,c.facing)
    if x then
      count=count+1;local pin=self:SpawnPin(self.minimapSpawns,count,Minimap,true);pin.spawn=point
      pin.texture:SetTexture(actionTextures[point.icon or point.target.icon] or actionTextures.interact)
      pin:SetWidth(14);pin:SetHeight(14);pin:ClearAllPoints();pin:SetPoint("CENTER",Minimap,"CENTER",x,y);pin:Show()
    end
  end end
  for i=count+1,getn(self.minimapSpawns) do self.minimapSpawns[i]:Hide() end
end
function Q:RefreshMap()
  if not self.overlay or not WorldMapFrame:IsVisible() then return end
  -- Reassert ordering even on cached renders: map addons/clicks can raise frames.
  local base=WorldMapButton:GetFrameLevel()
  self.selectorLayer:SetFrameLevel(base+5)
  self.overlay:SetFrameLevel(base+4)
  self.pinLayer:SetFrameLevel(base+8)
  for _,pin in ipairs(self.mapPins) do pin:SetFrameLevel(pin.entry and pin.entry.complete and base+11 or base+9) end
  local zone=self:GetMapZone()
  local width,height=WorldMapButton:GetWidth(),WorldMapButton:GetHeight()
  local scale=WorldMapButton:GetEffectiveScale()
  if not self.mapDirty and self.lastZone==zone and self.lastWidth==width and self.lastHeight==height and self.lastScale==scale then return end
  local zoneChanged=self.lastZone~=zone
  self.mapDirty=false;self.lastZone=zone;self.lastWidth=width;self.lastHeight=height;self.lastScale=scale
  for _,pool in ipairs({self.mapPins,self.objectivePins}) do for _,element in ipairs(pool) do element:Hide() end end
  if zoneChanged then self.mapTracker.page=1;self:RefreshTrackers() end
  if not zone or width<=0 or height<=0 then
    self:RefreshSpawnMap(nil)
    for _,pool in ipairs({self.fills,self.edges}) do for _,texture in ipairs(pool) do texture:Hide() end end
    self.areaLayoutKey=nil;return
  end
  local inverseScale=WorldMapFrame:GetEffectiveScale()/scale
  self:RefreshSpawnMap(zone,width,height,inverseScale)
  local selectedEntries,targets,targetKeys={},{},{}
  for _,entry in ipairs(self.quests) do if self:IsSelected(entry.key) then
    table.insert(selectedEntries,entry)
    for _,target in ipairs(self:Targets(entry)) do if not targetKeys[target.key] then
      targetKeys[target.key]=true;table.insert(targets,target)
    end end
  end end
  self:DrawAreas(targets,zone,width,height)
  local markerCount=0;local used={}
  for _,entry in ipairs(self.quests) do
    local selected=self:IsSelected(entry.key)
    local anchor
    for _,target in ipairs(self:Targets(entry)) do
      local location=DB.locations[target.key] and DB.locations[target.key][zone]
      if location and location.anchor then anchor=location.anchor;break end
    end
    if anchor then
      markerCount=markerCount+1
      local pin=self:GetPin(markerCount,false);pin.entry=entry;pin.target=nil
      self:SizeBadge(pin,25,inverseScale)
      self:PaintBadge(pin,entry,selected)
      if entry.complete then
        pin:SetWidth(14*inverseScale);pin:SetHeight(14*inverseScale)
        pin.texture:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        pin.text:Hide()
        pin.glow:SetTexture(texturePath.."turnin-glow")
        pin.glow:SetWidth(26*inverseScale);pin.glow:SetHeight(26*inverseScale)
      else
        -- Pins are pooled: restore the normal badge after a turn-in used this slot.
        pin.text:Show();pin.glow:SetTexture(texturePath.."circle-glow-v2")
      end
      -- Fan out shared questgiver pins instead of stacking unclickable circles.
      local x,y=anchor[1]/100*width,anchor[2]/100*height
      if selected and not entry.complete then
        for _,target in ipairs(self:Targets(entry)) do
          local location=DB.locations[target.key] and DB.locations[target.key][zone]
          if location then for _,point in ipairs(location.points) do
            if math.abs(point[1]-anchor[1])<0.1 and math.abs(point[2]-anchor[2])<0.1 then x=math.max(13*inverseScale,x-24*inverseScale);break end
          end end
          if x~=anchor[1]/100*width then break end
        end
      end
      local originalX,originalY=x,y
      -- A turn-in marker is a destination, so moving it to avoid nearby pins
      -- makes the map give the wrong location. Stacked turn-ins share the exact
      -- NPC coordinate; only numbered objective selectors fan out.
      if not entry.complete then for attempt=0,60 do
          local overlaps=false
          for _,p in ipairs(used) do if (x-p[1])*(x-p[1])+(y-p[2])*(y-p[2])<625*inverseScale*inverseScale then overlaps=true;break end end
          if not overlaps then break end
          local angle=attempt*2.4;local radius=(28+math.floor(attempt/7)*15)*inverseScale
          x=math.max(13*inverseScale,math.min(width-13*inverseScale,originalX+math.cos(angle)*radius))
          y=math.max(13*inverseScale,math.min(height-13*inverseScale,originalY+math.sin(angle)*radius))
        end end
      table.insert(used,{x,y});self:PlacePin(pin,{x/width*100,y/height*100},width,height)
    end
  end
  local count=0;local pointKeys={}
  for _,selected in ipairs(selectedEntries) do if not selected.complete then for _,target in ipairs(self:Targets(selected)) do
    local location=DB.locations[target.key] and DB.locations[target.key][zone]
    if location then for _,point in ipairs(location.points) do
      local key=point[1]..":"..point[2]..":"..target.icon
      if not pointKeys[key] then
        pointKeys[key]=true;count=count+1
        local icon=target.icon
        if icon=="kill" and target.kind=="unit" and target.faction and UnitFactionGroup then
          local faction=UnitFactionGroup("player")=="Horde" and "H" or "A"
          if string.find(target.faction,faction,1,true) then icon="talk" end
        end
        local pin=self:GetPin(count,true);pin.entry=selected;pin.target=target;pin.texture:SetTexture(actionTextures[icon] or actionTextures.interact)
        pin:SetWidth(18*inverseScale);pin:SetHeight(18*inverseScale)
        -- Small action icons sit next to the numbered selector at shared anchors.
        self:PlacePin(pin,point,width,height)
        pin:SetFrameLevel(self.pinLayer:GetFrameLevel()+4)
      end
    end end
  end end end
  -- Badges share the pin layer with objective icons: areas are behind both,
  -- objective icons sit above badges, and turn-in icons remain above all.
  for i=1,markerCount do
    local pin=self.mapPins[i]
    pin:SetFrameLevel(pin.entry.complete and (self:IsSelected(pin.entry.key) and base+14 or base+13) or base+9)
  end
  for _,pin in ipairs(self.mapSpawns or {}) do pin:SetFrameLevel(base+12) end
end
