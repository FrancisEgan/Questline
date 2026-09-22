// One-time/repeatable migration. The addon and build.js do NOT need pfQuest.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readLua } = require('./lua-data');
const root = path.resolve(__dirname, '..');
const sourceRoot = path.resolve(process.argv[2] || path.join(root, '..'));
const kinds = ['quests','units','objects','items','zones','areatrigger','refloot','quests-itemreq','professions'];
const localized = ['quests','units','objects','items','zones','professions'];
const layers = ['pfQuest','pfQuest-turtle','pfQuest-octo'];
const merged = {}, origin = {}, conflicts = [], tombstones = {}, inputs = [];
for (const kind of kinds) { merged[kind]={data:{},enUS:{}}; origin[kind]={data:{},enUS:{}}; tombstones[kind]={}; }
const reference = { meta:{}, minimap:{} };
const hash = value => crypto.createHash('sha256').update(typeof value==='string'?value:JSON.stringify(value)).digest('hex');
function read(file, env) {
  if (!fs.existsSync(file)) return;
  inputs.push({file:path.relative(sourceRoot,file).replace(/\\/g,'/'),sha256:hash(fs.readFileSync(file).toString('utf8'))});
  readLua(file,env);
}
function merge(kind, bucket, entries, source) {
  for(const [id,record] of Object.entries(entries||{})) {
    const old = merged[kind][bucket][id];
    if(old!==undefined && hash(old)!==hash(record)) conflicts.push({kind,bucket,id:Number(id),previous:origin[kind][bucket][id],winner:source,action:record==='_'?'delete':'replace',fields:[...new Set([...Object.keys(old||{}),...Object.keys(record||{})])].filter(k=>hash(old?.[k]??null)!==hash(record?.[k]??null))});
    if(record==='_') { delete merged[kind][bucket][id]; if(bucket==='data') tombstones[kind][id]=source; }
    else { merged[kind][bucket][id]=record; if(bucket==='data') delete tombstones[kind][id]; }
    origin[kind][bucket][id]=source;
  }
}
for(const source of layers) {
  console.log('Importing '+source+' (including manual corrections)');
  const suffix=source==='pfQuest'?'':'-turtle', env={pfDB:{}};
  for(const kind of kinds) env.pfDB[kind]={};
  for(const kind of kinds) read(path.join(sourceRoot,source,'db',kind+suffix+'.lua'),env);
  for(const kind of localized) read(path.join(sourceRoot,source,'db','enUS',kind+suffix+'.lua'),env);
  for(const kind of ['meta','minimap']) read(path.join(sourceRoot,source,'db',kind+suffix+'.lua'),env);
  if(source==='pfQuest-turtle') read(path.join(sourceRoot,source,'db','patches-turtle.lua'),env);
  read(path.join(sourceRoot,source,'overwrites.lua'),env);
  for(const kind of kinds) for(const bucket of ['data','enUS']) merge(kind,bucket,env.pfDB[kind][bucket+suffix],source);
  for(const kind of ['meta','minimap']) for(const [k,v] of Object.entries(env.pfDB[kind+suffix]||{})) {
    if(v==='_') delete reference[kind][k]; else reference[kind][k]=v;
  }
  if(env.pfDB.quests.patch) reference.questPatches=env.pfDB.quests.patch;
}

const values = v => Object.values(v||{});
const issues=[], stats={coordinatesRead:0,invalidCoordinates:0,duplicateCoordinates:0};
const aliases={5600:5601,5098:5103,5550:5639,5132:209,5150:209,5161:209,5169:209,5173:209,5177:209,5138:1581,5139:1583,5155:1583,5164:1583,5170:1583,5178:1583,5140:1584};
function coords(raw, kind, id) {
  const result=[], seen=new Set();
  for(const c of values(raw)) {
    stats.coordinatesRead++;
    const x=Number(c[1]),y=Number(c[2]),zone=aliases[c[3]]||Number(c[3]);
    if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100||!Number.isInteger(zone)||zone<=0||(x===0&&y===0)) {
      stats.invalidCoordinates++; issues.push({kind,id:Number(id),issue:'invalid-coordinate',coordinate:c}); continue;
    }
    const p=[Math.round(x*1000)/1000,Math.round(y*1000)/1000,zone];
    if(c[4]!==undefined && Number.isFinite(Number(c[4]))) p.push(Number(c[4]));
    const key=p.slice(0,3).join(':');
    if(seen.has(key)) {stats.duplicateCoordinates++;continue;}
    seen.add(key);result.push(p);
  }
  return result.sort((a,b)=>a[2]-b[2]||a[0]-b[0]||a[1]-b[1]);
}
const typeNames={U:'unit',O:'object',I:'item',A:'event',IR:'use',Z:'zone'};
function targets(raw, owner) {
  const out=[];
  for(const [code,ids] of Object.entries(raw||{})) {
    if(!typeNames[code]) {issues.push({issue:'unknown-target-kind',owner,code});continue;}
    for(const id of values(ids)) out.push({kind:typeNames[code],id:Number(id)});
  }
  return out;
}
function extras(raw, keys) { return Object.fromEntries(Object.entries(raw).filter(([k])=>!keys.includes(k))); }
const db={schemaVersion:1,locale:'enUS',profile:'octo',quests:{},units:{},objects:{},items:{},zones:{},events:{},lootGroups:{},itemUses:{}};
for(const [id,r] of Object.entries(merged.quests.data)) {
  const text=merged.quests.enUS[id];
  if(!text || typeof text!=='object' || !text.T) {issues.push({kind:'quest',id:Number(id),issue:'missing-title'});continue;}
  db.quests[id]={title:text.T,level:Number(r.lvl)||0,minLevel:Number(r.min)||0,raceMask:Number(r.race)||0,classMask:Number(r.class)||0,
    description:text.D||'',summary:text.O||'',starters:targets(r.start,'quest:'+id),finishers:targets(r.end,'quest:'+id),objectives:targets(r.obj,'quest:'+id),
    prerequisites:values(r.pre).map(Number),closes:values(r.close).map(Number),attributes:extras(r,['lvl','min','race','class','start','end','obj','pre','close'])};
}
for(const kind of ['units','objects']) for(const [id,r] of Object.entries(merged[kind].data)) db[kind][id]={
  name:merged[kind].enUS[id]||'',coordinates:coords(r.coords,kind,id),faction:r.fac||'',level:r.lvl||'',attributes:extras(r,['coords','fac','lvl'])};
