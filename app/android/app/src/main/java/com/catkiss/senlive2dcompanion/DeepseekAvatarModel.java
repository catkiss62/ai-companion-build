package com.catkiss.senlive2dcompanion;

import android.content.Context;
import android.graphics.BitmapFactory;
import com.live2d.sdk.cubism.framework.CubismModelSettingJson;
import com.live2d.sdk.cubism.framework.math.CubismMatrix44;
import com.live2d.sdk.cubism.framework.model.CubismUserModel;
import com.live2d.sdk.cubism.framework.rendering.android.CubismRendererAndroid;
import org.json.JSONObject;
import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Single authored rig. No Caicai carrier meshes, donor model or parameter aliases. */
final class DeepseekAvatarModel extends CubismUserModel {
    private static final Set<String> CONTROLS = new HashSet<>(Arrays.asList(
        "AngleX","AngleY","AngleZ","PositionX","PositionY","PositionZ","LeanInput",
        "EyeSmile","ParamEyeBallX","ParamEyeBallY","BrowInnerUp","ParamEyeROpen","ParamEyeLOpen",
        "ParamBrowRY","ParamBrowLY","REyeSquint","LEyeSquint","ParamMouthForm","ParamMouthOpenY",
        "JawOpen","TongueOut","MouthX","Mouthpucker","MouthFunnel","MouthPuckerWiden","CheeckPuff"));
    private static final Set<String> MOUTH = DeepseekExpressions.MOUTH;
    private final Map<String,Integer> indices = new HashMap<>();
    private final Map<String,Float> preview = new LinkedHashMap<>();
    private final Map<String,Float> appearance = new LinkedHashMap<>();
    private final DeepseekExpressions expressions=new DeepseekExpressions();
    private final DeepseekGestures gestures=new DeepseekGestures();
    private final DeepseekParameterPlan plan=new DeepseekParameterPlan();
    private DeepseekMotionClip auxiliary;
    private float effectTime,previewRootX,previewRootTilt;
    private String baseEmotion="normal",speechCue="",clipStatus="";
    private long speechDeadline,previewEmotionDeadline;
    private static final Set<String> AUXILIARY=new HashSet<>(Arrays.asList(
        "Param31","Param32","Param27","Param28","RCry","Param29","Param30","LCry"));
    private final DeepseekParameterPlan.Target pose=new DeepseekParameterPlan.Target() {
        public boolean accepts(String id) {return indices.containsKey(id) || id.equals("@rootX") || id.equals("@rootTilt");}
        public float current(String id) {
            if(id.equals("@rootX")) return rootX;
            if(id.equals("@rootTilt")) return rootTilt;
            Integer i=indices.get(id);return i==null?0:model.getParameterValue(i);
        }
        public void write(String id,float value) {
            if(id.equals("@rootX")) rootX=Math.max(-.035f,Math.min(.035f,value));
            else if(id.equals("@rootTilt")) rootTilt=Math.max(-3,Math.min(3,value));
            else set(id,value);
        }
    };
    private final CaicaiSpeechMouthOwner mouthOwner = new CaicaiSpeechMouthOwner();
    private File source;
    private CubismModelSettingJson setting;
    private float smallForm=.8f;
    private boolean small;
    private float form, targetForm, amplitude, anchorX=.5f, anchorY=.25f;
    private float left,right,top,bottom,rootX,rootTilt;
    private int anchorDrawable=-1, anchorVertex;
    private float[] savedParameters;
    private boolean anchorDirty=true;
    private final CubismMatrix44 mvp=CubismMatrix44.create();

