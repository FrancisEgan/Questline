const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const {readLua,lua,luaparse}=require('../tools/lua-data');
const {geometry,GRID}=require('../tools/geometry');
const {badge,glow,area}=require('../tools/contour-assets');
const {packRuns,unpackRuns}=require('../tools/packed-runs');
const {mobObjectives,mobDropRates,npcQuests,questGivers}=require('../tools/mob-objectives');
let fengari;
try { fengari=require('fengari'); } catch (_) { fengari=require(path.join(root,'../.test-tools/node_modules/fengari')); }
const {lua:Lapi,lauxlib,lualib,to_luastring,to_jsstring}=fengari;
let checks=0;
const check=(value,message)=>{checks++;assert.ok(value,message);};
const read=k=>JSON.parse(fs.readFileSync(path.join(root,'database',k+'.json'),'utf8'));
const quests=read('quests'),units=read('units'),items=read('items');
check(Object.keys(quests).length>6000,'merged quests retained');
check(!quests[1],'upstream underscore tombstone honored');
check(units[92012].coordinates[0][2]===8,'Octo manual relocation applied');
check(items[51220].drops.units[50610]===100,'Octo manual interaction applied');
check(quests[900].objectives.length===3,'all valve interactions preserved');
const mobIndex=mobObjectives({quests,units,items,lootGroups:read('lootGroups')});
check(mobIndex['rattlecage soldier'].includes('item:3162'),'Rattlecage Soldier drops Notched Rib');
check(mobIndex['young night web spider'].includes('unit:1504'),'kill objectives are indexed by mob name');
const lootFixture=mobObjectives({
  quests:{1:{objectives:[{kind:'item',id:10},{kind:'unit',id:1}]}},
  units:{1:{name:'Test Mob'},2:{name:'Quest Drop Mob'},3:{name:'Vendor Only'},4:{name:'Disabled Drop'}},
  items:{10:{drops:{units:{1:25,4:-1},groups:{20:100}},vendors:{3:1}}},
  lootGroups:{20:{units:{2:0},groups:{21:100}},21:{units:{1:50},groups:{20:100}}}
});
assert.deepEqual(lootFixture['test mob'],['item:10','unit:1']);checks++;
check(lootFixture['quest drop mob'].includes('item:10'),'zero-rate quest drops and cyclic reference loot resolve');
check(!lootFixture['vendor only']&&!lootFixture['disabled drop'],'vendors and disabled drops are excluded');
const realRates=mobDropRates({quests,units,items,lootGroups:read('lootGroups')});
check(realRates['adult plainstrider']['item:7097']===10.4,'Leg Meat uses the owned Adult Plainstrider rate, not the example percentage');
check(realRates['rattlecage soldier']['item:3162']===40,'Notched Rib percentage is retained');
const rateFixture=mobDropRates({
  quests:{1:{objectives:[{kind:'item',id:10},{kind:'unit',id:1}]}},
  units:{1:{name:'Direct'},2:{name:'Reference'},3:{name:'Unknown'},4:{name:'Vendor'},5:{name:'Disabled'},
    6:{name:'Same Name'},7:{name:'Same Name'},8:{name:'Invalid'},10:{name:'Tiny'},11:{name:'Member'},12:{name:'Conflicting references'}},
  items:{10:{drops:{units:{1:25,3:0,5:-1,6:20,7:50,8:101,10:.0065},groups:{20:12.5,21:70}},vendors:{4:1}}},
  lootGroups:{20:{units:{1:50,2:4,11:0},groups:{22:100}},22:{units:{12:100},groups:{20:100}},21:{units:{12:100}}}
});
check(rateFixture.direct['item:10']===25,'direct unit rates take priority over reference membership');
check(rateFixture.reference['item:10']===12.5&&rateFixture.member['item:10']===12.5,'item reference percentage is used without multiplying membership flags');
check(!rateFixture.unknown&&!rateFixture.invalid&&!rateFixture.disabled&&!rateFixture.vendor,'unknown, invalid and vendor-only percentages are omitted');
check(!rateFixture['same name']&&!rateFixture['conflicting references'],'conflicting same-name variants and reference paths do not invent a rate');
check(rateFixture.tiny['item:10']===.0065,'small positive percentages are retained');
const npcFixture={
  quests:{1:{starters:[{kind:'unit',id:1},{kind:'unit',id:1},{kind:'object',id:4}],finishers:[{kind:'unit',id:2}]},
    2:{starters:[{kind:'unit',id:1}],finishers:[{kind:'unit',id:1}]},
    3:{starters:[{kind:'unit',id:3},{kind:'unit',id:999}],finishers:[]}},
  units:{1:{name:'  Quest   Giver ',coordinates:[[52.2,31,17,300],[52.2,31,17],[20,30,14]]},
    2:{name:'Turn-in Only',coordinates:[[50,50,17]]},3:{name:'Unlocated Giver',coordinates:[]}}
};
const npcIndex=npcQuests(npcFixture),giverIndex=questGivers(npcFixture);
assert.deepEqual(npcIndex['quest giver'],{starters:[1,2],finishers:[2]});checks++;
assert.deepEqual(npcIndex['turn-in only'],{starters:[],finishers:[1]});checks++;
assert.deepEqual(giverIndex.givers[1].quests,[1,2]);checks++;
assert.deepEqual(giverIndex.givers[1].coordinates,[[52.2,31,17],[20,30,14]]);checks++;
assert.deepEqual(giverIndex.byZone,{14:[1],17:[1]});checks++;
check(!giverIndex.givers[2]&&!giverIndex.givers[4]&&!giverIndex.givers[999],'turn-in-only NPCs, objects and unresolved starters do not create giver pins');
const giverData=questGivers({quests,units});
check(giverData.byZone[17].includes(3338)&&giverData.givers[3338].quests.includes(844),'real Barrens starter and its quest chain are compiled');
const sources=JSON.parse(fs.readFileSync(path.join(root,'reports/import.json'),'utf8'));
check(sources.origin.units.data[92012]==='pfQuest-octo','Octo wins conflicting IDs');
for(const kind of ['units','objects','events']) for(const [id,r] of Object.entries(read(kind))) {
  const seen=new Set();
  for(const p of r.coordinates) {
    assert.ok(p[0]>=0&&p[0]<=100&&p[1]>=0&&p[1]<=100&&p[2]>0,kind+':'+id+' bounds');
    const key=p.slice(0,3).join(':');assert.ok(!seen.has(key),kind+':'+id+' duplicate');seen.add(key);
  }
}
checks++;
const single=geometry([[40,40,17]]);check(single.runs.length===0&&single.points.length===1,'one target becomes icon');
const points=[[10,10],[10,11],[11,10],[11,12],[12,11],[12,12],[80,80],[80,81],[81,80],[81,82],[82,81],[82,82]];
const grouped=geometry(points);check(grouped.runs.length>0,'dense clusters become areas');
let middle=false;for(let i=0;i<grouped.runs.length;i+=3) if(grouped.runs[i]>GRID*.3&&grouped.runs[i]<GRID*.7) middle=true;
check(!middle,'distant areas never joined across empty zone');
check(geometry(points,true).runs.length===0,'turn-in targets remain points');
check(JSON.stringify(geometry(points))===JSON.stringify(grouped),'geometry deterministic');
assert.deepEqual(unpackRuns(packRuns(grouped.runs)),grouped.runs,'packed scanlines retain geometry exactly');checks++;
assert.deepEqual(unpackRuns(packRuns([0,63,64,1279,1280,4095])),[0,63,64,1279,1280,4095],'packed coordinate boundaries');checks++;
assert.throws(()=>unpackRuns('abc'),/Truncated/);assert.throws(()=>packRuns([4096]),/range/);checks++;
for(let i=0;i<grouped.runs.length;i+=3) check(grouped.runs[i]>=0&&grouped.runs[i]<GRID&&grouped.runs[i+1]>=0&&grouped.runs[i+2]<=GRID,'raster bounds');
check(badge(0,0,true)[1]>180&&badge(0,0,false)[1]<50,'selected fill is yellow; normal fill is burgundy');
check(glow(.7,0)[3]>0&&glow(1,0)[3]===0,'halo fades to transparent without square corners');
let seamChecks=0;
for(let a=0;a<16;a++) for(let b=0;b<16;b++) for(const t of [.1,.25,.49,.5,.51,.75,.9]) {
  if(Boolean(a&2)===Boolean(b&1)&&Boolean(a&4)===Boolean(b&8)) {
    const left=area(a,1,t),right=area(b,0,t);
    left.forEach((c,i)=>assert.ok(Math.abs(c-right[i])<1e-8,'horizontal contour seam '+a+':'+b));seamChecks++;
  }
  if(Boolean(a&8)===Boolean(b&1)&&Boolean(a&4)===Boolean(b&2)) {
    const top=area(a,t,1),bottom=area(b,t,0);
    top.forEach((c,i)=>assert.ok(Math.abs(c-bottom[i])<1e-8,'vertical contour seam '+a+':'+b));seamChecks++;
  }
}
check(seamChecks>800,'all compatible atlas edge orientations join seamlessly');
const fixture={pfDB:{units:{data:{}}}};
readLua(path.join(__dirname,'fixture.lua'),fixture);
check(fixture.pfDB.units.data[1].name==="L'épreuve",'UTF-8 and Lua apostrophe escapes preserved');
check(!fixture.pfDB.units.data[2]&&fixture.pfDB.units.data[3]==='_','patch deletion and tombstone distinguished');
if(fs.existsSync(path.join(root,'reports/Barrens-preview.html'))) {
  const preview=fs.readFileSync(path.join(root,'reports/Barrens-preview.html'),'utf8');
  const script=preview.match(/<script>([\s\S]*)<\/script>/)[1];
  const elements={};
  require('node:vm').runInNewContext(script,{document:{querySelector:key=>elements[key]||(elements[key]={})}});
  check(elements['#map'].innerHTML.includes('<rect'),'offline preview renders compiled areas');
  check(elements['#quests'].innerHTML.includes('Plainstrider Menace'),'offline preview includes quest selectors');
}

