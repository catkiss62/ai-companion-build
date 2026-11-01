package com.catkiss.senlive2dcompanion;

import java.util.Random;

/** Natural blinks multiply the current emotional eyes, below explicit expressions and pats. */
final class DeepseekBlink {
    private static final String[] EYES={"ParamEyeLOpen","ParamEyeROpen"};
    private final Random random;
    private float wait,age=-1;
    private boolean blocked;
    DeepseekBlink() {this(new Random());}
    DeepseekBlink(Random random) {this.random=random;reset();}
    void reset() {age=-1;wait=2.8f+random.nextFloat()*3.7f;}
    void update(float dt,boolean reserved,DeepseekParameterPlan.Target target) {
        dt=Math.max(0,Math.min(.1f,dt));
        if(reserved) {if(!blocked) reset();blocked=true;return;}
        blocked=false;
        if(age<0) {wait-=dt;if(wait>0) return;age=0;}
        age+=dt;
        float close=age<.075f?age/.075f:age<.115f?1:Math.max(0,1-(age-.115f)/.14f);
        for(String id:EYES)
            if(target.accepts(id)) target.write(id,target.current(id)*(1-close));
        if(age>=.255f) reset();
    }
}
