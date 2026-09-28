package com.catkiss.senlive2dcompanion;

/** Visible expressions using maid IDs only; opening the mouth remains PCM-owned. */
final class CaicaiFaceMotion {
    private final float[] current = new float[8];
    private static final String[] IDS = {"ParamMouthForm","MOUTHX","SHRUG","ParamBrowLY","ParamBrowRY",
        "ParamEyeLSmile","ParamEyeRSmile","ParamAngleZ"};
    void begin(CaicaiParameterPlan.Target pose) {
        for(int i=0;i<IDS.length;i++) current[i]=i==7 || !pose.accepts(IDS[i]) ? 0 : pose.current(IDS[i]);
    }
    void update(String emotion,float dt,CaicaiParameterPlan.Target target) { update(emotion,dt,target,1); }
    void update(String emotion, float dt, CaicaiParameterPlan.Target target, float weight) {
        float[] wanted;
        switch(emotion) {
            case "happy": wanted=v(1,0,0,.35f,.35f,.9f,.9f,4); break;
            case "excited": wanted=v(1,.2f,0,.85f,.85f,1,1,-7); break;
            case "affection": wanted=v(.85f,0,0,.2f,.2f,.8f,.8f,-10); break;
            case "shy": wanted=v(.55f,-.65f,.2f,.25f,.4f,.6f,.6f,-12); break;
            case "romantic_shy": wanted=v(.65f,.35f,.2f,.3f,.3f,.85f,.85f,-14); break;
            case "flustered": wanted=v(-.6f,.5f,.7f,.9f,.6f,0,0,10); break;
            case "tense": wanted=v(-.6f,0,.8f,-.65f,-.65f,0,0,-5); break;
            case "worried": wanted=v(-.8f,-.4f,.6f,.8f,.5f,0,0,-7); break;
            case "confused": wanted=v(-.2f,.9f,.3f,-.65f,.85f,0,0,-16); break;
            case "helpless": wanted=v(-.65f,-.5f,.9f,.35f,.6f,.2f,.2f,-10); break;
            case "afraid": wanted=v(-.85f,0,.3f,.95f,.95f,0,0,5); break;
            case "angry": wanted=v(-1,0,.85f,-1,-1,0,0,7); break;
            case "sad": wanted=v(-1,0,.75f,.9f,.9f,0,0,-8); break;
            case "disgust": wanted=v(-.85f,-1,.9f,-.55f,.3f,0,0,-11); break;
            case "serious": wanted=v(-.5f,0,.4f,-.55f,-.55f,0,0,0); break;
            case "surprised": wanted=v(-.65f,0,0,1,1,0,0,7); break;
            case "confident": wanted=v(.85f,.9f,0,-.2f,.4f,.45f,.3f,-9); break;
            case "playful": wanted=v(1,.85f,0,-.25f,.55f,1,.6f,13); break;
            case "ashamed": wanted=v(-.8f,-.6f,.8f,.35f,.6f,.9f,.9f,-12); break;
            case "calm": wanted=v(.4f,0,0,.1f,.1f,.35f,.35f,2); break;
            default: wanted=new float[8];
        }
        float mix=1-(float)Math.exp(-Math.max(0,dt)/.16f);
        for(int i=0;i<IDS.length;i++) {
            current[i]+=(wanted[i]-current[i])*mix;
            if(target.accepts(IDS[i])) target.write(IDS[i], i==7 ? target.current(IDS[i])+current[i]*weight : target.current(IDS[i])*(1-weight)+current[i]*weight);
        }
        if(target.accepts("ParamAngleZ2")) target.write("ParamAngleZ2", target.current("ParamAngleZ2")+current[7]*weight);
    }
    private static float[] v(float... values) { return values; }
}
