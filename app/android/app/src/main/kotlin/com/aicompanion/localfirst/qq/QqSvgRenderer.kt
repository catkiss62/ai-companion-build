package com.aicompanion.localfirst.qq

import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.Xml
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayOutputStream
import java.io.StringReader
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore

/** A small, bounded drawing dialect. No WebView, files, URLs, scripts or CSS. */
internal object QqSvgRenderer {
    private val executor = Executors.newSingleThreadExecutor()
    private val slot = Semaphore(1)
    fun reply(svg: String?, result: MethodChannel.Result) {
        if (svg == null || svg.length > 16000 || !slot.tryAcquire()) {
            result.error("sketch_invalid_or_busy", "涂鸦不可用或正在绘制", null); return
        }
        executor.execute {
            try {
                val bytes = render(svg)
                Handler(Looper.getMainLooper()).post { result.success(bytes) }
            } catch (_: Exception) {
                Handler(Looper.getMainLooper()).post { result.error("sketch_invalid", "涂鸦格式不受支持", null) }
            } finally { slot.release() }
        }
    }
    private data class Style(val fill: Int? = Color.BLACK, val stroke: Int? = null, val width: Float = 1f, val opacity: Float = 1f)
    private data class Frame(val tag: String, val attributes: Map<String,String>, val style: Style, val text: StringBuilder = StringBuilder())
    private val tags = setOf("svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "text")
    private val attributes = setOf("viewBox","width","height","x","y","x1","x2","y1","y2","cx","cy","r","rx","ry","d","points","fill","stroke","stroke-width","opacity","transform","font-size","text-anchor","stroke-linecap","stroke-linejoin")
    private val number = Regex("[-+]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?")
    private fun value(raw: String): Float = raw.toFloat().also { require(it.isFinite() && kotlin.math.abs(it)<=8192f) }
    private fun numbers(raw: String): List<Float> {
        require(number.replace(raw, "").all { it.isWhitespace() || it==',' })
        return number.findAll(raw).map { value(it.value) }.toList().also { require(it.size<=1800) }
    }
    private fun color(raw: String): Int? {
        if(raw=="none")return null
        require(raw.matches(Regex("#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8}")) || raw in setOf("black","white","red","blue","green","yellow","gray","grey","cyan","magenta","pink","orange","purple","brown","transparent"))
        val expanded=if(raw.length==4 && raw.startsWith("#")) "#"+raw.drop(1).map { "$it$it" }.joinToString("") else raw
        return when(expanded) { "pink"->0xffffb6c1.toInt();"orange"->0xffffa500.toInt();"purple"->0xff800080.toInt();"brown"->0xffa52a2a.toInt();else->Color.parseColor(expanded) }
    }
    fun render(svg: String): ByteArray {
        require(svg.length<=16000 && svg.trimStart().startsWith("<svg") && !Regex("<!|<\\?|href\\s*=|url\\s*\\(|\\bon[a-z]+\\s*=",RegexOption.IGNORE_CASE).containsMatchIn(svg))
        val parser=Xml.newPullParser();parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES,true);parser.setInput(StringReader(svg))
        val bitmap=Bitmap.createBitmap(512,512,Bitmap.Config.ARGB_8888)
        try {
            val canvas=Canvas(bitmap);canvas.clipRect(0,0,512,512);val stack=ArrayList<Frame>();var count=0;var roots=0
            var event=parser.eventType
            while(event!=XmlPullParser.END_DOCUMENT) {
                when(event) {
                    XmlPullParser.START_TAG -> {
                        val tag=parser.name;require(tag in tags && (parser.namespace.isNullOrEmpty() || parser.namespace=="http://www.w3.org/2000/svg"))
                        require(++count<=220 && stack.size<12)
                        if(stack.isEmpty()) {require(tag=="svg" && ++roots==1)} else require(tag!="svg" && stack.last().tag in setOf("svg","g"))
                        val a=linkedMapOf<String,String>()
                        for(i in 0 until parser.attributeCount) {
                            val name=parser.getAttributeName(i);require(name in attributes && parser.getAttributeNamespace(i).isNullOrEmpty())
                            a[name]=parser.getAttributeValue(i).also { require(it.length<=12000) }
                        }
                        val inherited=stack.lastOrNull()?.style?:Style()
                        val style=Style(a["fill"]?.let(::color)?:if(a["fill"]=="none")null else inherited.fill,
                            a["stroke"]?.let(::color)?:if(a["stroke"]=="none")null else inherited.stroke,
                            a["stroke-width"]?.let(::value)?:inherited.width,
                            inherited.opacity*(a["opacity"]?.let(::value)?:1f))
                        require(style.width in 0f..100f && style.opacity in 0f..1f)
                        canvas.save()
                        if(tag=="svg") {
                            val box=a["viewBox"]?.let(::numbers)?:listOf(0f,0f,512f,512f)
                            require(box.size==4 && box[2]>=16 && box[3]>=16 && box[2]<=4096 && box[3]<=4096)
                            val scale=minOf(512f/box[2],512f/box[3]);canvas.translate((512-box[2]*scale)/2,(512-box[3]*scale)/2);canvas.scale(scale,scale);canvas.translate(-box[0],-box[1])
                        }
                        a["transform"]?.let { transform(canvas,it) }
                        stack.add(Frame(tag,a,style))
                        if(tag!="text" && tag!="g" && tag!="svg")draw(canvas,stack.last())
                    }
                    XmlPullParser.TEXT -> {require(stack.isNotEmpty() || parser.text.isBlank());if(stack.isNotEmpty()) {require(stack.last().tag=="text" || parser.text.isBlank());stack.last().text.append(parser.text);require(stack.last().text.length<=400)}}
                    XmlPullParser.END_TAG -> {require(stack.isNotEmpty());val frame=stack.removeAt(stack.lastIndex);require(frame.tag==parser.name);if(frame.tag=="text")draw(canvas,frame);canvas.restore()}
                    XmlPullParser.DOCDECL, XmlPullParser.ENTITY_REF, XmlPullParser.PROCESSING_INSTRUCTION -> error("unsupported_xml")
                }
                event=parser.nextToken()
            }
            require(roots==1 && stack.isEmpty())
            return ByteArrayOutputStream().use { output -> bitmap.compress(Bitmap.CompressFormat.PNG,100,output);output.toByteArray() }
        } finally {bitmap.recycle()}
    }
    private fun transform(canvas: Canvas, raw: String) {
        val expression=Regex("(translate|scale|rotate)\\s*\\(([^()]*)\\)")
        val matches=expression.findAll(raw).toList();require(matches.size<=6 && expression.replace(raw,"").isBlank())
        for(match in matches) {val n=numbers(match.groupValues[2]);when(match.groupValues[1]) {
            "translate"->{require(n.size in 1..2);canvas.translate(n[0],n.getOrElse(1){0f})}
            "scale"->{require(n.size in 1..2 && n.all { kotlin.math.abs(it)<=20f });canvas.scale(n[0],n.getOrElse(1){n[0]})}
            "rotate"->{require(n.size==1 || n.size==3);if(n.size==1)canvas.rotate(n[0]) else canvas.rotate(n[0],n[1],n[2])}
        }}
    }
    private fun draw(canvas: Canvas, f: Frame) {
        val a=f.attributes;fun n(key:String,default:Float=0f)=a[key]?.let(::value)?:default
        fun paint(color:Int,stroke:Boolean)=Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color=color;alpha=(Color.alpha(color)*f.style.opacity).toInt();style=if(stroke)Paint.Style.STROKE else Paint.Style.FILL;strokeWidth=f.style.width
            strokeCap=when(a["stroke-linecap"]) {"round"->Paint.Cap.ROUND;"square"->Paint.Cap.SQUARE;else->Paint.Cap.BUTT}
            strokeJoin=when(a["stroke-linejoin"]) {"round"->Paint.Join.ROUND;"bevel"->Paint.Join.BEVEL;else->Paint.Join.MITER}
        }
        val path=Path()
        when(f.tag) {
            "path"->path.set(this.path(a["d"]?:""))
            "rect"->{val w=n("width");val h=n("height");require(w>=0 && h>=0);val r=RectF(n("x"),n("y"),n("x")+w,n("y")+h);path.addRoundRect(r,n("rx"),n("ry",n("rx")),Path.Direction.CW)}
            "circle"->{val r=n("r");require(r>=0);path.addCircle(n("cx"),n("cy"),r,Path.Direction.CW)}
            "ellipse"->{val rx=n("rx");val ry=n("ry");require(rx>=0 && ry>=0);path.addOval(RectF(n("cx")-rx,n("cy")-ry,n("cx")+rx,n("cy")+ry),Path.Direction.CW)}
            "line"->{path.moveTo(n("x1"),n("y1"));path.lineTo(n("x2"),n("y2"))}
            "polygon","polyline"->{val points=numbers(a["points"]?:"");require(points.size>=4 && points.size%2==0);path.moveTo(points[0],points[1]);for(i in 2 until points.size step 2)path.lineTo(points[i],points[i+1]);if(f.tag=="polygon")path.close()}
            "text"->{val size=n("font-size",24f);require(size in 1f..160f);for((color,stroke) in listOf(f.style.fill to false,f.style.stroke to true))if(color!=null) {
                val p=paint(color,stroke);p.textSize=size;p.typeface=Typeface.DEFAULT;p.textAlign=when(a["text-anchor"]) {"middle"->Paint.Align.CENTER;"end"->Paint.Align.RIGHT;else->Paint.Align.LEFT};canvas.drawText(f.text.toString(),n("x"),n("y"),p)
            };return}
        }
        f.style.fill?.let {if(f.tag!="line")canvas.drawPath(path,paint(it,false))}
        f.style.stroke?.let {canvas.drawPath(path,paint(it,true))}
    }
    private fun path(raw:String):Path {
        val token=Regex("[MmLlHhVvCcQqZz]|${number.pattern}")
        require(token.replace(raw,"").all { it.isWhitespace() || it==',' })
        val tokens=token.findAll(raw).map { it.value }.toList();require(tokens.size<=1800)
        val path=Path();var i=0;var command=' ';var x=0f;var y=0f;var startX=0f;var startY=0f;var segments=0
        while(i<tokens.size) {
            if(tokens[i].length==1 && tokens[i][0].isLetter())command=tokens[i++][0]
            require(command!=' ' && ++segments<=400)
            val relative=command.isLowerCase();val upper=command.uppercaseChar()
            if(upper=='Z') {path.close();x=startX;y=startY;command=' ';continue}
            val count=when(upper) {'M','L'->2;'H','V'->1;'C'->6;'Q'->4;else->error("path_command")}
            require(i+count<=tokens.size);val n=(0 until count).map { value(tokens[i++]) }
            fun px(j:Int)=n[j]+if(relative)x else 0f
            fun py(j:Int)=n[j]+if(relative)y else 0f
            when(upper) {
                'M'->{val nx=px(0);val ny=py(1);path.moveTo(nx,ny);x=nx;y=ny;startX=x;startY=y;command=if(relative)'l' else 'L'}
                'L'->{val nx=px(0);val ny=py(1);path.lineTo(nx,ny);x=nx;y=ny}
                'H'->{x=px(0);path.lineTo(x,y)}
                'V'->{y=py(0);path.lineTo(x,y)}
                'C'->{val nx=px(4);val ny=py(5);path.cubicTo(px(0),py(1),px(2),py(3),nx,ny);x=nx;y=ny}
                'Q'->{val nx=px(2);val ny=py(3);path.quadTo(px(0),py(1),nx,ny);x=nx;y=ny}
            }
        }
        return path
    }
}
