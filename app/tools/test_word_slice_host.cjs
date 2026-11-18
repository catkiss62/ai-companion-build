const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../android/app/src/main/assets/word_slice/index.html'),'utf8');
const ids=new Set([...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1])),nodes=new Map();
const context=new Proxy({},{get(t,k){if(k==='createLinearGradient')return()=>({addColorStop(){}});return()=>{}}});
function el(id){assert.ok(ids.has(id),'No dangling DOM reference: '+id);if(!nodes.has(id))nodes.set(id,{style:{},textContent:'',classList:{add(){},remove(){}},clientWidth:390,clientHeight:844,events:{},addEventListener(k,f){this.events[k]=f},getBoundingClientRect(){return {left:0,top:0,width:390,height:844}},querySelectorAll(){return []},setPointerCapture(){},hasPointerCapture(){return false},releasePointerCapture(){},getContext(){return context}});return nodes.get(id)}
let requests=0,busy=false,failures=0;
const sandbox={console,Math,Promise,devicePixelRatio:2,Image:class{set src(v){queueMicrotask(()=>this.onload?.())}},requestAnimationFrame(){},setTimeout(){},clearTimeout(){},setInterval(){},document:{hidden:false,getElementById:el,querySelectorAll(){return[]},addEventListener(){}},window:{addEventListener(){}},NativeSlice:{ready(){},failed(){failures++},heartbeat(){},requestStart(){requests++},setPlaying(v){busy=v}}};
vm.createContext(sandbox);vm.runInContext(html.split('<script>')[1].split('</script>')[0],sandbox);const run=x=>vm.runInContext(x,sandbox);
run("loaded=true;window.sliceHost.configure({anchorX:358,panelTop:390,floor:700,hudTop:72})");
assert.equal(run('anchor.y'),390);run('startGame()');assert.equal(requests,1);assert.equal(run('mode'),'idle');
run("window.sliceHost.start([{ch:'鲸',x:130,y:550,size:20}])");assert.equal(busy,true);assert.equal(run('glyphs[0].x'),130);assert.equal(run('glyphs[0].ch'),'鲸');
run('for(let i=0;i<250;i++)update(1/120)');assert.equal(run('mode'),'playing');run('score=100;update(.01);draw()');assert.ok(run('love!==null'));
run('window.sliceHost.suspend()');assert.equal(busy,false);assert.equal(run('visible'),false);assert.equal(run('glyphs.length+bombs.length+particles.length'),0);
run('window.sliceHost.configure({anchorX:358,panelTop:230,floor:700,hudTop:72});window.sliceHost.resume()');assert.equal(run('anchor.y'),230);assert.equal(run('visible'),true);
assert.ok(!ids.has('sound')&&!ids.has('audioTest')&&!ids.has('hint')&&!ids.has('conversation'));assert.equal(failures,0);
console.log('PASS: actual bundled HTML, all DOM refs, native capture handshake, real glyph origin, moving anchor, reward draw, pause cleanup and removed controls.');
