const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../android/app/src/main/assets/word_slice/index.html'),'utf8');
const ids=new Set([...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1])),nodes=new Map();
const strokeCalls=[],fillCalls=[];
const context=new Proxy({},{get(t,k){
 if(k==='measureText')return text=>({width:16*[...text].length});
 if(k==='createLinearGradient')return()=>({addColorStop(){}});
 if(k==='strokeText')return text=>strokeCalls.push(text);
 if(k==='fillText')return(text,x,y)=>fillCalls.push({text,x,y,color:t.fillStyle,font:t.font,alpha:t.globalAlpha});
 return t[k]??(()=>{});
}});
function el(id){assert.ok(ids.has(id),'No dangling DOM reference: '+id);if(!nodes.has(id))nodes.set(id,{style:{},textContent:'',classList:{add(){},remove(){}},clientWidth:390,clientHeight:844,events:{},addEventListener(k,f){this.events[k]=f},getBoundingClientRect(){return {left:0,top:0,width:390,height:844}},querySelectorAll(){return []},setPointerCapture(){},hasPointerCapture(){return false},releasePointerCapture(){},getContext(){return context}});return nodes.get(id)}
let requests=0,busy=false,failures=0;
const sandbox={console,Math,Promise,performance,devicePixelRatio:2,Image:class{set src(v){queueMicrotask(()=>this.onload?.())}},requestAnimationFrame(){},setTimeout(){},clearTimeout(){},setInterval(){},document:{hidden:false,getElementById:el,createElement(tag){assert.equal(tag,'canvas');return {getContext(){return context;}};},querySelectorAll(){return[]},addEventListener(){}},window:{addEventListener(){}},NativeSlice:{ready(){},failed(){failures++},heartbeat(){},pendantPosition(x,y){sandbox.pendantXY=[x,y]},requestStart(){requests++},setPlaying(v){busy=v}}};
vm.createContext(sandbox);vm.runInContext(html.split('<script>')[1].split('</script>')[0],sandbox);const run=x=>vm.runInContext(x,sandbox);
run("loaded=true;window.sliceHost.configure({anchorX:358,panelTop:390,floor:700,hudTop:72})");
assert.equal(run('anchor.y'),390);run('startGame()');assert.equal(requests,1);assert.equal(run('mode'),'idle');
run("window.sliceHost.start([{ch:'鲸',x:130,y:550,size:20}])");assert.equal(busy,false);assert.equal(run('glyphs[0].x'),130);assert.equal(run('glyphs[0].ch'),'鲸');
run('warmIntroCache();draw()');assert.equal(busy,true);
assert.equal(run('introBitmaps.size'),1);
assert.equal(run('glyphs[0].y'),550);
run('for(let i=0;i<24;i++)update(1/120)');assert.equal(run('glyphs[0].y'),550);
run('for(let i=0;i<250;i++)update(1/120)');assert.equal(run('mode'),'playing');run('score=100;update(.01);draw()');assert.ok(run('love!==null'));
run('window.sliceHost.suspend()');assert.equal(busy,false);assert.equal(run('visible'),false);assert.equal(run('glyphs.length+bombs.length+particles.length'),0);
run('window.sliceHost.configure({anchorX:358,panelTop:230,floor:700,hudTop:72});window.sliceHost.resume()');assert.equal(run('anchor.y'),230);assert.equal(run('visible'),true);
assert.ok(!ids.has('sound')&&!ids.has('audioTest')&&!ids.has('hint')&&!ids.has('conversation'));assert.equal(failures,0);
console.log('PASS: actual bundled HTML, all DOM refs, native capture handshake, real glyph origin, moving anchor, reward draw, pause cleanup and removed controls.');

