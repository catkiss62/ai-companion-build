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
    // Separate instance: same event-duration policy as Caicai, no shared avatar state.
    private final CaicaiEmotionLease emotionLease=new CaicaiEmotionLease();
    private final DeepseekGestures gestures=new DeepseekGestures();
    private final DeepseekParameterPlan plan=new DeepseekParameterPlan();
    private final DeepseekIdleMotion idle=new DeepseekIdleMotion();
    private final DeepseekLeanFocus leanFocus=new DeepseekLeanFocus();
    private final DeepseekViewerFocus viewerFocus=new DeepseekViewerFocus();
    private long avertUntil;
    private final DeepseekGaze gaze=new DeepseekGaze();
    private final DeepseekFootProbe footProbe=new DeepseekFootProbe();
    private final DeepseekBlink blink=new DeepseekBlink();
    private final DeepseekHeadPat pat=new DeepseekHeadPat();
    private volatile DeepseekHitTransform hit=DeepseekHitTransform.INVALID;
    private boolean staticMode,manualPreview;
    private float[] frozenParameters;
    private DeepseekMotionClip auxiliary;
    private float effectTime,previewRootX,previewRootTilt;
    private String baseEmotion="normal",baseEvent="",previewEmotion="normal",speechEmotion="normal",speechCue="",clipStatus="";
    private boolean emotionSuppressed=true;
    private long speechDeadline,speechFaceFade,previewEmotionDeadline;
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
            if(id.equals("@rootX")) rootX=DeepseekParameterPlan.spatialValue(id,value);
            else if(id.equals("@rootTilt")) rootTilt=DeepseekParameterPlan.spatialValue(id,value);
            else set(id,value);
        }
    };
    private final CaicaiSpeechMouthOwner mouthOwner = new CaicaiSpeechMouthOwner();
    private File source;
    private CubismModelSettingJson setting;
    private float smallForm=.55f;
    private boolean small;
    private float form, targetForm, amplitude, anchorX=.5f, anchorY=.21504237f;
    private float left,right,top,bottom,rootX,rootTilt,legPivotX,legPivotY,morphShiftX,morphShiftY;
    private boolean[] legDrawables,eyeWhiteDrawables;
    private final DeepseekLegPivot.Bounds frameLegs=new DeepseekLegPivot.Bounds();
    private final DeepseekLegPivot.Bounds eyeWhites=new DeepseekLegPivot.Bounds();
    private float motionGain=1,motionSpeed=1,pivotSetting=.88f;
    private int legMeshCount;
    private boolean mappedLegPivot;
    private final DeepseekLegPivot.Bounds normalBounds=new DeepseekLegPivot.Bounds();
    private final DeepseekLegPivot.Bounds normalLegs=new DeepseekLegPivot.Bounds();
    private final DeepseekLegPivot.Bounds liveLegs=new DeepseekLegPivot.Bounds();
    private int anchorDrawable=-1, anchorVertex;
    private float[] savedParameters;
    private boolean anchorDirty=true;
    private final CubismMatrix44 mvp=CubismMatrix44.create();

    DeepseekAvatarModel(Context context) {
        android.content.SharedPreferences prefs=context.getSharedPreferences("deepseek_appearance",Context.MODE_PRIVATE);
        float savedSmall=prefs.getFloat("smallForm",.55f);
        smallForm=Float.isFinite(savedSmall)?Math.max(0,Math.min(1,savedSmall)):.55f;
        for(String id:Arrays.asList("key11","key12","Clothes1","Clothes4","MouthPressLipOpen"))
            appearance.put(id,id.equals("MouthPressLipOpen")?mouthStyle(prefs.getFloat(id,-1f)):
                prefs.getFloat(id,id.equals("Clothes1")?1f:0f));
        android.content.SharedPreferences stage=context.getSharedPreferences("deepseek_stage",Context.MODE_PRIVATE);
        anchorX=stage.getFloat("anchorX",.5f); anchorY=stage.getFloat("anchorY",.21504237f);
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
        smallForm=Math.max(model.getParameterMinimumValue(sizeIndex),Math.min(model.getParameterMaximumValue(sizeIndex),smallForm));
        form(small);
        loadPerformanceClips();
        applyBase(); model.update(); bounds();
        bindLegMeshes();
        model.saveParameters();
        savedParameters=new float[model.getParameterCount()];
        frozenParameters=new float[model.getParameterCount()];
        reloadRenderer(width,height,maxTexture,textures,listener);
    }
    private File child(String relative) throws IOException {
        File file=new File(source.getParentFile(),relative).getCanonicalFile();
        if(!file.getPath().startsWith(source.getParentFile().getCanonicalPath()+File.separator) || !file.isFile())
            throw new IOException("DeepSeek资源引用无效："+relative);
        return file;
    }
    private void bindLegMeshes() throws IOException {
        Set<String> ids=new HashSet<>(Arrays.asList("Part114","Part30","Part18"));
        // CDI: normal and small-form eye whites, never the moving pupils.
        Set<String> whiteIds=new HashSet<>(Arrays.asList("Part49","Part36","Part141","Part146"));
        String info=setting.getDisplayInfoFileName();
        if(info!=null && !info.isEmpty()) try {
            org.json.JSONArray parts=new JSONObject(new String(NativeFileLoader.readFile(child(info)),
                java.nio.charset.StandardCharsets.UTF_8)).optJSONArray("Parts");
            if(parts!=null) for(int i=0;i<parts.length();i++) {
                JSONObject part=parts.getJSONObject(i);String name=part.optString("Name");
                if(name.equals("腿") || name.equals("左腿") || name.equals("右腿")) ids.add(part.getString("Id"));
                if(name.equals("眼白") || name.equalsIgnoreCase("sclera") || name.equalsIgnoreCase("eye white")) whiteIds.add(part.getString("Id"));
            }
        } catch(org.json.JSONException error) {throw new IOException("DeepSeek腿部标识无效",error);}
        int[] parents=new int[model.getPartCount()];boolean[] legs=new boolean[parents.length],whites=new boolean[parents.length];
        for(int i=0;i<parents.length;i++) {
            parents[i]=model.getPartParentPartIndex(i);legs[i]=ids.contains(model.getPartId(i).getString());
            whites[i]=whiteIds.contains(model.getPartId(i).getString());
        }
        legDrawables=new boolean[model.getDrawableCount()];eyeWhiteDrawables=new boolean[legDrawables.length];
        for(int d=0;d<legDrawables.length;d++) {
            legDrawables[d]=DeepseekLegPivot.belongsToLeg(model.getDrawableParentPartIndex(d),parents,legs);
            if(legDrawables[d]) legMeshCount++;
            eyeWhiteDrawables[d]=DeepseekLegPivot.belongsToLeg(model.getDrawableParentPartIndex(d),parents,whites);
        }
    }
    private void readBounds(DeepseekLegPivot.Bounds out,boolean legsOnly) {
        out.clear();
        for(int d=0;d<model.getDrawableCount();d++) {
            if(model.getDrawableOpacity(d)<=.01f || (legsOnly && !legDrawables[d])) continue;
            float[] vertices=model.getDrawableVertexPositions(d);
            for(int i=0;i+1<vertices.length;i+=2) out.include(vertices[i],vertices[i+1]);
        }
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
    static float mouthStyle(float value) {return Float.isFinite(value) && value>0?1:-1;}
    float mouthStyle() {return appearance.get("MouthPressLipOpen");}
    void form(boolean small) { this.small=small; targetForm=small?smallForm:0f; }
    void playback(boolean playing) { mouthOwner.playback(playing,System.nanoTime()); }
    void amplitude(float value) { amplitude=Math.max(0,Math.min(1,value)); }
    void configureAnchor(float x,float y) { anchorX=x; anchorY=y; anchorDirty=true; }
    void preview(JSONObject values) {
        staticMode(false);pat.cancel();idle.resetGrass();
        stopPerformance();preview.clear(); previewRootX=0;previewRootTilt=0;
        for(java.util.Iterator<String> it=values.keys();it.hasNext();) {
            String id=it.next();
            float value=(float)values.optDouble(id,Double.NaN);
            if(!Float.isFinite(value)) continue;
            if(id.equals("rootX")) previewRootX=Math.max(-.15f,Math.min(.15f,value));
            else if(id.equals("rootTilt")) previewRootTilt=Math.max(-10,Math.min(10,value));
            else if(CONTROLS.contains(id)) preview.put(id,value);
        }
        manualPreview=!preview.isEmpty() || previewRootX!=0 || previewRootTilt!=0;
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
            else if(id.equals("MouthPressLipOpen")) value=mouthStyle(value);
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
        try {gestures.registerAmbient(readClip("脱捕",DeepseekGestures.IDLE_CHANNELS),
            readClip("狗尾草切回默认手",DeepseekGestures.IDLE_CHANNELS));}
        catch(IOException|org.json.JSONException e) {clipStatus+=" missing:idle-grass";}
    }
    void tune(float gain,float speed) {motionGain=gain;motionSpeed=speed;plan.setGain(gain);plan.setSpeed(speed);idle.tune(gain,speed);}
    void emotion(String event,String value) {emotion(event,value,System.nanoTime());}
    void emotion(String event,String value,long now) {
        if(emotionLease.present(event,value,now)) {baseEvent=event;emotionSuppressed=false;expressions.begin(pose);}
        baseEmotion=emotionLease.emotion();
    }
    float emotionWeight(long now) {return emotionSuppressed?0:emotionLease.weight(now);}
    void performance(JSONObject args,boolean speech) throws org.json.JSONException {
        if(args.optBoolean("_preview")) {staticMode(false);pat.cancel();}
        else if(staticMode || manualPreview || pat.active()) return;
        long now=System.nanoTime();
        String emotion=args.optString("emotion");if(emotion.isEmpty()) emotion=emotionWeight(now)>0?baseEmotion:"normal";
        if(!speech) {
            speechDeadline=0;speechFaceFade=0;speechCue="";
            if(args.optBoolean("_preview")) {
                expressions.begin(pose);
                previewEmotion=emotion;previewEmotionDeadline=now+4_500_000_000L;
            } else {previewEmotionDeadline=0;emotion(baseEvent.isEmpty()?"plan:"+now:baseEvent,emotion);}
        }
        else {speechEmotion=emotion;speechFaceFade=0;speechDeadline=now+700_000_000L;}
        String cue=args.optString("cue","");
        if(speech && cue.equals(speechCue)) return;
        if(speech) {expressions.begin(pose);speechCue=cue;}
        avertUntil=speech && args.optString("delivery").equals("avert")?now+1_300_000_000L:0;
        preview.clear();manualPreview=false;previewRootX=previewRootTilt=0;
        idle.resetGrass();
        boolean animate=!speech || args.optBoolean("animate");
        expressions.trigger(speech && args.optString("face").equals("嫌弃眼")?"":args.optString("face"),animate?args.optString("wink"):"",args.optString("effect"));
        if(animate) {
            String action=args.optString("action");
            if(action.isEmpty() || !gestures.request(action,2.4f)) gestures.stop();
            plan.replace(args.optJSONArray("frames")==null?"[]":args.getJSONArray("frames").toString(),pose);
        } else {plan.release();gestures.stop();}
    }
    void releaseSpeech() {
        releaseSpeech(System.nanoTime());
    }
    void releaseSpeech(long now) {
        if(speechDeadline==0) return;
        speechDeadline=0;speechFaceFade=now+350_000_000L;previewEmotionDeadline=0;speechCue="";
        plan.release();expressions.release();gestures.stop();
    }
    void stopPerformance() {
        speechDeadline=speechFaceFade=0;previewEmotionDeadline=0;speechCue="";expressions.emotion(baseEmotion);
        plan.release();expressions.release();gestures.stop();
    }
    void look(boolean active,float x,float y) {
        if(staticMode) return;
        if(!active) {idle.look(false,0,0);return;}
        float[] aim=gaze.direction(x,y);if(aim!=null) idle.look(true,aim[0],aim[1]);
    }
    void beginPat(boolean held,boolean rare) {
        staticMode(false);
        if(!pat.start(held,rare,pose)) return;
        stopPerformance();plan.clear();expressions.clearTransient();
        preview.clear();manualPreview=false;previewRootX=previewRootTilt=0;idle.resetGrass();
    }
    void releasePat() {pat.release();}
    void previewIdle(boolean grass) {
        staticMode(false);suspend();
        if(grass) gestures.requestAmbient();
    }
    void staticMode(boolean enabled) {
        if(staticMode==enabled) return;
        if(enabled && model!=null && frozenParameters!=null)
            for(int i=0;i<frozenParameters.length;i++) frozenParameters[i]=model.getParameterValue(i);
        staticMode=enabled;
        if(enabled) {stopPerformance();plan.clear();gestures.clear();pat.cancel();idle.clearAttention();blink.reset();}
    }
    void suspend() {
        hit=DeepseekHitTransform.INVALID;
        stopPerformance();plan.clear();gestures.clear();pat.cancel();expressions.clearTransient();
        emotionSuppressed=true;
        preview.clear();manualPreview=false;previewRootX=previewRootTilt=rootX=rootTilt=0;
        idle.clearAttention();idle.resetGrass();blink.reset();
        leanFocus.reset();viewerFocus.reset();avertUntil=0;gaze.clear();
    }
    boolean screenToModel(float x,float y,float[] result) {return hit.inverse(x,y,result);}
    private void animateEffect(String id,float elapsed,float period) {
        Integer i=indices.get(id);if(i==null) return;
        set(id,DeepseekExpressions.cycle(elapsed,period,model.getParameterMinimumValue(i),model.getParameterMaximumValue(i)));
    }
    private void ownMouth() {
        // key6 replaces the authored mouth mesh; parameter lip-sync alone cannot animate it.
        set("key6",0);
        for(String id:MOUTH) {Integer i=indices.get(id);if(i!=null) set(id,model.getParameterDefaultValue(i));}
        set("ParamMouthOpenY",amplitude);
    }
    void update(float delta) {
        morphShiftX=morphShiftY=0;
        delta=Math.max(0,Math.min(.1f,delta));
        boolean speaking=mouthOwner.active(System.nanoTime());
        if(staticMode) {
            for(int i=0;i<frozenParameters.length;i++) model.setParameterValue(i,frozenParameters[i]);
            applyBase();if(speaking) ownMouth();
            if(form>.0001f || anchorDirty) stabilizeMorph(); else model.update();
            return;
        }
        model.loadParameters();rootX=previewRootX;rootTilt=previewRootTilt;
        form+=(targetForm-form)*(1-(float)Math.exp(-delta*6));
        if(Math.abs(targetForm-form)<.0001f) form=targetForm;
        applyBase();
        if(!manualPreview) idle.update(delta,pose);
        Integer breath=indices.get("ParamBreath");
        if(breath!=null) set("ParamBreath",model.getParameterMinimumValue(breath)
            +(model.getParameterMaximumValue(breath)-model.getParameterMinimumValue(breath))*idle.breath());
        applyEmotion(delta,small || form>.05f,pose,System.nanoTime());
        plan.apply(delta,pose);
        if(small || form>.05f) expressions.smallReaction(pose);
        if(!manualPreview) idle.applyAttention(pose,pat.active()?.25f:1);
        blink.update(delta,manualPreview || pat.active() || expressions.reservesEyes(speaking) || plan.reservesEyes(),pose);
        for(Map.Entry<String,Float> e:preview.entrySet()) if(!speaking || !MOUTH.contains(e.getKey())) set(e.getKey(),e.getValue());
        if(manualPreview) {rootX=previewRootX;rootTilt=previewRootTilt;}
        expressions.overlay(pose,speaking);
        effectTime+=delta;
        if(auxiliary!=null && expressions.effect("落泪"))
            auxiliary.sample(effectTime%auxiliary.duration).forEach(this::set);
        // CDI: Param140 is the loading animation. Param55..58 are tail lights,
        // including those embedded in arm clips, and must never enter this owner.
        if(expressions.effect("加载")) animateEffect("Param140",effectTime,1.2f);
        if(expressions.effect("流冷汗")) {
            animateEffect("Sweat1",effectTime,1.8f);animateEffect("Sweat2",effectTime+.9f,1.8f);
        }
        if(speaking && gestures.ambientActive()) gestures.stop();
        if(idle.grassDue(delta,manualPreview || pat.active() || plan.active() || expressions.active()
            || previewEmotionDeadline!=0 || speaking || gestures.busy())) gestures.requestAmbient();
        Map<String,Float> arm=gestures.update(delta);arm.forEach(this::set);
        pat.apply(delta,small || form>.05f,pose);
        if(speaking) ownMouth();
        if(physics!=null) physics.evaluate(model,delta);
        // Reassert every mouth channel, including silent phonemes, after the single physics tick.
        if(speaking) ownMouth();
        viewerFocus.apply(delta,pose,(speaking || plan.active()) && System.nanoTime()>=avertUntil,
            manualPreview || pat.active() || previewEmotionDeadline!=0);
        leanFocus.apply(delta,pose,manualPreview || pat.active());
        if(form>.0001f || anchorDirty) stabilizeMorph(); else model.update();
    }
    void applyEmotion(float delta,boolean small,DeepseekParameterPlan.Target target,long now) {
        if(speechDeadline!=0 && now>speechDeadline) releaseSpeech(speechDeadline);
        if(speechFaceFade!=0 && now>=speechFaceFade) speechFaceFade=0;
        if(previewEmotionDeadline!=0 && now>previewEmotionDeadline) previewEmotionDeadline=0;
        float faceWeight=emotionWeight(now);
        String faceEmotion=baseEmotion;
        if(previewEmotionDeadline!=0) {
            faceEmotion=previewEmotion;faceWeight=Math.max(0,Math.min(1,(previewEmotionDeadline-now)/380_000_000f));
        }
        float speechWeight=speechDeadline!=0?1:speechFaceFade==0?0:
            Math.max(0,Math.min(1,(speechFaceFade-now)/350_000_000f));
        if(speechWeight>0) {faceEmotion=speechEmotion;faceWeight=speechWeight+faceWeight*(1-speechWeight);}
        if(faceWeight<=0) faceEmotion="normal";
        expressions.emotion(faceEmotion);
        expressions.apply(delta,small,target,faceWeight);
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
        readBounds(normalBounds,false);readBounds(normalLegs,true);
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
        // Core may retain unchanged drawable buffers across updates. Never translate
        // those buffers in place: the next neutral evaluation would read its own
        // previous correction and make the shin pivot drift on an otherwise idle rig.
        morphShiftX=x-current[anchorVertex];morphShiftY=y-current[anchorVertex+1];
        readBounds(liveLegs,true);
    }
    void draw(float width,float sceneHeight,float viewportHeight,float scale,float x,float y,float pivot,float[] crop) {
        pivotSetting=pivot;frameLegs.clear();eyeWhites.clear();
        // Read only on GL. Publish an immutable snapshot for UI hit testing below.
        float vl=Float.POSITIVE_INFINITY,vr=Float.NEGATIVE_INFINITY,vt=Float.NEGATIVE_INFINITY,vb=Float.POSITIVE_INFINITY;
        for(int d=0;d<model.getDrawableCount();d++) if(model.getDrawableOpacity(d)>.01f) {
            float[] v=model.getDrawableVertexPositions(d);
            for(int i=0;i<v.length;i+=2) {
                vl=Math.min(vl,v[i]);vr=Math.max(vr,v[i]);vb=Math.min(vb,v[i+1]);vt=Math.max(vt,v[i+1]);
                if(legDrawables[d]) frameLegs.include(v[i],v[i+1]);
                if(eyeWhiteDrawables[d]) eyeWhites.include(v[i],v[i+1]);
            }
        }
        if(!Float.isFinite(vl) || vr<=vl || vt<=vb) {vl=left;vr=right;vt=top;vb=bottom;}
        CubismMatrix44 projection=CubismMatrix44.create();float aspect=width/sceneHeight;
        if(model.getCanvasHeight()/model.getCanvasWidth()<sceneHeight/width) {
            modelMatrix.setWidth(2);projection.scale(1,aspect);
        } else {modelMatrix.setHeight(2);projection.scale(1/aspect,1);}
        mvp.setMatrix(projection);CubismMatrix44.multiply(modelMatrix.getArray(),mvp.getArray(),mvp.getArray());
        float[] stage={scale,0,0,0,0,scale,0,0,0,0,1,0,x,y,0,1};
        CubismMatrix44.multiply(mvp.getArray(),stage,mvp.getArray());
        DeepseekLegPivot.translateModel(mvp.getArray(),morphShiftX,morphShiftY);
        float[] mapped=form>.0001f?DeepseekLegPivot.map(normalBounds,normalLegs,liveLegs,pivot):null;
        mapped=DeepseekLegPivot.withSmallFormAnchor(mapped,liveLegs,pivot,form);
        float[] root;float rootSpan;mappedLegPivot=mapped!=null;
        if(mappedLegPivot) {
            legPivotX=mapped[0];legPivotY=mapped[1];
            rootSpan=Math.abs(mvp.getArray()[0]*mapped[2]);
            root=DeepseekLegPivot.matrix(width,sceneHeight,mvp.transformX(legPivotX),mvp.transformY(legPivotY),
                rootSpan,rootX,rootTilt);
        } else {
            legPivotX=(vl+vr)*.5f;legPivotY=vt-(vt-vb)*pivot;
            rootSpan=Math.abs(mvp.transformX(vr)-mvp.transformX(vl));
            root=CaicaiRootTransform.create(width,sceneHeight,mvp.transformX(vl),mvp.transformX(vr),
                mvp.transformY(vt),mvp.transformY(vb),rootX,rootTilt,pivot).matrix();
        }
        // Probe the same final root; it never changes the pose or the stable morph correction.
        footProbe.capture(mvp.getArray(),root,crop,frameLegs,legPivotX,legPivotY,
            Math.max(-.15f,Math.min(.15f,rootX))*rootSpan);
        CubismMatrix44.multiply(mvp.getArray(),root,mvp.getArray());
        CubismMatrix44.multiply(mvp.getArray(),crop,mvp.getArray());
        gaze.capture(mvp.getArray(),eyeWhites,width,viewportHeight);
        getRenderer().setMvpMatrix(mvp);getRenderer().drawModel();
        hit=new DeepseekHitTransform(mvp.getArray(),vl,vr,vt,vb);
    }
    String trace() { return "deepseek-avatar form="+form+" target="+targetForm+" smallForm="+smallForm+" anchor="+anchorX+","+anchorY+" root="+rootX+","+rootTilt+" legPivot="+(legPivotX+morphShiftX)+","+(legPivotY+morphShiftY)+" rawLegPivot="+legPivotX+","+legPivotY+" morphShift="+morphShiftX+","+morphShiftY+" motionTuning="+motionGain+","+motionSpeed+","+pivotSetting+" "+footProbe.trace()+" "+gaze.trace()+
        " eye="+pose.current("ParamEyeBallX")+","+pose.current("ParamEyeBallY")+
        " eyeOpen="+pose.current("ParamEyeLOpen")+","+pose.current("ParamEyeROpen")+
        " head="+pose.current("AngleX")+","+pose.current("AngleY")+","+pose.current("AngleZ")+
        " body="+pose.current("PositionX")+","+pose.current("PositionY")+","+pose.current("PositionZ")+" mapped="+mappedLegPivot+" legMeshes="+legMeshCount+" leanFocus="+leanFocus.weight()+" face="+expressions.trace()+" gesture="+gestures.trace()+clipStatus+" speech="+(speechDeadline!=0)+" pat="+pat.state()+" idle="+idle.trace()+" static="+staticMode+" preview="+manualPreview; }
    void resizeRenderTarget(int width,int height) { if(getRenderer()!=null) getRenderer().setRenderTargetSize(width,height); }
    void closeModel() {hit=DeepseekHitTransform.INVALID;suspend();delete();}
}