// Parse every runtime file and disallow syntax introduced after Lua 5.0.
const toc=fs.readFileSync(path.join(root,'Questline.toc'),'utf8');
const files=toc.split(/\r?\n/).filter(s=>s&&!s.startsWith('#')).map(s=>s.replace(/\\/g,'/'));
function walk(node,visit) {if(!node||typeof node!=='object')return;visit(node);for(const v of Object.values(node)) if(Array.isArray(v))v.forEach(n=>walk(n,visit));else if(v&&typeof v==='object')walk(v,visit);}
for(const name of files) {
  const code=fs.readFileSync(path.join(root,name),'utf8');
  const ast=luaparse.parse(code,{luaVersion:'5.1',comments:false});
  let constants=new Set();
  walk(ast,node=>{assert.notEqual(node.operator,'#',name+' uses Lua 5.1 length operator');assert.notEqual(node.operator,'%',name+' uses Lua 5.1 modulo operator');assert.notEqual(node.type,'VarargLiteral',name+' uses Lua 5.1 vararg expression');if(node.type==='StringLiteral'||node.type==='NumericLiteral')constants.add(node.raw);});
  check(constants.size<65536,name+' fits Vanilla constant table');
}
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
function run(code,name) {
  let status=lauxlib.luaL_loadbuffer(L,to_luastring(code),null,to_luastring(name));
  if(status===Lapi.LUA_OK) status=Lapi.lua_pcall(L,0,0,0);
  if(status!==Lapi.LUA_OK) throw Error(name+': '+to_jsstring(Lapi.lua_tostring(L,-1)));
}
run(fs.readFileSync(path.join(__dirname,'runtime.lua'),'utf8'),'runtime stubs');
for(const name of files) run(fs.readFileSync(path.join(root,name),'utf8'),name);
run('runTests()','runtime tests');
if(process.argv.includes('--review')) {
  const id=Number(Object.keys(quests).find(id=>quests[id].title==='Preventing Poison'))||845;
  const source='return Questline:ContourPatches(Questline:AreaRows(QuestlineDB.quests['+id+'].objectives,17))';
  let status=lauxlib.luaL_loadstring(L,to_luastring(source));
  if(status===Lapi.LUA_OK)status=Lapi.lua_pcall(L,0,1,0);
  if(status!==Lapi.LUA_OK)throw Error(to_jsstring(Lapi.lua_tostring(L,-1)));
  const patches=[];
  for(let i=1;i<=Lapi.lua_rawlen(L,-1);i++) {
    Lapi.lua_rawgeti(L,-1,i);const p=[];
    for(let j=1;j<=5;j++){Lapi.lua_rawgeti(L,-1,j);p.push(Lapi.lua_tonumber(L,-1));Lapi.lua_pop(L,1);}
    patches.push(p);Lapi.lua_pop(L,1);
  }
  Lapi.lua_pop(L,1);
  const x1=Math.min(...patches.map(p=>p[0]))-4,y1=Math.min(...patches.map(p=>p[1]))-4;
  const x2=Math.max(...patches.map(p=>p[2]))+4,y2=Math.max(...patches.map(p=>p[3]))+4;
  const width=720,height=Math.round(width*(y2-y1)/(x2-x1)*2/3),buckets={};
  const {bitmap,writePNG}=require('../tools/texture-format');
  writePNG(path.join(root,'reports','Rounded-area.png'),bitmap(width,height,(px,py)=>{
    const x=x1+px/width*(x2-x1),y=y1+py/height*(y2-y1),key=Math.floor(y*4);
    if(!buckets[key])buckets[key]=patches.filter(p=>p[1]<(key+1)/4&&p[3]>key/4);
    const patch=buckets[key].find(p=>x>=p[0]&&x<p[2]&&y>=p[1]&&y<p[3]);
    const color=patch?area(patch[4],(x-patch[0])/(patch[2]-patch[0]),(y-patch[1])/(patch[3]-patch[1])):[0,0,0,0];
    const a=color[3]/255,bg=[147,110,56];
    return [...bg.map((v,i)=>v*(1-a)+color[i]*a),255];
  },4));
  console.log('Rendered review for '+quests[id].title+' from '+patches.length+' actual Lua contour patches.');
}
console.log('Database / geometry / compatibility: '+checks+' checks passed. '+files.length+' Lua files parsed and executed.');
