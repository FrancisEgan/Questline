// Build-time dependency contract. Keep in sync with Questie-Octo/Tools/shared-database.js.
// Runtime Lua never loads this module or the shared checkout.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sha256=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const repository='https://github.com/FrancisEgan/OctoQuestDatabase.git';
function loadDatabase(addonRoot,args=process.argv.slice(2)) {
  const update=args.includes('--update-lock');
  const paths=args.filter(arg=>!arg.startsWith('--'));
  if(paths.length>1||args.some(arg=>arg.startsWith('--')&&arg!=='--update-lock')) throw Error('Usage: [OctoQuestDatabase path] [--update-lock]');
  const sourceRoot=path.resolve(paths[0]||process.env.OCTO_QUEST_DATABASE||path.join(addonRoot,'../OctoQuestDatabase'));
  const manifest=JSON.parse(fs.readFileSync(path.join(sourceRoot,'manifest.json'),'utf8'));
  if(manifest.schemaVersion!==1||manifest.profile!=='octo'||manifest.locale!=='enUS'||!Array.isArray(manifest.files)) throw Error('Unsupported OctoQuestDatabase manifest');
  const files=manifest.files;
  const names=new Set();
  for(const entry of files) {
    if(typeof entry.file!=='string'||entry.file.includes('\\')||path.posix.isAbsolute(entry.file)||entry.file.split('/').some(part=>!part||part==='.'||part==='..')||names.has(entry.file)) throw Error('Invalid manifest path');
    names.add(entry.file);
    if(sha256(fs.readFileSync(path.join(sourceRoot,entry.file)))!==entry.sha256) throw Error('Shared database hash mismatch: '+entry.file+'; regenerate its manifest and explicitly update the addon lock.');
  }
  const revision='sha256:'+sha256(JSON.stringify(files));
  if(revision!==manifest.revision) throw Error('Shared database manifest revision mismatch');
  const lockFile=path.join(addonRoot,'database-source.json');
  let lock=fs.existsSync(lockFile)?JSON.parse(fs.readFileSync(lockFile,'utf8')):null;
  if(!update&&(!lock||lock.repository!==repository||lock.revision!==revision||lock.schemaVersion!==1)) throw Error('Shared database revision differs from database-source.json. Select the pinned checkout or explicitly pass --update-lock.');
  const data={};
  for(const entry of files.filter(entry=>entry.file.startsWith('source/'))) {
    if(!entry.file.endsWith('.json')) throw Error('Unsupported source file: '+entry.file);
    data[path.posix.basename(entry.file,'.json')]=JSON.parse(fs.readFileSync(path.join(sourceRoot,entry.file),'utf8'));
  }
  for(const kind of ['quests','items','units','objects','refloot','quests-itemreq','zones','areatrigger','minimap','meta','locales','scriptedEncounters','supplemental']) {
    if(!data[kind]||typeof data[kind]!=='object'||Array.isArray(data[kind])) throw Error('Missing shared source table: '+kind);
  }
  if(update) {
    lock={schemaVersion:1,repository,revision};
    fs.writeFileSync(lockFile,JSON.stringify(lock,null,2)+'\n');
  }
  return {data,manifest,sourceRoot,lock};
}
function copyNotices(sourceRoot,manifest,destination) {
  const originals=['provenance/SHARED_LICENSE_SCOPE.md','provenance/Questie-Octo/LICENSE','provenance/Questie-Octo/THIRD_PARTY_NOTICES.md','provenance/Questie-Octo/Docs/SOURCE_PROVENANCE.md'];
  for(const entry of manifest.files.filter(entry=>entry.file==='LICENSE'||entry.file.startsWith('LICENSES/')||originals.includes(entry.file))) {
    const output=path.join(destination,entry.file);
    fs.mkdirSync(path.dirname(output),{recursive:true});fs.copyFileSync(path.join(sourceRoot,entry.file),output);
  }
}
module.exports={loadDatabase,copyNotices,sha256};
