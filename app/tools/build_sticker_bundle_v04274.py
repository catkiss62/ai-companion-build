"""Rebuild the user's four-pack bundle. Input media remains private and unchanged.

Usage: python build_sticker_bundle_v04274.py EXTRACTED_WORKSPACE OUTPUT_ZIP
Workspace contains original-index.json, personal-001/, official-001/,
dafeiyu-001/, and q-original/. These were extracted from the two user ZIPs.
"""
import hashlib
import json
import re
import sqlite3
import sys
import zipfile
from collections import Counter
from pathlib import Path

from PIL import Image

root, output = Path(sys.argv[1]), Path(sys.argv[2])
packs = json.loads((root / 'original-index.json').read_text())
changes = []
labels = {'happy':'开心','sad':'难过','angry':'生气','shy':'害羞',
          'confused':'疑惑懵圈','surprised':'惊讶','tease':'调侃','cute':'卖萌',
          'love':'亲昵','refuse':'拒绝','food':'吃喝','watch':'围观',
          'greet':'招呼','request':'请求','tired':'疲惫躺平','sleep':'睡觉',
          'work':'工作','sigh':'无语','daily':'日常','color':'成人玩笑'}

animal = {20:'手握拳敲得猫咪缩头',24:'卡通企鹅挠头怀疑自己要长脑子了',
          25:'鼠鼠骑着小摩托赶来啦',26:'熊猫头探出头顶着一个问号',
          27:'狗狗歪头竖耳偷听',28:'猫咪侧过脸一副心虚样',29:'猫咪吐着舌头宣布摆烂',
          30:'猫咪嘴巴变成小圆圈地哇哦',31:'鱼眼镜头下猫咪滑稽地吃东西',
          32:'猫咪满头问号地看着你',33:'猫咪拍地板催着搞快点',34:'猫咪拿着筷子埋头吃泡面',
          35:'猫咪一边吃一边夸张抖动',36:'猫咪被逗着突然轻咬手指',37:'猫咪歪头斜眼说你不对劲',
          38:'猫咪不高兴地转身埋起脸',39:'猫咪生无可恋地劝自己快乐就好',
          40:'猫咪舔着毛还死死盯着镜头',41:'猫咪一爪把另一只猫敲矮十厘米',
          42:'猫咪按住另一只猫当场暴打',43:'猫咪遇到困难就盖被睡大觉',
          44:'猫咪睁大眼睛顶着问号',45:'猫咪突然一个后空翻退出画面',
          46:'猫咪脑袋转了一圈彻底懵了',48:'猫咪闭眼侧头表示看不下去',
          49:'猫咪闭眼躺平直接气晕',57:'熊猫头敷衍地点头说嗯嗯好好好',
          59:'熊猫头提着小猪指给你看',60:'熊猫头端着茶安静看戏',
          64:'卡通鼠鼠闭眼躺着不知道是睡了还是归西了'}
a_tags = ('confused confused tease tease sad sad request sad food tease happy happy request request happy color angry color color angry refuse tease tease confused greet confused watch shy tired surprised food confused request food food cute confused angry sigh watch angry angry sleep confused tease confused color sigh angry daily happy sigh daily greet color watch sigh daily tease watch angry angry surprised sleep tired happy sigh confused').split()
assert len(a_tags) == 68
b_captions = {
 1:'Q版动漫猫猫头表情愤怒，配文“小笔载治 别让我逮到你”，表达生气和玩笑式威胁',
 35:'Q版动漫猫猫头脑袋空空，一脸茫然，配文“脑袋空空哒——”',
 36:'Q版动漫猫猫头贴在白色猫咪身上，配文“小可爱看小笨蛋”，带有调侃的情绪',
 39:'Q版动漫猫猫头喊着打劫，配文“给我忙尼”，表达可爱又有点小蛮横地讨钱',
 50:'Q版动漫猫猫头贴在猫咪身上，闭眼鼓着脸，表情气鼓鼓，在闹小脾气',
 55:'Q版动漫猫猫头没精打采，配文“朋友们早上好 不好也可以 随便你”，敷衍地打招呼',
 82:'Q版动漫猫猫头躺在枕头上，配文“小猫躺了下去”，表达慵懒卖萌、想睡觉',
 90:'Q版动漫猫猫头表情急切，配文“我宣布 下班!!”，表达想结束工作、下班的心情',
}
b_tags = {2:'tease',4:'sigh',6:'sigh',7:'tease',15:'angry',16:'sigh',17:'happy',
 19:'shy',21:'shy',23:'shy',31:'sigh',32:'cute',33:'confused',34:'sigh',35:'confused',
 36:'tease',37:'tease',38:'request',39:'request',43:'shy',46:'cute',48:'happy',49:'love',
 50:'angry',51:'sigh',52:'sigh',53:'cute',55:'greet',56:'request',57:'shy',65:'surprised',
 66:'confused',67:'food',68:'sigh',69:'sigh',70:'surprised',76:'love',79:'angry',92:'daily'}
d_tags = {2:'food',6:'confused',7:'love',9:'love',11:'greet',12:'tired',15:'sigh',16:'work',
 17:'surprised',20:'refuse',23:'cute',24:'request',28:'sigh',29:'tease',30:'tease',31:'tease',
 32:'tease',33:'food',34:'food',35:'tease',36:'tease',40:'happy',41:'request',42:'tease',
 45:'tired',46:'confused',48:'surprised',49:'sad'}