for(const [id,r] of Object.entries(merged.items.data)) db.items[id]={name:merged.items.enUS[id]||'',
  drops:{units:r.U||{},objects:r.O||{},groups:r.R||{}},vendors:r.V||{},attributes:extras(r,['U','O','R','V'])};
for(const [id,r] of Object.entries(merged.refloot.data)) db.lootGroups[id]={units:r.U||{},objects:r.O||{},groups:r.R||{},attributes:extras(r,['U','O','R'])};
for(const [id,r] of Object.entries(merged['quests-itemreq'].data)) db.itemUses[id]=Object.entries(r).map(([target,spell])=>({kind:Number(target)<0?'object':'unit',id:Math.abs(Number(target)),spell:Number(spell)}));
for(const [id,r] of Object.entries(merged.areatrigger.data)) db.events[id]={coordinates:coords(r.coords,'event',id),attributes:extras(r,['coords'])};
const zoneWeight={};
for(const kind of ['units','objects','events']) for(const r of Object.values(db[kind])) for(const p of r.coordinates) zoneWeight[p[2]]=(zoneWeight[p[2]]||0)+1;
for(const [id,name] of Object.entries(merged.zones.enUS)) {
  if(aliases[id]) continue;
  const r=merged.zones.data[id];
  db.zones[id]={name:name.trim(),coordinateCount:zoneWeight[id]||0};
  if(r) db.zones[id].bounds={parent:Number(r[1]),width:Number(r[2]),height:Number(r[3]),x:Number(r[4]),y:Number(r[5])};
}
const groups={};
for(const [id,z] of Object.entries(db.zones)) (groups[z.name]||=[]).push(Number(id));
for(const [name,ids] of Object.entries(groups)) if(ids.length>1) issues.push({issue:'duplicate-zone-name',name,ids,preferred:ids.sort((a,b)=>(zoneWeight[b]||0)-(zoneWeight[a]||0)||a-b)[0]});
const kindTable={unit:'units',object:'objects',item:'items',event:'events',use:'itemUses',zone:'zones'};
for(const [id,q] of Object.entries(db.quests)) for(const t of [...q.starters,...q.finishers,...q.objectives]) if(!db[kindTable[t.kind]]?.[t.id]) issues.push({issue:'missing-reference',quest:Number(id),target:t});

const output=path.join(root,'database');fs.mkdirSync(output,{recursive:true});fs.mkdirSync(path.join(root,'reports'),{recursive:true});fs.mkdirSync(path.join(root,'licenses'),{recursive:true});
function writeRecords(name, records) {fs.writeFileSync(path.join(output,name+'.json'),'{\n'+Object.entries(records).map(([k,v])=>'  '+JSON.stringify(k)+': '+JSON.stringify(v)).join(',\n')+'\n}\n');}
for(const [kind,records] of Object.entries(db)) if(typeof records==='object') writeRecords(kind,records);
reference.professions=merged.professions.enUS;
writeRecords('reference',reference);
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify({schemaVersion:1,locale:db.locale,profile:db.profile,precedence:layers,inputs,counts:Object.fromEntries(Object.entries(db).filter(([,v])=>typeof v==='object').map(([k,v])=>[k,Object.keys(v).length])),stats},null,2)+'\n');
fs.writeFileSync(path.join(root,'reports','import.json'),JSON.stringify({policy:'Atomic record replacement; base < Turtle < Octo; underscore means deletion. English text uses the same precedence. Coordinates are validated, deduplicated, and phantom dungeon zone IDs canonicalized.',conflicts,issues,tombstones,origin},null,2)+'\n');
for(const source of layers) fs.copyFileSync(path.join(sourceRoot,source,'LICENSE'),path.join(root,'licenses',source+'-MIT.txt'));
console.log(JSON.stringify({counts:JSON.parse(fs.readFileSync(path.join(output,'manifest.json'))).counts,stats,conflicts:conflicts.length,issues:issues.length},null,2));
