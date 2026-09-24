// Rebuild the runtime entirely from Questline's own normalized database.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { lua } = require('./lua-data');
const { GRID, geometry } = require('./geometry');
const { packRuns } = require('./packed-runs');
const { mobObjectives, mobDropRates, npcQuests, questGivers } = require('./mob-objectives');
const root=path.resolve(__dirname,'..'), dir=path.join(root,'database');
const kinds=['quests','units','objects','items','zones','events','lootGroups','itemUses','reference'];
const db=Object.fromEntries(kinds.map(k=>[k,JSON.parse(fs.readFileSync(path.join(dir,k+'.json'),'utf8'))]));
function patch(base,delta) {
  for(const [k,v] of Object.entries(delta)) {
    if(v===null) delete base[k];
    else if(typeof v==='object'&&!Array.isArray(v)) { if(!base[k]||typeof base[k]!=='object') base[k]={};patch(base[k],v); }
    else base[k]=v;
  }
}
const corrections=JSON.parse(fs.readFileSync(path.join(dir,'overrides.json'),'utf8'));
for(const k of kinds) if(corrections[k]) patch(db[k],corrections[k]);
const issues=[], locations={}, runtimeQuests={}, zoneIndex={};
const tables={unit:'units',object:'objects',item:'items',event:'events',use:'itemUses',zone:'zones'};
function targetName(kind,id) {return db[tables[kind]]?.[id]?.name || (kind==='use'?db.items[id]?.name:'') || (kind==='event'?'Explore the quest location':kind+' '+id);}
function gather(kind,id,seen=new Set()) {
  const key=kind+':'+id;if(seen.has(key)) return [];
  seen.add(key);
  const record=db[tables[kind]]?.[id];
  if(!record) return [];
  if(record.coordinates) return record.coordinates.map(p=>[p[0],p[1],p[2],p[3],kind]);
  let points=[];
  function sources(drops) {
    for(const [id,chance] of Object.entries(drops.units||{})) if(Number(chance)>=0) points.push(...gather('unit',id,seen));
    for(const [id,chance] of Object.entries(drops.objects||{})) if(Number(chance)>0) points.push(...gather('object',id,seen));
    for(const [id,chance] of Object.entries(drops.groups||{})) if(Number(chance)>=0 && !seen.has('group:'+id)) {
      seen.add('group:'+id);if(db.lootGroups[id]) sources(db.lootGroups[id]);
    }
  }
  if(kind==='item') {sources(record.drops);for(const id of Object.keys(record.vendors||{})) points.push(...gather('unit',id,seen));}
  if(kind==='use') for(const use of record) points.push(...gather(use.kind,use.id,seen));
  if(kind==='zone'&&record.bounds) {const b=record.bounds;points.push([b.x+b.width/2,b.y+b.height/2,b.parent]);}
  return points;
}
function target(t,turnin) {
  const key=(turnin?'turnin:':'')+t.kind+':'+t.id;
  if(!locations[key]) {
    const points=gather(t.kind,t.id), byZone={};
    for(const p of points) (byZone[p[2]]||=[]).push(p);
    locations[key]={};
    for(const [zone,coords] of Object.entries(byZone)) {
      const location=geometry(coords,turnin||t.kind==='event'||t.kind==='zone');
      if(!turnin && ['unit','object','item','use'].includes(t.kind)) {
        const unique=new Map();
        for(const p of coords) {
          const xy=[Math.round(p[0]*40),Math.round(p[1]*40)],key=xy.join(':');
          const gear=t.kind==='item'&&p[4]==='object';
          unique.set(key,{xy,gear:gear||unique.get(key)?.gear});
        }
        const ordered=[...unique.values()].sort((a,b)=>a.xy[0]-b.xy[0]||a.xy[1]-b.xy[1]);
        location.spawnPoints=packRuns(ordered.flatMap(p=>p.xy));
        if(t.kind==='item') location.spawnKinds=ordered.map(p=>p.gear?'g':'l').join('');
      }
      locations[key][zone]=location;
    }
    if(!points.length) issues.push({target:key,issue:'no-locations'});
  }
  let icon=t.icon || (t.kind==='item'?'loot':t.kind==='object'||t.kind==='use'?'interact':t.kind==='event'||t.kind==='zone'?'explore':'kill');
  if(t.kind==='item') {
    const sources=gather(t.kind,t.id);
    if(sources.length && sources.every(p=>p[4]==='object')) icon='interact';
  }
  if(t.kind==='unit' && db.units[t.id]?.faction==='AH') icon='talk';
  if(turnin) icon='turnin';
  const result={kind:t.kind,id:t.id,key,name:targetName(t.kind,t.id),icon};
  if(t.kind==='unit') result.faction=db.units[t.id]?.faction||'';
  return result;
}
const blockedBy={};
for(const [id,q] of Object.entries(db.quests)) for(const closed of q.closes) if(Number(id)!==closed) (blockedBy[closed]||=[]).push(Number(id));
for(const [id,q] of Object.entries(db.quests)) {
  const objectives=q.objectives.map(t=>target(t,false)),finishers=q.finishers.map(t=>target(t,true));
  runtimeQuests[id]={title:q.title,level:q.level,minLevel:q.minLevel,raceMask:q.raceMask,classMask:q.classMask,summary:q.summary,description:q.description,objectives,finishers,
    prerequisites:q.prerequisites,blockedBy:blockedBy[id]||[],skill:q.attributes.skill ? (db.reference.professions[q.attributes.skill]||'Unknown profession') : undefined,
    event:q.attributes.event,repeatable:q.attributes.repeatable ? true : undefined};
  for(const t of [...objectives,...finishers]) for(const zone of Object.keys(locations[t.key])) {
    if(!zoneIndex[zone]) zoneIndex[zone]=new Set();zoneIndex[zone].add(Number(id));
  }
}
const output=path.join(root,'Data');fs.mkdirSync(output,{recursive:true});
function writeTable(file,field,records,append=false) {
  const lines=['-- Generated by tools/build.js. Edit database/overrides.json, then rebuild.'];
  for(const [k,record] of Object.entries(records)) {
    const v=field==='locations'?Object.fromEntries(Object.entries(record).map(([zone,data])=>[zone,{...data,runs:packRuns(data.runs)}])):record;
    lines.push('QuestlineDB.'+field+'['+lua(/^\d+$/.test(k)?Number(k):k)+']='+lua(v));
  }
  fs[append?'appendFileSync':'writeFileSync'](path.join(output,file),lines.join('\n')+'\n');
}
const digest=crypto.createHash('sha256').update(JSON.stringify(db)).update(fs.readFileSync(__filename)).update(fs.readFileSync(path.join(__dirname,'geometry.js'))).update(fs.readFileSync(path.join(__dirname,'packed-runs.js'))).update(fs.readFileSync(path.join(__dirname,'mob-objectives.js'))).digest('hex').slice(0,16);
fs.writeFileSync(path.join(output,'Init.lua'),'-- Generated; see database/manifest.json for upstream inputs.\nQuestlineDB={schemaVersion=2,runEncoding="base64-pairs",profile="octo",locale="enUS",build='+lua(digest)+',grid='+GRID+',quests={},locations={},zones={},zoneQuests={},mobObjectives={},objectObjectives={},mobDropRates={},npcQuests={},givers={},zoneGivers={}}\n');
writeTable('Quests.lua','quests',runtimeQuests);
writeTable('Locations.lua','locations',locations);
writeTable('Zones.lua','zones',Object.fromEntries(Object.entries(db.zones).map(([id,zone])=>[id,{...zone,mapSize:db.reference.minimap[id]}])));
writeTable('ZoneQuests.lua','zoneQuests',Object.fromEntries(Object.entries(zoneIndex).map(([k,v])=>[k,[...v].sort((a,b)=>a-b)])));
writeTable('MobObjectives.lua','mobObjectives',mobObjectives(db));
writeTable('MobObjectives.lua','objectObjectives',mobObjectives(db,true),true);
writeTable('MobObjectives.lua','mobDropRates',mobDropRates(db),true);
writeTable('NPCQuests.lua','npcQuests',npcQuests(db));
const giverData=questGivers(db);
writeTable('QuestGivers.lua','givers',giverData.givers);
writeTable('ZoneGivers.lua','zoneGivers',giverData.byZone);
fs.mkdirSync(path.join(root,'reports'),{recursive:true});
const report={build:digest,grid:GRID,quests:Object.keys(runtimeQuests).length,targets:Object.keys(locations).length,zones:Object.keys(zoneIndex).length,unmappedTargets:issues.length,issues,
  barrens:{quests:zoneIndex[17]?.size,examples:[844,845,903,855,895,881,900].map(id=>({id,title:runtimeQuests[id]?.title,targets:runtimeQuests[id]?.objectives.map(t=>({key:t.key,spawns:locations[t.key][17]?.spawns,scanlines:(locations[t.key][17]?.runs.length||0)/3,points:locations[t.key][17]?.points.length}))}))}};
fs.writeFileSync(path.join(root,'reports','build.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,issues:undefined},null,2));
module.exports={patch,gather};
