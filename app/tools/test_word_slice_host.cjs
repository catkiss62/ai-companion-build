const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../android/app/src/main/assets/word_slice/index.html'),'utf8');
const ids=new Set([...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1])),nodes=new Map();
const context=new Proxy({},{get(t,k){if(k==='measureText')return()=>({width:24});if(k==='createLinearGradient')return()=>({addColorStop(){}});return()=>{}}});
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

assert.ok(ids.has('resultHint')&&html.includes('下拉右侧挂件，回到聊天'));
run("window.sliceHost.start(Array.from({length:150},(_,i)=>({ch:String.fromCharCode(0x4e00+i),x:130,y:550,size:20})))");
assert.ok(run('introCacheJob!==null'));
run('warmIntroCache()');assert.ok(run('introCacheJob!==null'));assert.ok(run('introCacheJob.next<=40'));
assert.equal(busy,false);
run('while(introCacheJob)warmIntroCache();draw()');
assert.equal(busy,true);assert.equal(run('glyphs.length'),150);
assert.ok(run('glyphs.every(g=>introBitmaps.get(g.bitmapKey))'));
run("window.sliceHost.start([{ch:'鲸',x:130,y:550,size:20}])");assert.equal(run('introCacheJob'),null);
console.log('PASS: bounded atlas warmup, stable source positions, reuse and result-only hint.');
