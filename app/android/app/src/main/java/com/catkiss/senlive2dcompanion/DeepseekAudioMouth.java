package com.catkiss.senlive2dcompanion;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

/** Small, local acoustic shape hints, not a phoneme recognizer. Read-only PCM;
 * the speaker and its playback clock are never resampled or delayed for analysis. */
public final class DeepseekAudioMouth {
    public static final class Shape {
        public final float width, opening;
        private Shape(float width,float opening) {this.width=width;this.opening=opening;}
    }
    public static final Shape NEUTRAL=new Shape(0,1);
    private static final int LIMIT=512;
    private final double[] real=new double[LIMIT],imaginary=new double[LIMIT];
    private final double[] power=new double[LIMIT/2+1],envelope=new double[LIMIT/2+1];

    /** One approximately 40 ms window, indexed in PCM frames (all channels included).
     * The first channel matches the existing amplitude path. Very short chunks,
     * silence, non-finite PCM and unvoiced/noisy spectra fall back to RMS only. */
    public Shape analyze(byte[] bytes,int offset,int frames,int sampleRate,int channels,int bits,int format) {
        if(bytes==null || offset<0 || frames<1 || sampleRate<8000 || sampleRate>192000 || channels<1 ||
            !(format==1 && bits==16 || format==3 && bits==32)) return NEUTRAL;
        long frameBytes=(long)channels*(bits/8);
        if(offset+(long)frames*frameBytes>bytes.length || frames<sampleRate/50) return NEUTRAL;
        int stride=Math.max(1,(frames+LIMIT-1)/LIMIT);
        int count=frames/stride;
        if(count<128) return NEUTRAL;
        int size=1;while(size<count) size<<=1;
        Arrays.fill(real,0);Arrays.fill(imaginary,0);
        ByteBuffer pcm=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
        double mean=0,energy=0;
        // Box-average only the analysis input when capping its size. This does
        // not touch the byte buffer or the PCM written to AudioTrack.
        for(int i=0;i<count;i++) {
            double sum=0;
            for(int j=0;j<stride;j++) {
                int at=(int)(offset+((long)i*stride+j)*frameBytes);
                double v=format==3?pcm.getFloat(at):pcm.getShort(at)/32768.0;
                if(!Double.isFinite(v)) return NEUTRAL;
                sum+=v;
            }
            real[i]=sum/stride;mean+=real[i];energy+=real[i]*real[i];
        }
        mean/=count;
        if(energy/count-mean*mean<.000009) return NEUTRAL;
        // Pre-emphasis compensates spectral tilt before finding broad resonances.
        double previous=0;
        for(int i=0;i<count;i++) {
            double value=real[i]-mean;
            real[i]=(value-.97*previous)*(.54-.46*Math.cos(2*Math.PI*i/(count-1)));
            previous=value;
        }
        fft(size);
        double hz=(double)sampleRate/stride/size;
        int last=size/2;
        double total=0,high=0,logSum=0,flatSum=0;int flatCount=0;
        for(int i=0;i<=last;i++) {
            power[i]=real[i]*real[i]+imaginary[i]*imaginary[i];
            double f=i*hz;
            if(f>=180 && f<=5000) {total+=power[i];if(f>=3500) high+=power[i];}
            if(f>=200 && f<=Math.min(5000,last*hz)) {
                // Measure flatness without the pre-emphasis tilt; otherwise
                // broadband noise can masquerade as a narrow vowel resonance.
                double raw=power[i]/(1+.97*.97-2*.97*Math.cos(2*Math.PI*i/size));
                flatSum+=raw;logSum+=Math.log(Math.max(1e-20,raw));flatCount++;
            }
        }
        if(total<1e-12 || flatCount==0 || high>total*.6 ||
            Math.exp(logSum/flatCount)/(flatSum/flatCount+1e-20)>.45) return NEUTRAL;
        int radius=Math.max(1,(int)Math.round(85/hz));
        for(int i=0;i<=last;i++) {
            double sum=0;int low=Math.max(0,i-radius),upper=Math.min(last,i+radius);
            for(int j=low;j<=upper;j++) sum+=power[j];
            envelope[i]=sum/(upper-low+1);
        }
        int low=Math.max(1,(int)Math.ceil(220/hz));
        int upper=Math.min(last-1,(int)Math.floor(1050/hz));
        double peak=0;for(int i=low;i<=upper;i++) peak=Math.max(peak,envelope[i]);
        if(peak<1e-12) return NEUTRAL;
        int first=-1;
        for(int i=low;i<=upper;i++) {
            if(envelope[i]>=peak*.3 && envelope[i]>=envelope[i-1] && envelope[i]>=envelope[i+1]) {first=i;break;}
        }
        if(first<0) return NEUTRAL;
        int second=-1;
        for(int i=Math.max((int)Math.ceil(750/hz),first+(int)Math.ceil(250/hz));i<=Math.min(last-1,(int)(3200/hz));i++)
            if(second<0 || envelope[i]>envelope[second]) second=i;
        if(second<0 || envelope[second]<peak*.12) return NEUTRAL;
        // These continuous hints use the rig's actual width control. MouthFunnel
        // is a teeth slit on this model, so it must not be treated as an O vowel.
        float width=(float)Math.max(-.55,Math.min(.45,(second*hz-1700)/1800));
        float opening=(float)Math.max(.78,Math.min(1.12,.78+(first*hz-220)*.0005));
        return new Shape(width,opening);
    }

    private void fft(int size) {
        for(int i=1,j=0;i<size;i++) {
            int bit=size>>1;for(; (j&bit)!=0;bit>>=1) j^=bit;j^=bit;
            if(i<j) {double v=real[i];real[i]=real[j];real[j]=v;}
        }
        for(int length=2;length<=size;length<<=1) {
            double angle=-2*Math.PI/length,stepR=Math.cos(angle),stepI=Math.sin(angle);
            for(int start=0;start<size;start+=length) {
                double wr=1,wi=0;
                for(int j=0;j<length/2;j++) {
                    int a=start+j,b=a+length/2;
                    double r=wr*real[b]-wi*imaginary[b],im=wr*imaginary[b]+wi*real[b];
                    real[b]=real[a]-r;imaginary[b]=imaginary[a]-im;real[a]+=r;imaginary[a]+=im;
                    double next=wr*stepR-wi*stepI;wi=wr*stepI+wi*stepR;wr=next;
                }
            }
        }
    }
}
