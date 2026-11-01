package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.json.*;

/** Bounded motion3 sampler. Authored data stays in the user's imported package. */
final class DeepseekMotionClip {
    private final Map<String, double[]> curves = new LinkedHashMap<>();
    final float duration;
    DeepseekMotionClip(String json, Set<String> allowed) throws JSONException {
        JSONObject input=new JSONObject(json);
        duration=(float)input.getJSONObject("Meta").getDouble("Duration");
        if(!Float.isFinite(duration) || duration<=0 || duration>30) throw new JSONException("Invalid motion duration");
        JSONArray list=input.getJSONArray("Curves");
        if(list.length()>256) throw new JSONException("Too many motion curves");
        for(int i=0;i<list.length();i++) {
            JSONObject c=list.getJSONObject(i); String id=c.getString("Id");
            if(!"Parameter".equals(c.optString("Target")) || !allowed.contains(id)) continue;
            JSONArray a=c.getJSONArray("Segments");
            if(a.length()<2 || a.length()>12000) throw new JSONException("Invalid motion curve");
            double[] s=new double[a.length()];
            for(int j=0;j<s.length;j++) {s[j]=a.getDouble(j);if(!Double.isFinite(s[j])) throw new JSONException("Nonfinite curve");}
            double last=s[0];
            if(last<0) throw new JSONException("Invalid curve start");
            for(int p=2;p<s.length;) {
                int type=(int)s[p];
                if(s[p]!=type || type<0 || type>3) throw new JSONException("Unknown segment");
                int n=type==1?7:3;
                if(p+n>s.length) throw new JSONException("Truncated segment");
                double end=s[p+n-2];
                if(end<last || end>duration+.01 || (type==1 && (s[p+1]<last || s[p+3]<s[p+1] || s[p+3]>end)))
                    throw new JSONException("Nonmonotonic curve");
                last=end;p+=n;
            }
            curves.put(id,s);
        }
        // Meta.Loop deliberately ignored: enter/return clips are always one-shot.
    }
    Map<String,Float> sample(float time) {
        Map<String,Float> values=new LinkedHashMap<>();
        for(Map.Entry<String,double[]> e:curves.entrySet()) values.put(e.getKey(),sample(e.getValue(),time));
        return values;
    }
    private static float sample(double[] s,float time) {
        double x=s[0],y=s[1];
        if(time<=x) return (float)y;
        for(int p=2;p<s.length;) {
            int type=(int)s[p],n=type==1?7:3;double end=s[p+n-2],value=s[p+n-1];
            if(time<=end) {
                double t=end==x?1:Math.max(0,Math.min(1,(time-x)/(end-x)));
                if(type==0) return (float)(y+(value-y)*t);
                if(type==2) return (float)y;
                if(type==3) return (float)value;
                double lo=0,hi=1;
                for(int j=0;j<22;j++) {double m=(lo+hi)/2;if(bezier(x,s[p+1],s[p+3],end,m)<time) lo=m;else hi=m;}
                return (float)bezier(y,s[p+2],s[p+4],value,(lo+hi)/2);
            }
            x=end;y=value;p+=n;
        }
        return (float)y;
    }
    private static double bezier(double a,double b,double c,double d,double t) {
        double u=1-t;return u*u*u*a+3*u*u*t*b+3*u*t*t*c+t*t*t*d;
    }
}