    DeepseekAvatarModel(Context context) {
        android.content.SharedPreferences prefs=context.getSharedPreferences("deepseek_appearance",Context.MODE_PRIVATE);
        for(String id:Arrays.asList("key11","key12","Clothes1","Clothes4","MouthPressLipOpen"))
            appearance.put(id,prefs.getFloat(id,id.equals("Clothes1")?1f:0f));
        android.content.SharedPreferences stage=context.getSharedPreferences("deepseek_stage",Context.MODE_PRIVATE);
        anchorX=stage.getFloat("anchorX",.5f); anchorY=stage.getFloat("anchorY",.25f);
    }
    void load(File file,int width,int height,int maxTexture,NativeTextureManager textures,SenRenderer.Listener listener) throws IOException {
        source=file; setting=new CubismModelSettingJson(NativeFileLoader.readFile(file));
        loadModel(NativeFileLoader.readFile(child(setting.getModelFileName())),false);
        if(model==null || modelMatrix==null) throw new IOException("DeepSeek Cubism Core创建失败");
        for(int i=0;i<model.getParameterCount();i++) indices.put(model.getParameterId(i).getString(),i);
        if(!indices.keySet().containsAll(Arrays.asList("AngleX","Clothes2","Movement1","Movement2","Movement3")))
            throw new IOException("DeepSeek参数签名不匹配");
        String physicsFile=setting.getPhysicsFileName();
        if(physicsFile!=null && !physicsFile.isEmpty()) {
            loadPhysics(NativeFileLoader.readFile(child(physicsFile)));
            if(physics==null) throw new IOException("DeepSeek物理文件无法加载");
        }
        Map<String,Float> layout=new HashMap<>();
        if(setting.getLayoutMap(layout)) modelMatrix.setupFromLayout(layout);
        Integer sizeIndex=indices.get("Clothes2");
        if(sizeIndex==null || model.getParameterMinimumValue(sizeIndex)>0 || model.getParameterMaximumValue(sizeIndex)<.8f)
            throw new IOException("DeepSeek大小参数不支持正常0／小豆丁0.8");
        loadPerformanceClips();
        applyBase(); model.update(); bounds();
        model.saveParameters();
        savedParameters=new float[model.getParameterCount()];
        reloadRenderer(width,height,maxTexture,textures,listener);
    }
    private File child(String relative) throws IOException {
        File file=new File(source.getParentFile(),relative).getCanonicalFile();
        if(!file.getPath().startsWith(source.getParentFile().getCanonicalPath()+File.separator) || !file.isFile())
            throw new IOException("DeepSeek资源引用无效："+relative);
        return file;
    }
    void reloadRenderer(int width,int height,int maxTexture,NativeTextureManager textures,SenRenderer.Listener listener) throws IOException {
        deleteRenderer();
        CubismRendererAndroid renderer=(CubismRendererAndroid)CubismRendererAndroid.create(width,height);
        setupRenderer(renderer,1);
        renderer.setDrawableClippingMaskBufferSize(SenRenderOptions.HIGH_PRECISION_MASK_SIZE,SenRenderOptions.HIGH_PRECISION_MASK_SIZE);
        renderer.isUsingHighPrecisionMask(true); renderer.isPremultipliedAlpha(true);
        for(int i=0;i<setting.getTextureCount();i++) {
            File file=child(setting.getTextureFileName(i));
            BitmapFactory.Options dimensions=new BitmapFactory.Options(); dimensions.inJustDecodeBounds=true;
            BitmapFactory.decodeFile(file.getAbsolutePath(),dimensions);
            if(dimensions.outWidth<=0 || dimensions.outHeight<=0 || dimensions.outWidth>maxTexture || dimensions.outHeight>maxTexture)
                throw new IOException("设备无法加载DeepSeek原分辨率贴图："+file.getName());
            listener.onStatus("DeepSeek：上传原分辨率贴图 "+(i+1)+"/"+setting.getTextureCount());
            renderer.bindTexture(i,textures.loadPng(file).id);
        }
    }
    private void set(String id,float value) { Integer i=indices.get(id); if(i!=null && Float.isFinite(value)) model.setParameterValue(i,Math.max(model.getParameterMinimumValue(i),Math.min(model.getParameterMaximumValue(i),value))); }
    private void applyBase() {
        appearance.forEach(this::set);
        set("Clothes3",0); set("Clothes5",0); set("Clothes2",form);
    }
    void form(boolean small) { this.small=small; targetForm=small?smallForm:0f; }
    void playback(boolean playing) { mouthOwner.playback(playing,System.nanoTime()); }
    void amplitude(float value) { amplitude=Math.max(0,Math.min(1,value)); }
    void configureAnchor(float x,float y) { anchorX=x; anchorY=y; anchorDirty=true; }
    void preview(JSONObject values) {
        stopPerformance();preview.clear(); previewRootX=0;previewRootTilt=0;
        for(java.util.Iterator<String> it=values.keys();it.hasNext();) {
            String id=it.next();
            float value=(float)values.optDouble(id,Double.NaN);
            if(!Float.isFinite(value)) continue;
            if(id.equals("rootX")) previewRootX=Math.max(-.15f,Math.min(.15f,value));
            else if(id.equals("rootTilt")) previewRootTilt=Math.max(-10,Math.min(10,value));
            else if(CONTROLS.contains(id)) preview.put(id,value);
        }
    }
    void appearance(JSONObject values) {
        if(values.has("smallForm")) {
            float value=(float)values.optDouble("smallForm",smallForm);
            Integer i=indices.get("Clothes2");
            if(Float.isFinite(value) && i!=null) {
                smallForm=Math.max(model.getParameterMinimumValue(i),Math.min(model.getParameterMaximumValue(i),value));
                if(small) targetForm=smallForm;
            }
        }
        for(String id:appearance.keySet()) if(values.has(id)) {
            float value=(float)values.optDouble(id,Float.NaN);
            if(!Float.isFinite(value)) continue;
            if(id.equals("Clothes1")) value=value<.75f?.5f:1f;
            else if(id.equals("MouthPressLipOpen")) value=Math.max(-1,Math.min(1,value));
            else value=value>=.5f?1:0;
            appearance.put(id,value);
        }
    }
    String parameters() {
        JSONObject result=new JSONObject();
        try { for(String id:CONTROLS) { Integer i=indices.get(id); if(i==null) continue;
            result.put(id,new JSONObject().put("min",model.getParameterMinimumValue(i))
                .put("max",model.getParameterMaximumValue(i)).put("default",model.getParameterDefaultValue(i)));
        } } catch(org.json.JSONException ignored) { }
        return result.toString();
    }
    private DeepseekMotionClip readClip(String name,Set<String> allowed) throws IOException,org.json.JSONException {
        return new DeepseekMotionClip(new String(NativeFileLoader.readFile(child("Animation/"+name+".motion3.json")),java.nio.charset.StandardCharsets.UTF_8),allowed);
    }
    private void loadPerformanceClips() {
        String[][] files={{"狗尾草","狗尾草切换出来","狗尾草切回默认手"},
            {"扶胸","默认手切举手","举手切默认手"},{"竖食指","竖手指切出来动画","竖手指切回默认"}};
        for(String[] f:files) try {gestures.register(f[0],readClip(f[1],DeepseekGestures.CHANNELS),readClip(f[2],DeepseekGestures.CHANNELS));}
        catch(IOException|org.json.JSONException e) {clipStatus+=" missing:"+f[0];}
        try {auxiliary=readClip("IDLE",AUXILIARY);} catch(IOException|org.json.JSONException e) {clipStatus+=" missing:effects";}
    }
    void tune(float gain,float speed) {plan.setGain(gain);plan.setSpeed(speed);}
    void emotion(String value) {baseEmotion=value;expressions.emotion(value);}
    void performance(JSONObject args,boolean speech) throws org.json.JSONException {
        String emotion=args.optString("emotion",baseEmotion);if(emotion.isEmpty()) emotion=baseEmotion;
        if(!speech) {
            speechDeadline=0;speechCue="";
            if(args.optBoolean("_preview")) {
                expressions.emotion(emotion);previewEmotionDeadline=System.nanoTime()+4_000_000_000L;
            } else {previewEmotionDeadline=0;emotion(emotion);}
        }
        else {expressions.emotion(emotion);speechDeadline=System.nanoTime()+700_000_000L;}
        String cue=args.optString("cue","");
        if(speech && cue.equals(speechCue)) return;
        if(speech) speechCue=cue;
        preview.clear();previewRootX=previewRootTilt=0;
        boolean animate=!speech || args.optBoolean("animate");
        expressions.trigger(args.optString("face"),animate?args.optString("wink"):"",args.optString("effect"));
        if(animate) {
            String action=args.optString("action");
            if(action.isEmpty() || !gestures.request(action,2.4f)) gestures.stop();
            plan.replace(args.optJSONArray("frames")==null?"[]":args.getJSONArray("frames").toString(),pose);
        } else {plan.release();gestures.stop();}
    }
    void releaseSpeech() {
        if(speechDeadline==0) return;
        speechDeadline=0;previewEmotionDeadline=0;speechCue="";expressions.emotion(baseEmotion);
        plan.release();expressions.release();gestures.stop();
    }
    void stopPerformance() {
        speechDeadline=0;previewEmotionDeadline=0;speechCue="";expressions.emotion(baseEmotion);
        plan.release();expressions.release();gestures.stop();
    }
    private void animateEffect(String id,float elapsed,float period) {
        Integer i=indices.get(id);if(i==null) return;
        set(id,DeepseekExpressions.cycle(elapsed,period,model.getParameterMinimumValue(i),model.getParameterMaximumValue(i)));
    }
    private void ownMouth() {
        for(String id:MOUTH) {Integer i=indices.get(id);if(i!=null) set(id,model.getParameterDefaultValue(i));}
        set("ParamMouthOpenY",amplitude);
    }
    void update(float delta) {
        delta=Math.max(0,Math.min(.1f,delta));
        model.loadParameters();rootX=previewRootX;rootTilt=previewRootTilt;
        form+=(targetForm-form)*(1-(float)Math.exp(-delta*6));
        if(Math.abs(targetForm-form)<.0001f) form=targetForm;
        applyBase();
        if(speechDeadline!=0 && System.nanoTime()>speechDeadline) releaseSpeech();
        if(previewEmotionDeadline!=0 && System.nanoTime()>previewEmotionDeadline) {
            previewEmotionDeadline=0;expressions.emotion(baseEmotion);
        }
        boolean speaking=mouthOwner.active(System.nanoTime());
        expressions.apply(delta,small || form>.05f,pose);
        plan.apply(delta,pose);
        if(small || form>.05f) expressions.smallReaction(pose);
        for(Map.Entry<String,Float> e:preview.entrySet()) if(!speaking || !MOUTH.contains(e.getKey())) set(e.getKey(),e.getValue());
        expressions.overlay(pose);
        effectTime+=delta;
        if(auxiliary!=null && expressions.effect("落泪"))
            auxiliary.sample(effectTime%auxiliary.duration).forEach(this::set);
        // CDI: Param140 is the loading animation. Param55..58 are tail lights,
        // including those embedded in arm clips, and must never enter this owner.
        if(expressions.effect("加载")) animateEffect("Param140",effectTime,1.2f);
        if(expressions.effect("流冷汗")) {
            animateEffect("Sweat1",effectTime,1.8f);animateEffect("Sweat2",effectTime+.9f,1.8f);
        }
        Map<String,Float> arm=gestures.update(delta);arm.forEach(this::set);
        if(speaking) ownMouth();
        if(physics!=null) physics.evaluate(model,delta);
        // Reassert every mouth channel, including silent phonemes, after the single physics tick.
        if(speaking) ownMouth();
        if(form>.0001f || anchorDirty) stabilizeMorph(); else model.update();
    }
    private void bounds() {
        left=bottom=Float.POSITIVE_INFINITY;right=top=Float.NEGATIVE_INFINITY;
        for(int d=0;d<model.getDrawableCount();d++) if(model.getDrawableOpacity(d)>.01f) {
            float[] v=model.getDrawableVertexPositions(d);
            for(int i=0;i<v.length;i+=2) {left=Math.min(left,v[i]);right=Math.max(right,v[i]);bottom=Math.min(bottom,v[i+1]);top=Math.max(top,v[i+1]);}
        }
        if(!Float.isFinite(left) || right<=left || top<=bottom) {left=-1;right=1;bottom=-1;top=1;}
    }
    private void stabilizeMorph() {
        // Evaluate the same deformed vertex with/without morph, never advance physics twice.
        float[] parameters=savedParameters;
        for(int i=0;i<parameters.length;i++) parameters[i]=model.getParameterValue(i);
        set("Clothes2",0); Integer morphOutput=indices.get("Param34");
        if(morphOutput!=null) model.setParameterValue(morphOutput,model.getParameterDefaultValue(morphOutput));
        model.update();
        if(anchorDirty || anchorDrawable<0) {
            float x=left+(right-left)*anchorX,y=top-(top-bottom)*anchorY,best=Float.POSITIVE_INFINITY;
            for(int d=0;d<model.getDrawableCount();d++) if(model.getDrawableOpacity(d)>.01f) {
                float[] v=model.getDrawableVertexPositions(d);
                for(int i=0;i<v.length;i+=2) {float dist=(v[i]-x)*(v[i]-x)+(v[i+1]-y)*(v[i+1]-y);
                    if(dist<best){best=dist;anchorDrawable=d;anchorVertex=i;}}
            }
            anchorDirty=false;
        }
        float[] neutral=anchorDrawable<0?null:model.getDrawableVertexPositions(anchorDrawable);
        float x=neutral==null?0:neutral[anchorVertex],y=neutral==null?0:neutral[anchorVertex+1];
        for(int i=0;i<parameters.length;i++) model.setParameterValue(i,parameters[i]);
        model.update();
        if(neutral==null) return;
        float[] current=model.getDrawableVertexPositions(anchorDrawable);
        float dx=x-current[anchorVertex],dy=y-current[anchorVertex+1];
        for(int d=0;d<model.getDrawableCount();d++) {float[] v=model.getDrawableVertexPositions(d);
            for(int i=0;i<v.length;i+=2){v[i]+=dx;v[i+1]+=dy;}}
    }
    void draw(float width,float sceneHeight,float scale,float x,float y,float pivot,float[] crop) {
        CubismMatrix44 projection=CubismMatrix44.create();float aspect=width/sceneHeight;
        if(model.getCanvasHeight()/model.getCanvasWidth()<sceneHeight/width) {
            modelMatrix.setWidth(2);projection.scale(1,aspect);
        } else {modelMatrix.setHeight(2);projection.scale(1/aspect,1);}
        mvp.setMatrix(projection);CubismMatrix44.multiply(modelMatrix.getArray(),mvp.getArray(),mvp.getArray());
        float[] stage={scale,0,0,0,0,scale,0,0,0,0,1,0,x,y,0,1};
        CubismMatrix44.multiply(mvp.getArray(),stage,mvp.getArray());
        CaicaiRootTransform root=CaicaiRootTransform.create(width,sceneHeight,mvp.transformX(left),mvp.transformX(right),
            mvp.transformY(top),mvp.transformY(bottom),rootX,rootTilt,pivot);
        CubismMatrix44.multiply(mvp.getArray(),root.matrix(),mvp.getArray());
        CubismMatrix44.multiply(mvp.getArray(),crop,mvp.getArray());
        getRenderer().setMvpMatrix(mvp);getRenderer().drawModel();
    }
    String trace() { return "deepseek-avatar form="+form+" target="+targetForm+" anchor="+anchorX+","+anchorY+" root="+rootX+","+rootTilt+" face="+expressions.trace()+" gesture="+gestures.trace()+clipStatus+" speech="+(speechDeadline!=0); }
    void resizeRenderTarget(int width,int height) { if(getRenderer()!=null) getRenderer().setRenderTargetSize(width,height); }
    void closeModel() { delete(); }
}
