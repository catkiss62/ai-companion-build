const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
const nodes=new Map();
function element(id){if(nodes.has(id))return nodes.get(id);let el={style:{},textContent:'',classList:{add(){},remove(){}},clientWidth:390,clientHeight:844,events:{},addEventListener(n,f){this.events[n]=f},getBoundingClientRect(){return id==='input'?{left:75,top:700,width:240,height:48}:id==='.heat'?{left:344,top:87,width:28,height:120}:id==='conversation'?{left:16,top:397,width:358,height:270}:{left:0,top:0,width:390,height:844}},querySelectorAll(){return[]},setPointerCapture(){},hasPointerCapture(){return false},releasePointerCapture(){},getContext(){return new Proxy({},{get(t,k){if(k==='createLinearGradient')return()=>({addColorStop(){}});return()=>{}}})}};nodes.set(id,el);return el}
const sandbox={console,Math,Promise,devicePixelRatio:2,Image:class{set src(v){if(this.onload)this.onload()}},requestAnimationFrame(){},setTimeout(){},clearTimeout(){},document:{hidden:false,getElementById:element,querySelector:element,addEventListener(){},createRange(){}},window:{addEventListener(){}},getComputedStyle(){return{fontSize:'17px'}}};
vm.createContext(sandbox);vm.runInContext(fs.readFileSync(__dirname+'/check.js','utf8'),sandbox);const run=s=>vm.runInContext(s,sandbox);
run('loaded=true;resize();');
assert.equal(run('W'),390);
run('startGame();');assert.equal(run('mode'),'intro');
run('for(let i=0;i<240;i++)update(1/120)');assert.equal(run('mode'),'playing');
run("glyphs=[{ch:'鲸',x:150,y:300,size:35,color:'#fff',cut:false,vx:0,vy:0,r:0,vr:0}];bombs=[];cut({x:100,y:300},{x:200,y:300})");assert.equal(run('score'),1);assert.equal(run('particles.length'),8);
run('cut({x:100,y:300},{x:200,y:300})');assert.equal(run('score'),1);
run("bombs=[{x:150,y:300,vx:40,vy:-500,age:time}];cut({x:100,y:300},{x:200,y:300});");assert.equal(run('mode'),'ending');
run('for(let i=0;i<180;i++)update(1/120)');assert.equal(run('victim.landed'),true);assert.equal(run('victim.y'),676);assert.equal(run('mode'),'ending');
run('for(let i=0;i<240;i++)update(1/120)');assert.equal(run('mode'),'over');assert.ok(run('time-victim.hit')>=3.3);assert.equal(element('result').style.display,'block');
run('exitGame()');assert.equal(run('glyphs.length+bombs.length+particles.length'),0);assert.equal(run('victim'),null);
run('drag={x:anchor.x-40,y:anchor.y+140};for(let i=0;i<120;i++)stepRope(1/120);drag=null;for(let i=0;i<2400;i++)stepRope(1/120)');assert.ok(run('Math.abs(rope[8].x-anchor.x)')<1);assert.ok(run('Math.abs(rope[8].y-anchor.y-settings.rope)')<2);
function event(y){return{pointerId:1,clientX:358,clientY:y,preventDefault(){},stopPropagation(){}}}
let y=run('rope[8].y+18');element('pendant').events.pointerdown(event(y));element('pendant').events.pointermove(event(y+90));element('pendant').events.pointerup(event(y+90));assert.equal(run('pending'),'start');run('for(let i=0;i<30;i++)update(1/120)');assert.equal(run('mode'),'intro');
run('exitGame()'); y=run('rope[8].y+18');element('pendant').events.pointerdown(event(y));element('pendant').events.pointermove(event(y+90));element('pendant').events.pointercancel(event(y+90));assert.equal(run('pending'),null);assert.equal(run('mode'),'idle');
run('startGame();resize()');assert.equal(run('mode'),'intro');
run('drag={x:anchor.x,y:anchor.y+148};stepRope(1/120);drag=null;stepRope(1/120)');assert.ok(run('ropeLength')>140);run('for(let i=0;i<240;i++)stepRope(1/120)');assert.ok(run('Math.abs(ropeLength-settings.rope)')<.1);
console.log('PASS: initialization, intro→play, scoring once, fragments, bomb→landing→one-shot→over, exit cleanup, rope stability, pull toggle, cancel, resize.');
// Low chat text must visibly rise before falling, without leaving the viewport.
for(const h of [550,844,1100])for(const fraction of [.52,.7,.83]){
 run(`H=${h}`);const y=h*fraction,v=run(`introVelocity(${y})`),apex=y-v*v/(2*900);
 assert.ok(v<0);assert.ok(apex>=100&&apex<y-24);assert.ok(apex<=h*.4+1);
 const t=-v/900;assert.ok(y+v*t+450*t*t<y-24);assert.ok(y+v*(2*t+.1)+450*(2*t+.1)**2>y);
}
// Audio is optional, rate limited, capped and cleaned on exit/mute.
let starts=0,stops=0;
const param=()=>({value:0,setValueAtTime(){},exponentialRampToValueAtTime(){}});
const node=()=>({gain:param(),frequency:param(),Q:param(),connect(){},disconnect(){},start(){starts++},stop(){stops++}});
sandbox.window.AudioContext=class {constructor(){this.currentTime=1;this.sampleRate=48000;this.state='running';this.destination={}}createGain(){return node()}createOscillator(){return node()}createBufferSource(){return node()}createBiquadFilter(){return node()}createBuffer(){return{getChannelData(){return new Float32Array(14400)}}}resume(){return Promise.resolve()}};
run("sound.unlock();sound.play('cut',1)");assert.equal(starts,2);
run("sound.play('cut',1)");assert.equal(starts,2);
run("sound.context.currentTime+=1;sound.play('hit')");assert.equal(starts,5);
run("for(let i=0;i<30;i++)sound.note(200,100,.1,.1)");assert.equal(run('sound.voices.size'),12);
run('sound.stop()');assert.equal(run('sound.voices.size'),0);
const n=starts;run("sound.enabled=false;sound.play('start')");assert.equal(starts,n);
run("sound.enabled=true;sound.context.state='suspended';sound.play('start')");assert.equal(starts,n);
console.log('PASS: upward launch/apex/fall on 3 viewport heights; optional audio, cooldown, voice cap, stop, mute and suspended context.');
// Reward boundaries, bomb exclusion, scoring throttle and clean next round.
run("exitGame();H=844;W=390;mode='playing';score=100;nextLoveScore=100;spawnAt=time+10;update(.01)");assert.ok(run('love!==null'));assert.equal(run('nextLoveScore'),200);
run("love.x=195;love.y=300;bombs=[{x:195,y:300,age:time}];cut({x:150,y:300},{x:240,y:300})");assert.equal(run('love.active'),true);assert.equal(run('bombs.length'),0);assert.equal(run('score'),101);
run("cut({x:240,y:300},{x:150,y:300});spawnWave()");assert.equal(run('score'),101);assert.equal(run('bombs.length'),0);
run("update(.09);cut({x:150,y:love.y},{x:240,y:love.y})");assert.equal(run('score'),102);
run('for(let i=0;i<370;i++)update(1/120)');assert.equal(run('love'),null);assert.equal(run('nextLoveScore'),200);
run('startGame()');assert.equal(run('nextLoveScore'),100);assert.equal(run('loveHits'),0);
// Deterministic rare wave: five equal-spaced letters and staggered triple bombs.
const oldRandom=Math.random;try{Math.random=()=>0;run("exitGame();mode='playing';wave=3;spawnWave()");assert.equal(run('glyphs.length'),5);assert.equal(run('bombs.length'),3);assert.equal(run('new Set(glyphs.map(g=>g.vy)).size'),1);assert.equal(run('new Set(glyphs.map(g=>g.y)).size'),1);assert.ok(run('bombs[1].age>bombs[0].age&&bombs[2].age>bombs[1].age'));const xs=run('glyphs.map(g=>g.x)');assert.equal(xs[1]-xs[0],xs[4]-xs[3]);}finally{Math.random=oldRandom;}
run("sound.context.state='running';sound.stop();sound.play('hit')");assert.equal(run('sound.effectGain'),2.5);run("sound.play('cut')");assert.equal(run('sound.effectGain'),2);run('exitGame()');assert.equal(run('love'),null);
console.log('PASS: 100-point reward, repeated cuts/cooldown, bomb exclusion, expiry/reset, equal row launch, triple bomb spacing and audio gains.');
// v5 phrases, safe margins and time-scaled reward motion.
assert.equal(run('rowPhrases.length'),50);assert.equal(run('new Set(rowPhrases).size'),50);assert.ok(run('rowPhrases.every(p=>[...p].length===5)'));
try{Math.random=()=>0;run("exitGame();W=390;H=844;mode='playing';spawnWave()");assert.ok(run('rowPhrases.includes(glyphs.map(g=>g.ch).join(""))'));assert.ok(run('glyphs[0].x-16>=50&&glyphs[4].x+16<=W-50'));assert.ok(run('glyphs[1].x-glyphs[0].x<=54'));
run('score=100;nextLoveScore=100;spawnAt=time+10;update(0)');assert.notEqual(run('love.x'),195);assert.equal(run('love.gravity'),400);assert.ok(Math.abs(run('love.vy')/-Math.sqrt(2*900*844*.34)-2/3)<1e-9);
run('love.x=120;love.y=300;sliceLove({x:90,y:300},{x:150,y:300});update(.1)');assert.equal(run('love.x'),120);assert.equal(run('love.y'),300);run('exitGame()');
}finally{Math.random=oldRandom;}
console.log('PASS: 50 unique five-character phrases, row margins, random reward origin, 2/3 time scale and local hover.');
// v6: 3s reward, bounded trail, rotating flight, repeated local impacts.
run("exitGame();mode='playing';score=100;nextLoveScore=100;spawnAt=time+10;update(0);love.x=150;love.y=300;love.vr=1;update(.1)");assert.ok(run('love.r!==undefined&&particles.some(p=>p.alpha===.45)'));run('drawLove()');
run('sliceLove({x:100,y:love.y},{x:200,y:love.y})');assert.ok(Math.abs(run('love.end-time')-3)<1e-9);const firstKick=run('love.kickSign');run('update(.1);sliceLove({x:100,y:love.y},{x:200,y:love.y});drawLove()');assert.equal(run('love.kickSign'),-firstKick);assert.equal(run('love.kickAt'),run('time'));
run('for(let i=0;i<340;i++)update(1/120)');assert.ok(run('love!==null'));run('for(let i=0;i<12;i++)update(1/120)');assert.equal(run('love'),null);run('exitGame()');assert.equal(run('particles.length'),0);
console.log('PASS: gradient drawing, flight rotation/trail, alternating impact response, 3s expiry and cleanup.');
// A suspended context resumes asynchronously; the explicit test must wait.
(async()=>{
 for(const el of nodes.values())el.setAttribute=()=>{};
 let resolveResume;sandbox.visible=true;
 run("sound.enabled=true;sound.context.state='suspended'");
 run('sound.context').resume=()=>new Promise(r=>{resolveResume=()=>{run("sound.context.state='running'");r();}});
 const before=starts;run('testSound()');assert.equal(starts,before);resolveResume();await Promise.resolve();await Promise.resolve();await Promise.resolve();assert.ok(starts>before);
 const template=fs.readFileSync(__dirname+'/template.html','utf8');assert.ok(template.includes("['pointerup','touchend','click']"));
 run("startGame();hitBomb({x:180,y:300,vx:0,vy:0})");assert.equal(element('damage').style.opacity,'1');run('update(.14)');assert.ok(Number(element('damage').style.opacity)>.45);run('update(.15)');assert.equal(Number(element('damage').style.opacity),0);run('exitGame()');assert.equal(element('damage').style.opacity,'0');
 console.log('PASS: asynchronous audio resume then audition, touch-release hooks, single hit flash/fade/exit reset.');
})().catch(e=>{console.error(e);process.exitCode=1});