legacy = {'baka':'tease','fool':'tease','like':'love','meow':'cute','givemoney':'request',
          'see':'watch','cpu':'confused','morning':'greet','reply':'daily'}

for pack in packs:
    pid = pack['manifest']['id']; db = sqlite3.connect(root/pid/'index.db')
    for i,row in enumerate(pack['rows'],1):
        caption, tag, keywords = row['caption'], legacy.get(row['tag'],row['tag']), row['keywords']
        if pid == 'personal-001': caption=animal.get(i,caption);tag=a_tags[i-1]
        if pid == 'official-001':
            caption=b_captions.get(i,caption);tag=b_tags.get(i,tag)
            keywords=keywords.replace('柴郡','Q版动漫猫猫头').replace('碧蓝航线','')
            if i==50: keywords='生气 气鼓鼓 闹脾气 不高兴 哼'
        if pid == 'dafeiyu-001': caption='鲸鱼娘-'+caption;tag=d_tags.get(i,tag)
        if caption!=row['caption'] or tag!=row['tag'] or keywords!=row['keywords']:
            changes.append({'pack':pid,'path':row['path'],'before':row['caption'],'after':caption,'old_tag':row['tag'],'tag':tag})
        db.execute('UPDATE memes SET caption=?,tag=?,keywords=? WHERE path=?',(caption,tag,keywords,row['path']))
    db.commit();db.close()
    m=pack['manifest'];m['name']={'personal-001':'表情包A','official-001':'表情包B','dafeiyu-001':'大肥鱼'}[pid]
    m['version']='2.0.0';m['categories']={k:{'name':v} for k,v in labels.items()};
    (root/pid/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))

qroot=root/'q-whale-001';(qroot/'memes').mkdir(parents=True,exist_ok=True)
qpaths=sorted((root/'q-original').iterdir(),key=lambda x:x.name)
# Human-reviewed semantic mapping by the supplied filename. Ambiguous poses were visually checked.
qtags=('cute tease love watch request sad cute food watch food surprised angry daily food sleep tease daily love tease sad surprised shy daily confused happy love request sleep confused angry love tease request love sigh love sad color daily angry daily color sleep love angry cute sigh tired tired tired happy love food love happy food sad happy love happy').split()
assert len(qtags)==len(qpaths)==60
qdb=sqlite3.connect(qroot/'index.db');qdb.execute('DROP TABLE IF EXISTS memes');qdb.execute('CREATE TABLE memes(path TEXT PRIMARY KEY,tag TEXT,file_name TEXT,caption TEXT,keywords TEXT,tone_scope TEXT,intensity INTEGER,enabled INTEGER)')
for i,(src,tag) in enumerate(zip(qpaths,qtags),1):
    text=re.sub(r'^鲸鱼娘[-，]?','',src.stem)
    text={'(*^ω^*)表情':'闭眼脸红，双手托脸卖萌，(*^ω^*)表情','小喇叭':'拿着小喇叭大声喊话','趴着':'趴着抬眼看你','头锥':'用头撞过来'}.get(text,text)
    name=f'{i:04d}{src.suffix.lower()}'; path='memes/'+name
    (qroot/path).write_bytes(src.read_bytes())
    qdb.execute('INSERT INTO memes VALUES(?,?,?,?,?,?,?,?)',(path,tag,name,'Q版鲸鱼娘-'+text,labels[tag],'nsfw' if tag=='color' else 'general',1,1))
qdb.commit();qdb.close()
(qroot/'manifest.json').write_text(json.dumps({'id':'q-whale-001','name':'Q版鲸鱼娘','version':'1.0.0','license':'personal-use/user-provided','description':'用户人工描述，Q版鲸鱼娘60张。','sticker_count':60},ensure_ascii=False,indent=2))

output.parent.mkdir(parents=True,exist_ok=True)
order=['personal-001','official-001','q-whale-001','dafeiyu-001'];summary={}
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as outer:
    for index,pid in enumerate(order,1):
        proot=root/pid;child=root/f'{index:02d}-{pid}.zip'
        db=sqlite3.connect(proot/'index.db');rows=list(db.execute('select path,tag,caption from memes'));db.close()
        assert len({r[0] for r in rows})==len(rows)
        for path,tag,caption in rows:
            assert tag in labels and 0<len(caption)<=240
            with Image.open(proot/path) as image:
                image.seek(getattr(image,'n_frames',1)-1);image.load()
        with zipfile.ZipFile(child,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for p in [proot/'manifest.json',proot/'index.db',*[proot/r[0] for r in rows]]:
                z.write(p,p.relative_to(proot).as_posix())
        outer.write(child,child.name)
        summary[pid]={'records':len(rows),'categories':dict(Counter(r[1] for r in rows))}
# Check every old media file kept its original bytes, including disabled historical entries.
with zipfile.ZipFile(root.parent/'upload/AI-Companion-Sticker-Bundle.zip') as orig:
    import io
    for n in orig.namelist():
        with zipfile.ZipFile(io.BytesIO(orig.read(n))) as child:
            mn=next(x for x in child.namelist() if x.endswith('manifest.json'));pid=json.loads(child.read(mn))['id'];prefix=mn[:-13]
            for n2 in child.namelist():
                if n2.startswith(prefix+'memes/') and not n2.endswith('/'):
                    assert child.read(n2)==(root/pid/n2[len(prefix):]).read_bytes()
(root/'changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2))
(root/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({'summary':summary,'changes':len(changes),'zip':str(output),'sha256':hashlib.sha256(output.read_bytes()).hexdigest()},ensure_ascii=False))
