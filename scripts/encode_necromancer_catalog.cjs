/* Encode controlled game recordings with Chromium's own VP9 encoder; no downloads. */
const fs=require('fs'),path=require('path'),http=require('http'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),source=path.join(root,'production/qa/evidence/necromancer-catalog'),out=path.join(root,'output/necromancer-catalog');
fs.mkdirSync(out,{recursive:true});
const catalog=JSON.parse(fs.readFileSync(path.join(source,'catalog.json'),'utf8'));
const page=`<!doctype html><meta charset="utf-8"><canvas width="256" height="144"></canvas><p id="state">Recording</p><script>
(async()=>{
 const meta=await(await fetch('/meta')).json(),canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
 const stream=canvas.captureStream(0),track=stream.getVideoTracks()[0],chunks=[];
 const rec=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp9',videoBitsPerSecond:10000});
 rec.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};
 const stopped=new Promise(resolve=>rec.onstop=resolve);rec.start();const clock=performance.now(),clips=[];let frame=0;
 for(const item of meta.cases){const clip={id:item.id,start:frame/meta.fps};
  for(let f=0;f<item.frames;f++){
   const img=await createImageBitmap(await(await fetch('/frames/'+item.id+'/frame-'+String(f).padStart(3,'0')+'.png')).blob());
   await new Promise(r=>setTimeout(r,Math.max(0,clock+frame*1000/meta.fps-performance.now())));
   ctx.drawImage(img,0,0,canvas.width,canvas.height);img.close();track.requestFrame();frame++;
  }clip.end=frame/meta.fps;clips.push(clip);document.getElementById('state').textContent=item.id;
 }
 await new Promise(r=>setTimeout(r,100));rec.stop();await stopped;stream.getTracks().forEach(t=>t.stop());
 await fetch('/timing',{method:'POST',body:JSON.stringify({clips,duration:frame/meta.fps,fps:meta.fps})});
 const blob=new Blob(chunks,{type:'video/webm'});await fetch('/recording',{method:'POST',body:blob});document.getElementById('state').textContent='Complete';
})().catch(e=>fetch('/failure',{method:'POST',body:String(e.stack||e)}));
</script>`;
let child,done=false;
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://localhost');
 if(url.pathname==='/'){res.setHeader('Content-Type','text/html');res.end(page);return;}
 if(url.pathname==='/meta'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(catalog));return;}
 if(url.pathname.startsWith('/frames/')){const file=path.resolve(source,decodeURIComponent(url.pathname.slice(8)));if(!file.startsWith(source+path.sep)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}res.setHeader('Content-Type','image/png');fs.createReadStream(file).pipe(res);return;}
 let chunks=[];req.on('data',b=>chunks.push(b));req.on('end',()=>{
  const data=Buffer.concat(chunks);
  if(url.pathname==='/timing'){fs.writeFileSync(path.join(out,'video-timing.json'),data);console.log('CATALOG_VIDEO timings received');}
  if(url.pathname==='/recording'){fs.writeFileSync(path.join(out,'catalog-raw.webm'),data);console.log('CATALOG_VIDEO_DONE bytes='+data.length);done=true;}
  if(url.pathname==='/failure'){console.error('CATALOG_VIDEO_FAIL '+data.toString());done=true;process.exitCode=1;}
  res.end('ok');
  if(done)setTimeout(()=>{child.kill();server.close();},500);
 });
});
server.listen(0,'127.0.0.1',()=>{
 const port=server.address().port,url='http://127.0.0.1:'+port+'/';
 const profile=path.join(out,'chrome-encoder-profile');
 child=cp.spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows','--autoplay-policy=no-user-gesture-required','--remote-debugging-port=0','--user-data-dir='+profile,url],{windowsHide:true,stdio:'ignore'});
 console.log('CATALOG_VIDEO recording cases='+catalog.cases.length+' seconds='+catalog.cases.reduce((n,c)=>n+c.frames/catalog.fps,0).toFixed(1)+' port='+port);
 child.on('exit',code=>{if(!done){console.error('CATALOG_VIDEO browser exited '+code);server.close();process.exitCode=1;}});
});
setTimeout(()=>{if(!done){console.error('CATALOG_VIDEO timeout');process.exitCode=1;child?.kill();server.close();}},300000).unref();
