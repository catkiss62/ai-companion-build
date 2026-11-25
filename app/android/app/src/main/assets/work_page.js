// Invoked in the isolated work WebView. Only this function maps a model choice
// to a DOM operation. Element references are rebuilt before every action.
(function page(command, arg) {
  const all = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const visible = e => e && e.getClientRects().length && !e.closest('[hidden],[inert],dialog:not([open]),[aria-hidden="true"]') && getComputedStyle(e).visibility !== 'hidden';
  const first = (sel, root) => all(sel,root).find(visible);
  const clean = v => String(v || '').replace(/\s+/g,' ').trim();
  const text = (e, max = 200) => clean(e && (e.innerText || e.textContent)).slice(0,max);
  const root = first('dialog[open],[role="dialog"][aria-modal="true"]') || document;
  const label = e => clean(e.getAttribute('aria-label') || (e.labels && Array.from(e.labels).map(l=>text(l)).join(' ')) ||
    e.getAttribute('title') || text(e) || e.querySelector('img')?.alt || (e.type === 'submit' ? e.value : '')).slice(0,180);
  const selected = e => !!e.checked || e.matches('[aria-pressed=true],[aria-checked=true],.is-selected');
  const resSel = '[data-dere-result],.zdc-quiz-result,[data-quiz-result],.quiz-result,#quiz-result,#result,.result-panel,[data-result-panel],.result-screen';
  const result = all(resSel,root).find(e=>visible(e) && text(e).length>1);
  const eligible = e => visible(e) && !e.disabled && e.getAttribute('aria-disabled') !== 'true';
  const rawControls = all('button,input[type=radio],input[type=checkbox],input[type=submit],[role=radio],[role=checkbox],[role=button],select,canvas',root)
    .filter(e => eligible(e) || (e.matches('input[type=radio],input[type=checkbox]') && !e.disabled && Array.from(e.labels || []).some(visible)));
  const nextPattern = /^(?:下一题|下一頁|下一页|继续|下一步|查看结果|显示结果|看结果|提交(?:答案)?|开始(?:测试|答题)?|next|continue|submit|start|finish|show (?:my )?result|see (?:my )?result|get (?:my )?result)/i;
  const controls = [];
  const add = (e,kind,name,aux) => {if(controls.length<100) controls.push({e,kind,name,aux});};
  const questionBlock = first('.hantei-card,.zdc-quiz-body,.zdc-quiz-card,[data-current-question]') ||
    all('fieldset,[data-question],.question,.quiz-question').find(e=>visible(e) && !all('input:checked,[aria-checked=true],[aria-pressed=true]',e).length) ||
    first('fieldset,[data-question],.question,.quiz-question');
  const qEl = first('.hantei-qtext,.zdc-quiz-q',root) ||
    (questionBlock && (first('legend,[data-prompt],h1,h2,h3,h4,p',questionBlock) || questionBlock)) ||
    first('[data-question-title],.question-title,.question-text,[role=heading]',root);
  const question = text(qEl,450);
  for(const e of rawControls) {
    if(e.closest('nav,header,footer') && !questionBlock?.contains(e)) continue;
    if(questionBlock && !questionBlock.contains(e) && !nextPattern.test(label(e)) && !e.matches('.zdc-tarot-draw')) continue;
    if(e.matches('[data-dere-autoadvance],[data-dere-clear]') || /(?:上一题|上一页|重测|再测|重置|previous|reset|restart|retest|share|分享|登录|sign in)/i.test(label(e))) continue;
    if(e.matches('select')) {
      for(const o of e.options) if(o.value && !o.disabled) add(e,'option',clean(o.text),o.index);
    } else if(e.matches('canvas') && !result) add(e,'canvas',label(e)||'画布');
    else add(e,!e.closest('.zdc-quiz-answers,[role=radiogroup],.dere-scale') && nextPattern.test(label(e)) ? 'next' : 'button',label(e)||'图片选项');
  }
  const originHost = arg.host;
  const href = e => {try{let u=new URL(e.getAttribute('href'),location.href);
    if(u.protocol==='https:' && !u.username && !u.password && (!u.port || u.port==='443') &&
      (u.host===location.host || u.host===originHost)) {u.host=originHost;return u.href;}
  }catch(_){} return '';};
  if(arg.explore && !question && !result) {
    const seen=new Set();
    for(const e of all('main a[href],article a[href],nav a[href],body a[href]')) {
      const u=href(e), name=label(e);
      if(!visible(e)|| !name || !u || seen.has(u) || !/\/(?:quiz|tarot|horoscope|astrolog|compatib|birth-chart|zodiac-sign)/i.test(new URL(u).pathname)) continue;
      seen.add(u); add(e,'link',name,u);
    }
  }
  // Static readings are offered only on an actual detail page, not on a directory.
  const reading = arg.explore && /\/horoscopes?\/.+|\/zodiac-signs?\/.+/.test(location.pathname)
    ? first('main article,article .entry-content,main .entry-content') : null;
  const three = first('#zdc-tarot-three');
  const daily = first('#zdc-tarot-daily');
  const panel = result || (three && text(three) ? three : arg.spread ? null : daily && text(daily) ? daily : reading);
  const summary = panel ? text(panel,2600) : '';
  const title = panel && (text(first('.zdc-quiz-result-name,[data-dere-summary] h3,h2,h3,h1',panel),140) || text(panel,100));
  const controlsInfo=controls.map(({e,kind,name,aux},i)=>({id:i,kind,name,...(kind==='link'?{url:aux}:{}),
    ...(selected(e)||kind==='option' && e.selectedIndex===aux?{selected:true}:{}),...(e.matches('input[type=checkbox],[role=checkbox]')?{multiple:true}:{})}));
  const position=text(first('.hantei-qnum,.zdc-quiz-step,[aria-current=step],.question-number,[data-progress]'),80);
  const section=questionBlock || first('main,article') || document.body;
  const excerpt=text(section,850);
  const key=JSON.stringify([location.pathname+location.search,question,position,title,controlsInfo.map(v=>[v.name,v.selected||false,v.url||'']),question?'':excerpt]);
  const snap={question,position,title,summary,excerpt,controls:controlsInfo,key, page:location.pathname+location.search+location.hash,
    wall:/(?:必须|请先|只能|仅支持).{0,9}(?:打开|下载|安装).{0,6}(?:app|客户端)|(?:must|required to) (?:open|install|download) (?:the |our )?app/i.test(text(root.body||root,1600)) && !question && !title};
  if(command==='read') return snap;
  if(command==='act') {
    if(arg.key!==key) return 'changed';
    if(arg.point) {
      const [x,y]=arg.point;
      if(!(x>=0 && x<1 && y>=0 && y<1)) return 'miss';
      const cx=x*innerWidth, cy=y*innerHeight, hit=document.elementFromPoint(cx,cy);
      if(!hit || !hit.closest('button,label,canvas,input[type=radio],input[type=checkbox],[role=button],[role=radio],[role=checkbox]')) return 'miss';
      for(const type of ['pointerdown','pointerup','click']) hit.dispatchEvent(new (type==='click'?MouseEvent:PointerEvent)(type,{bubbles:true,clientX:cx,clientY:cy}));
      return 'ok';
    }
    const item=controls[arg.id]; if(!item) return 'miss';
    if(item.kind==='link') return item.aux;
    if(item.kind==='canvas') {item.e.scrollIntoView({block:'center'});return 'look';}
    if(item.kind==='option'){
      item.e.selectedIndex=item.aux;
      for(const t of ['input','change']) item.e.dispatchEvent(new Event(t,{bubbles:true}));
    } else item.e.click();
    return 'ok';
  }
  if(command==='focus'){
    (controls.find(c=>c.kind==='canvas' || c.name==='图片选项')?.e || qEl)?.scrollIntoView({block:'center',behavior:'instant'});
    return true;
  }
  if(!panel || !title) return null;
  if(command==='card'){
    const img=panel.querySelector('[data-dere-preview],img[data-result-card],img.result-card,canvas.result-card');
    if(img && (img.naturalWidth || img.width)>150 && (img.naturalHeight||img.height)>100) {
      try{
        let w=img.naturalWidth || img.width, h=img.naturalHeight || img.height;
        for(let scale=Math.min(1,1200/w,2400/h);w*scale>=320;scale*=0.82){
          const c=document.createElement('canvas');c.width=Math.round(w*scale);c.height=Math.round(h*scale);
          c.getContext('2d').drawImage(img,0,0,c.width,c.height);
          const png=c.toDataURL('image/png').split(',')[1]; if(png.length<=349520)return png;
        }
      }catch(_){}
    }
    return null;
  }
  if(command==='tile') {
    const offset=arg.offset || 0;
    if(getComputedStyle(panel).position==='static')panel.style.position='relative';
    const mark=document.createElement('i');
    mark.style.cssText='position:absolute;left:0;top:'+offset+'px;width:1px;height:1px;pointer-events:none';
    panel.appendChild(mark);mark.scrollIntoView({block:'start',inline:'nearest',behavior:'instant'});mark.remove();
    const r=panel.getBoundingClientRect();
    let left=Math.max(0,r.left),right=Math.min(innerWidth,r.right),top=Math.max(0,r.top+offset),bottom=Math.min(innerHeight,r.bottom);
    for(let p=panel.parentElement;p && p!==document.body;p=p.parentElement){
      const st=getComputedStyle(p), b=p.getBoundingClientRect();
      if(/auto|scroll|hidden|clip/.test(st.overflowY)){top=Math.max(top,b.top);bottom=Math.min(bottom,b.bottom);}
    }
    const height=Math.floor(bottom-top);
    if(height<1||right<=left||top-r.top-offset>3) return null;
    return {x:left/innerWidth,y:top/innerHeight,w:(right-left)/innerWidth,h:height/innerHeight,
      offset:offset+height,done:offset+height>=Math.floor(r.height)-1};
  }
})