run('window.sliceHost.configure({anchorX:358,panelTop:230,floor:700,hudTop:72})');
for (const [x,y] of [[1,0],[0,-1],[-1,0],[0,1]]) {
 run(`window.sliceHost.motion(${x},${y});for(let i=0;i<500;i++)stepRope(1/120);time+=.04;draw()`);
 assert.ok(run(`(rope[8].x-anchor.x)*${x}+(rope[8].y-anchor.y)*${y}`)>40);
 assert.equal(run('rope[0].x'),358);
 assert.equal(run('rope[0].y'),230);
 assert.ok(Math.abs(sandbox.pendantXY[0]-run('pendantPose().x'))<.01);
 assert.ok(Math.abs(sandbox.pendantXY[1]-run('pendantPose().y'))<.01);
 if (x===1) assert.ok(run('pendantPose().x>W'));
 if (y===-1) assert.ok(run('pendantPose().y<anchor.y'));
}
run('window.sliceHost.configure({anchorX:195,panelTop:230,floor:700,hudTop:72});window.sliceHost.motion(0,-1);for(let i=0;i<600;i++)stepRope(1/120)');
assert.ok(run('rope[8].y<anchor.y-40'),'direct inversion can leave vertical equilibrium');
run('window.sliceHost.suspend();window.sliceHost.resume();for(let i=0;i<600;i++)stepRope(1/120)');
assert.ok(run('rope[8].y>anchor.y+40'));
run('window.sliceHost.motion(NaN,Infinity);stepRope(.01)');
assert.ok(run('Number.isFinite(rope[8].x)'));
assert.ok(html.includes('target.strokeText(g.ch,0,0)'));
assert.ok(!html.match(/#hud\{[^}]*text-shadow/));
assert.ok(!run('textGlyph.toString().includes("shadowBlur")'));
console.log('PASS: 360° motion, offscreen swing, fixed anchor, hit target, suspend reset, invalid sensor values and no text shadow.');

assert.ok(!ids.has('resultHint')&&!html.includes('下拉右侧挂件，回到聊天'));
assert.ok(ids.has('again')&&html.includes('再来一次'));
run("window.sliceHost.start(Array.from({length:150},(_,i)=>({ch:String.fromCharCode(0x4e00+i),x:130,y:550,size:20})))");
assert.ok(run('introCacheJob!==null'));
run('warmIntroCache()');assert.ok(run('introCacheJob!==null'));assert.ok(run('introCacheJob.next<=40'));
assert.equal(busy,false);
run('while(introCacheJob)warmIntroCache();draw()');
assert.equal(busy,true);assert.equal(run('glyphs.length'),150);
assert.ok(run('glyphs.every(g=>introBitmaps.get(g.bitmapKey))'));
run("window.sliceHost.start([{ch:'鲸',x:130,y:550,size:20}])");assert.equal(run('introCacheJob'),null);
console.log('PASS: bounded atlas warmup, stable source positions, reuse and simplified result card.');


// Floating hit and combo labels use solid fill. The red label still grows and fades.
run("exitGame();mode='playing';spawnAt=Infinity;labels=[{text:'连切 ×8',x:170,y:310,life:.7},{text:'爱意连切 +5',x:195,y:303,life:1.2}];");
run("hitBomb({x:180,y:330,vx:0,vy:0},{x:145,y:330},{x:220,y:330})");
const strokeStart=strokeCalls.length;
let fillStart=fillCalls.length;
run('draw()');
assert.deepEqual(fillCalls.slice(fillStart).map(x=>x.text),['连切 ×8','爱意连切 +5','痛！']);
assert.equal(strokeCalls.length,strokeStart);
const painDraw=fillCalls.at(-1);
assert.equal(painDraw.color,'#ff5863');
assert.equal(painDraw.alpha,1);
run('for(let i=0;i<60;i++)update(1/120);draw()');
const halfway=fillCalls.at(-1);
const fontSize=entry=>Number(entry.font.match(/ ([0-9.]+)px/)[1]);
assert.ok(fontSize(halfway)>fontSize(painDraw),'pain label grows');
assert.ok(fontSize(halfway)<fontSize(painDraw)*1.28,'growth is gradual');
assert.ok(halfway.y<painDraw.y,'original rise is preserved');
assert.ok(halfway.alpha<1,'original fade is preserved');
assert.equal(strokeCalls.length,strokeStart);
run('for(let i=0;i<39;i++)update(1/120);draw()');
assert.ok(run("labels.every(l=>l.text!=='痛！')"),'pain label still expires at 0.8s');

// The love streak caption has solid fill; the reward glyph and countdown still render.
run("exitGame();mode='playing';spawnAt=Infinity;love={x:195,y:330,r:0,active:true,end:time+3};loveHits=5;update(.1)");
fillStart=fillCalls.length;
run('draw()');
assert.deepEqual(fillCalls.slice(fillStart).map(x=>x.text),['爱','连切 ×5']);
assert.deepEqual(strokeCalls.slice(strokeStart),['爱']);
assert.equal(el('subscore').textContent,'爱意连切 · 2.9 秒');
assert.ok(!html.includes('暂无炸弹'));
console.log('PASS: unoutlined labels, red impact growth and fade, and simplified love countdown.');

// A touch unlocks audio, but system Back, activity hide and resume are silent.
let playedVoices=0;
const audioParameter=()=>({value:0,setValueAtTime(){},exponentialRampToValueAtTime(){}});
const audioNode=()=>({gain:audioParameter(),frequency:audioParameter(),Q:audioParameter(),
 connect(){},disconnect(){},start(){playedVoices++;},stop(){}});
sandbox.window.AudioContext=class {
 constructor(){this.state='running';this.currentTime=1;this.sampleRate=48000;this.destination={};}
 createGain(){return audioNode();}
 createOscillator(){return audioNode();}
 createBufferSource(){return audioNode();}
 createBiquadFilter(){return audioNode();}
 createBuffer(){return {getChannelData(){return new Float32Array(14400);}};}
};
run('window.sliceHost.reset()');
const pullEvent=y=>({pointerId:23,clientX:358,clientY:y,preventDefault(){},stopPropagation(){}});
const pendant=el('pendant');
let pendantY=run('pendantPose().y');
pendant.events.pointerdown(pullEvent(pendantY));
pendant.events.pointerup(pullEvent(pendantY));
assert.equal(run('sound.context.state'),'running');
assert.equal(playedVoices,0);
run('window.sliceHost.reset();window.sliceHost.suspend();window.sliceHost.resume();draw()');
assert.equal(playedVoices,0,'system keys and foreground restore must be silent when idle');
run('window.sliceHost.start([])');
let beforeReset=playedVoices;
assert.ok(beforeReset>0,'the game start remains audible');
run('window.sliceHost.reset();draw()');
assert.equal(playedVoices,beforeReset,'Android Back is silent even in a game');
assert.equal(run('sound.voices.size'),0);
run('window.sliceHost.start([])');
beforeReset=playedVoices;
run('window.sliceHost.suspend();window.sliceHost.resume();draw()');
assert.equal(playedVoices,beforeReset,'leaving and restoring an active game never plays a cue');
assert.equal(run('sound.voices.size'),0);
run('window.sliceHost.start([])');
const beforePull=playedVoices;
pendantY=run('pendantPose().y');
pendant.events.pointerdown(pullEvent(pendantY));
pendant.events.pointermove(pullEvent(pendantY+90));
pendant.events.pointerup(pullEvent(pendantY+90));
run('for(let i=0;i<20;i++)update(1/120);draw()');
assert.equal(run('mode'),'idle');
assert.equal(playedVoices,beforePull+1,'explicit pendant exit still plays exactly one cue');
console.log('PASS: silent system Back, suspension and return after touch, explicit pendant exit stays audible.');
