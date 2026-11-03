const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/necromancer-catalog'),profile=path.join(out,'chrome-review-profile-'+process.pid);
const expected=JSON.parse(fs.readFileSync(path.join(out,'video-timing.json'))).clips;
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const child=cp.spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--autoplay-policy=no-user-gesture-required','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore'});
let socket;
(async()=>{
 let port;for(let i=0;i<100;i++){try{port=fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0];break;}catch{}await delay(100);}
 if(!port)throw Error('No inspection port');
 const tabs=await(await fetch('http://127.0.0.1:'+port+'/json')).json();
 socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise(r=>socket.addEventListener('open',r,{once:true}));
 const pending=new Map(),errors=[];let serial=0;
 socket.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}}if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text);});
 function call(method,params={}){const id=++serial;return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});}
 const evaluate=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
 await call('Runtime.enable');await call('Page.enable');await call('Emulation.setDeviceMetricsOverride',{width:900,height:1100,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:'file:///'+path.join(out,'preview.html').replace(/\\/g,'/')});
 for(let i=0;i<150;i++){if(await evaluate('(document.querySelector("video")?.readyState||0)>=2&&document.querySelector("#necro-still")?.naturalWidth===320'))break;await delay(100);}
 const initial=await evaluate('({duration:document.querySelector("video").duration,ready:document.querySelector("video").readyState,selected:document.querySelector("select").value,options:document.querySelector("select").options.length,stillWidth:document.querySelector("#necro-still").naturalWidth})');
 if(!Number.isFinite(initial.duration)||initial.ready<2||initial.stillWidth!==320)throw Error('Media did not load: '+JSON.stringify(initial));
 const decoded=Buffer.from(await evaluate('document.querySelector("video").src.split(",")[1]'),'base64');
 if(!decoded.equals(fs.readFileSync(path.join(out,'catalog.webm'))))throw Error('Embedded video differs from encoded source');
 const seen=new Set(),checks=[];
 for(const spec of ['curse','minion','soul']){
  await evaluate('document.querySelector("[data-spec='+spec+']").click()');
  const ids=await evaluate('[...document.querySelector("select").options].map(o=>o.value)');ids.forEach(id=>seen.add(id));
  if(ids.length!==new Set(ids).size)throw Error('Duplicate options '+spec);
  const passiveCount=await evaluate('document.querySelector("#necro-passives").children.length');if(passiveCount!==7)throw Error('Passives missing');
  for(const id of ids){
   await evaluate('(()=>{const s=document.querySelector("select");s.value='+JSON.stringify(id)+';s.dispatchEvent(new Event("change"));})()');
   for(let wait=0;wait<100;wait++){await delay(30);if(await evaluate('!document.querySelector("video").seeking&&document.querySelector("video").readyState>=2'))break;}
   const check=await evaluate('({id:document.querySelector("select").value,time:document.querySelector("video").currentTime,seek:document.querySelector("video").seeking,error:document.querySelector("video").error?.message,name:document.querySelector("#necro-name").textContent})');
   const target=expected.find(c=>c.id===id);
   if(check.error||check.seek||Math.abs(check.time-target.start-.025)>.15)throw Error('Seek failed: '+JSON.stringify(check));checks.push(check);
  }
 }
 if(seen.size!==38)throw Error('Only '+seen.size+' selectable clips');
 await evaluate('document.querySelector("[data-spec=curse]").click();document.querySelector("select").value="curse_9";document.querySelector("select").dispatchEvent(new Event("change"));document.querySelector("#necro-play").click()');
 await delay(1200);
 const playing=await evaluate('({paused:document.querySelector("video").paused,time:document.querySelector("video").currentTime,label:document.querySelector("#necro-play").textContent})');if(playing.paused)throw Error('Playback failed');
 await evaluate('document.querySelector("#necro-play").click()');
 const pause=await evaluate('document.querySelector("video").paused');if(!pause)throw Error('Pause failed');
 for(const width of [900,360,320]){
  await call('Emulation.setDeviceMetricsOverride',{width,height:1100,deviceScaleFactor:1,mobile:false});await delay(100);
  const sizes=await evaluate('({view:innerWidth,scroll:document.documentElement.scrollWidth})');if(sizes.scroll>width)throw Error('Overflow '+JSON.stringify(sizes));
  const shot=await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true});fs.writeFileSync(path.join(out,'review-'+width+'.png'),Buffer.from(shot.data,'base64'));
 }
 const result={initial,selectableClips:seen.size,checks,playing,pause,errors};fs.writeFileSync(path.join(out,'browser-review.json'),JSON.stringify(result,null,2));
 if(errors.length)throw Error(errors.join('\n'));console.log('NECRO_ARTIFACT_BROWSER clips='+seen.size+' widths=900,360,320 playback=pause/seek/playing errors=0 duration='+initial.duration);
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{socket?.close();child.kill();});
