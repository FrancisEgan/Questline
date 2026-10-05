// Exercise the dependency boundary with tiny isolated fixtures, no shared checkout required.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const {loadDatabase,sha256}=require('../tools/shared-database');
module.exports=function() {
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'questline-database-'));
  const addon=path.join(temp,'addon'),source=path.join(temp,'source');
  fs.mkdirSync(addon);fs.mkdirSync(path.join(source,'source'),{recursive:true});
  let checks=0;
  try {
    const names=['quests','items','units','objects','refloot','quests-itemreq','zones','areatrigger','minimap','meta','locales','scriptedEncounters','supplemental'];
    const files=names.map(name=>{const file='source/'+name+'.json';fs.writeFileSync(path.join(source,file),'{}\n');return {file,sha256:sha256('{}\n')};});
    const manifest={schemaVersion:1,profile:'octo',locale:'enUS',files,revision:'sha256:'+sha256(JSON.stringify(files))};
    const manifestFile=path.join(source,'manifest.json');
    fs.writeFileSync(manifestFile,JSON.stringify(manifest));
    assert.throws(()=>loadDatabase(addon,[source]),/revision differs/);checks++;
    const loaded=loadDatabase(addon,[source,'--update-lock']);
    assert.equal(loaded.lock.revision,manifest.revision);checks++;
    assert.deepEqual(loadDatabase(addon,[source]).data.quests,{});checks++;
    const pinned=fs.readFileSync(path.join(addon,'database-source.json'),'utf8');
    fs.writeFileSync(path.join(source,files[0].file),'{"2":{"disabled":1}}\n');
    assert.throws(()=>loadDatabase(addon,[source]),/hash mismatch/);checks++;
    files[0].sha256=sha256(fs.readFileSync(path.join(source,files[0].file)));
    manifest.revision='sha256:'+sha256(JSON.stringify(files));fs.writeFileSync(manifestFile,JSON.stringify(manifest));
    assert.throws(()=>loadDatabase(addon,[source]),/revision differs/);checks++;
    assert.equal(fs.readFileSync(path.join(addon,'database-source.json'),'utf8'),pinned);checks++;
    assert.equal(loadDatabase(addon,[source,'--update-lock']).data.quests[2].disabled,1);checks++;
    manifest.revision='sha256:wrong';fs.writeFileSync(manifestFile,JSON.stringify(manifest));
    assert.throws(()=>loadDatabase(addon,[source,'--update-lock']),/manifest revision mismatch/);checks++;
    files[0].file='../escape.json';fs.writeFileSync(manifestFile,JSON.stringify(manifest));
    assert.throws(()=>loadDatabase(addon,[source]),/Invalid manifest path/);checks++;
    assert.throws(()=>loadDatabase(addon,[source,'--unknown']),/Usage/);checks++;
  } finally {
    const resolved=path.resolve(temp),tempRoot=path.resolve(os.tmpdir())+path.sep;
    assert.ok(resolved.startsWith(tempRoot)&&path.basename(resolved).startsWith('questline-database-'));
    fs.rmSync(resolved,{recursive:true,force:true});
  }
  return checks;
};
