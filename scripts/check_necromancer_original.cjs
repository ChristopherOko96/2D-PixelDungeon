const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/necromancer-catalog'),profile=path.join(out,'chrome-original-review-'+process.pid),wait=ms=>new Promise(r=>setTimeout(r,ms));
const child=cp.spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore'});let socket;
(async()=>{
 let port;for(let i=0;i<100;i++){try{port=fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0];break;}catch{}await wait(100);}if(!port)throw Error('No review port');
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json')).json();socket=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);await new Promise(r=>socket.addEventListener('open',r,{once:true}));
 const pending=new Map(),errors=[];let serial=0;socket.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}}if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text);});
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++serial;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});
 const evaluate=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
 await call('Runtime.enable');await call('Page.enable');await call('Emulation.setDeviceMetricsOverride',{width:1360,height:1000,deviceScaleFactor:1,mobile:false});
 const url=file=>'file:///'+path.join(out,file).replace(/\\/g,'/');
 await call('Page.navigate',{url:url('nekromant-original.html')});
 async function loaded(){for(let i=0;i<200;i++){const status=await evaluate('({ready:!!document.querySelector("#necro-original-play")&&!document.querySelector("#necro-original-play").disabled,loading:document.querySelector("#necro-original-loading")?.textContent})');if(status.loading?.startsWith('Aufnahme konnte'))throw Error(status.loading);if(status.ready)return;await wait(50);}throw Error('Frames did not load');}
 await wait(100);await loaded();
 if(await evaluate('getComputedStyle(document.querySelector("#necro-original-still")).display')!=='none')throw Error('Duplicate still visible over player');
 const cases=JSON.parse(fs.readFileSync(path.join(root,'production/qa/evidence/necromancer-catalog-hq/catalog.json'))).cases,seen=new Set();
 for(const spec of ['soul','curse','minion']){
  await evaluate('document.querySelector("[data-spec='+spec+']").click()');await loaded();
  const ids=await evaluate('[...document.querySelector("select").options].map(o=>o.value)');
  if(ids.length!==new Set(ids).size)throw Error('Duplicate options');
  for(const id of ids){
   await evaluate('(()=>{const s=document.querySelector("select");s.value='+JSON.stringify(id)+';s.dispatchEvent(new Event("change"));})()');await loaded();
   const state=await evaluate('({max:Number(document.querySelector("input").max),width:document.querySelector("canvas").width,height:document.querySelector("canvas").height,loaded:document.querySelector("#necro-original-loading").textContent})');
   if(state.max!==cases.find(c=>c.id===id).frames-1||state.width!==640||state.height!==360)throw Error('Bad original '+id+JSON.stringify(state));
   seen.add(id);
  }
 }
 if(seen.size!==cases.length)throw Error('Missing attacks');
 await evaluate('document.querySelector("[data-spec=soul]").click()');await loaded();
 const start=await evaluate('Number(document.querySelector("input").value)');await evaluate('document.querySelector("#necro-original-play").click()');await wait(900);
 const moving=await evaluate('Number(document.querySelector("input").value)');if(moving===start)throw Error('Animation stalled');
 await evaluate('document.querySelector("#necro-original-play").click()');
 const pause=await evaluate('Number(document.querySelector("input").value)');await wait(100);if(await evaluate('Number(document.querySelector("input").value)')!==pause)throw Error('Pause failed');
 await evaluate('document.querySelector("#necro-original-next").click()');if(await evaluate('Number(document.querySelector("input").value)')!==(pause+1)%92)throw Error('Single frame step failed');
 await evaluate('(()=>{const s=document.querySelector("input");s.value=18;s.dispatchEvent(new Event("input"));})()');
 for(const width of [1360,736,360,320]){await call('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});await wait(100);const overflow=await evaluate('document.documentElement.scrollWidth>innerWidth');if(overflow)throw Error('Overflow '+width);const shot=await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true});fs.writeFileSync(path.join(out,'original-review-'+width+'.png'),Buffer.from(shot.data,'base64'));}
 await call('Page.navigate',{url:url('original-inline-preview.html')});await wait(200);
 const data=await evaluate('JSON.parse(document.querySelector("#necro-original-data").textContent)');
 if(await evaluate('getComputedStyle(document.querySelector("#necro-original-player")).display')!=='none')throw Error('Inline still gallery exposes animation controls');
 for(const clip of data.clips){const image=Buffer.from(clip.still.split(',')[1],'base64'),file=fs.readFileSync(path.join(out,'original-stills',clip.id+'.png'));if(!image.equals(file)||image.readUInt32BE(16)!==640||image.readUInt32BE(20)!==360)throw Error('Inline downsample or changed bytes '+clip.id);}
 if(errors.length)throw Error(errors.join('\n'));
 const result={attacks:seen.size,sourceWidth:640,sourceHeight:360,sourceFps:30,frames:cases.reduce((n,c)=>n+c.frames,0),play:true,pause:true,singleFrame:true,inlineLossless:true,widths:[1360,736,360,320],errors};fs.writeFileSync(path.join(out,'original-browser-review.json'),JSON.stringify(result,null,2));console.log('NECRO_ORIGINAL_REVIEW '+JSON.stringify(result));
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{socket?.close();child.kill();});
