"""Build the offline Android overlay from the phone-reviewed v6 prototype.
The prototype stays runnable for regression; host adaptation contains no API calls.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parent.parent
SRC=ROOT/'tools/word_slice'
s=(SRC/'template.html').read_text()
script=s.split('<script>',1)[1].split('</script>',1)[0]
script=script.replace('__ASSETS__',(SRC/'assets.json').read_text())
script=script.replace("const images={};", "let hostLayout={anchorX:0,panelTop:0,floor:0,hudTop:0},hostGlyphs=[];let hostReady=false,startWaiting=false;let lastPendantReport=-1;const images={};")
script=script.replace("function floorY(){return rect($('input')).y}","function floorY(){return hostLayout.floor||H-100}")
script=re.sub(r"const heat=rect\(document.querySelector\('\.heat'\)\),chat=rect\(\$\('conversation'\)\);anchor=\{x:heat.x\+heat.w/2,y:chat.y-54\};initRope\(\);\$\('hint'\).style.top=\(anchor.y\+35\)\+'px';", "anchor={x:hostLayout.anchorX,y:hostLayout.panelTop};initRope();",script)
a=script.index('function captureText()');b=script.index('function lockUi',a)
script=script[:a]+"function captureText(){return hostGlyphs.map(g=>({...g,delay:rand(.12,.38),vx:rand(-50,50),vy:introVelocity(g.y),r:0,vr:rand(-2,2),color:'#fff',intro:true,cut:false}));}\n"+script[b:]
script=script.replace("function startGame(){if(!loaded)return;", "function startGame(){if(!loaded||!hostReady||startWaiting)return;startWaiting=true;NativeSlice.requestStart();}\nfunction startCapturedGame(){if(!loaded)return;")
script=script.replace("function lockUi(value){for(const el of app.querySelectorAll('header,nav,#composer,#conversation'))el.inert=value;}", "function lockUi(value){NativeSlice.setPlaying(value);}")
script=script.replace("function exitGame(){love=null", "function exitGame(){startWaiting=false;cancelHostPointers();love=null")
script=script.replace("$('avatar').src=ASSETS['默认动作'].frames[0];resize();requestAnimationFrame(frame)","resize();NativeSlice.ready();requestAnimationFrame(frame)")
script=script.replace(".catch(()=>toast('素材加载失败，请重新打开文件'))", ".catch(()=>NativeSlice.failed())")
# No prototype controls, instruction text or trial toasts in the real UI.
a=script.index('function testSound()');b=script.index('// Touch pointerdown',a);script=script[:a]+script[b:]
script=re.sub(r"function toast\(msg\)\{.*?\}\n",'function toast(msg){}\n',script)
# Keep audio startup/release hooks but remove the test-only status button implementation.
a=script.index(' status(message){');b=script.index('\n',a)
script=script[:a]+ ' status(){},'+script[b:]
script=re.sub(r"\$\('sound'\)\.onclick=.*?;\n",'',script)
# Report the centre of the actual rotated sprite to Android hit testing.
pendant_position="pendant.style.top=(pose.y-32)+'px';"
assert script.count(pendant_position)==1
script=script.replace(pendant_position, pendant_position+'''
 if(time-lastPendantReport>.032){
  lastPendantReport=time;NativeSlice.pendantPosition(pose.x,pose.y);
 }''')
# Native calls are JSON-encoded; text is never evaluated as code.
script+='''
function cancelHostPointers(){for(const [element,id] of [[pendant,pullPointer],[$('gesture'),activePointer]]){if(id!==null&&element.hasPointerCapture(id))element.releasePointerCapture(id);}drag=null;pullPointer=null;pullStart=null;activePointer=null;swipeSound.reset();pending=null;trail=[];}
window.sliceHost={
 motion(x,y,reset=false){
  const valid=Number.isFinite(x)&&Number.isFinite(y)&&!reset;
  targetRopeGravity.x=valid?clamp(x,-1,1):0;
  targetRopeGravity.y=valid?clamp(y,-1,1):1;
 },
 configure(layout){hostLayout=layout;hostReady=true;$('hud').style.top=(layout.hudTop+8)+'px';resize();},
 start(snapshot){startWaiting=false;if(!hostReady||!visible)return;hostGlyphs=snapshot;startCapturedGame();},
 reset(){exitGame();sound.stop();},
 suspend(){ropeGravity.x=targetRopeGravity.x=0;ropeGravity.y=targetRopeGravity.y=1;exitGame();sound.stop();visible=false;last=0;acc=0;},
 resume(){visible=true;last=0;acc=0;},
};
window.addEventListener('error',()=>NativeSlice.failed());
window.addEventListener('unhandledrejection',()=>NativeSlice.failed());
setInterval(()=>NativeSlice.heartbeat(),500);
'''
# Use only gameplay CSS; old mock DOM, hints and sound controls are absent.
css='''*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent!important;color:#f4f2fb;font-family:system-ui;user-select:none;touch-action:none}#app{position:relative;width:100%;height:100%;overflow:hidden}button{font:inherit;color:inherit;border:0;background:none}#canvas{position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:5}#gesture{position:absolute;inset:0;display:none;z-index:6;touch-action:none}.playing #gesture{display:block}#pendant{position:absolute;width:64px;height:64px;z-index:20;touch-action:none;outline:none}#hud{position:absolute;left:20px;z-index:8;display:none;pointer-events:none}#score{font-size:30px;font-weight:800}#hud small{margin-left:5px}#subscore{font-size:11px;margin-top:3px;color:#d0c7e6}.playing #hud{display:block}#result{display:none;position:absolute;left:50%;top:48%;transform:translate(-50%,-50%);width:240px;padding:22px;border:1px solid #b7a0dc80;border-radius:22px;background:#252439ed;text-align:center;z-index:15;box-shadow:0 12px 45px #0004}#result h2{font-size:19px;color:#ffd1df;margin:0 0 10px}#resultHint{font-size:12px;color:#d0c7e6;margin:12px 0 0}#again{padding:10px 20px;border-radius:20px;background:#cdb4f2;color:#302640;font-weight:700}#damage{position:absolute;inset:0;pointer-events:none;z-index:9;opacity:0;background:radial-gradient(ellipse at center,#ff526320,#e125505c);transition:opacity .28s ease-out}'''
html='<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>'+css+'</style></head><body><main id="app"><div id="damage"></div><canvas id="canvas"></canvas><div id="gesture"></div><button id="pendant" aria-label="下拉小鲸鱼进入或退出切字游戏"></button><div id="hud"><span id="score">0</span><small>分</small><div id="subscore"></div></div><div id="result"><h2>呜，切到我了…</h2><p id="resultScore"></p><button id="again">再来一次</button><p id="resultHint">下拉右侧挂件，回到聊天</p></div></main><script>'+script+'</script></body></html>'
out=ROOT/'android/app/src/main/assets/word_slice/index.html';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(html)
if __name__=='__main__':print('Built',out.relative_to(ROOT))
