package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import static org.junit.Assert.*;
import java.util.*;

public class CaicaiSpeechPresetLeaseTest {
    static final class Stage implements CaicaiSpeechPresetLease.Target {
        final Set<String> active = new HashSet<>();
        final List<String> starts = new ArrayList<>();
        final Set<String> manual = new HashSet<>();
        public boolean acquire(String name) {
            if (manual.contains(name)) return false;
            active.add(name); starts.add(name); return true;
        }
        public void release(String name) { active.remove(name); }
    }
    @Test public void allAuthoredFamiliesCanStackAndEachWinkEndsIndependently() {
        for (String face : List.of("1爱心","1生气","1红脸","1钱钱","1黑脸","1星星眼","1流泪")) {
            for (String wink : List.of("wink","wink吐舌","比耶wink吐舌")) {
                for (String action : List.of("2奶茶","2插手","2比耶","2点单","2菜单","2餐盘左","2餐盘右")) {
                    var state = new CaicaiSpeechPresetLease(); var stage = new Stage();
                    state.cue("1:0",face,wink,action,true,0,stage);
                    assertEquals(3, stage.active.size());
                    state.tick(CaicaiSpeechPresetLease.releaseAfterNanos(wink),stage);
                    assertFalse(stage.active.contains(wink));
                    assertTrue(stage.active.contains(face)); assertTrue(stage.active.contains(action));
                    state.release(stage); assertTrue(stage.active.isEmpty());
                }
            }
        }
    }
    @Test public void repeatedHeartbeatNeverExtendsOrRestartsTheSameWink() {
        var state = new CaicaiSpeechPresetLease(); var stage = new Stage();
        state.cue("1:0","1红脸","wink","2奶茶",true,0,stage);
        state.cue("1:0","1红脸","wink","2奶茶",false,800_000_000L,stage);
        state.tick(820_000_000L,stage);
        state.cue("1:0","1红脸","wink","2奶茶",true,900_000_000L,stage);
        assertFalse(stage.active.contains("wink")); assertEquals(3,stage.starts.size());
    }
    @Test public void lateAttachMuteStopAndUnknownNamesCannotStartPresets() {
        var state = new CaicaiSpeechPresetLease(); var stage = new Stage();
        state.cue("1:0","1爱心","wink","2菜单",false,0,stage);
        assertTrue(stage.active.isEmpty());
        state.cue("1:1","1爱心","wink","2菜单",true,0,stage);
        state.release(stage); assertTrue(stage.active.isEmpty());
        state.cue("1:1","1爱心","wink","2菜单",false,1,stage);
        assertTrue(stage.active.isEmpty());
        state.cue("1:2","变小","made-up","女仆装",true,2,stage);
        assertTrue(stage.active.isEmpty());
    }
    @Test public void retirementNeverRemovesAnUnacquiredManualPreset() {
        var state = new CaicaiSpeechPresetLease(); var stage = new Stage();
        stage.manual.add("1红脸"); stage.active.add("1红脸");
        state.cue("1:0","1红脸","wink","",true,0,stage);
        state.release(stage);
        assertEquals(Set.of("1红脸"),stage.active);
    }
    @Test public void audioPresetsExcludeJawAndMouthShapeButKeepTongueAndEyes() {
        for(String id : List.of("ParamMouthOpenY","ParamMouthForm","MOUTHX","SHRUG","PUCKER"))
            assertTrue(id,CaicaiSpeechPresetLease.mouthParameter(id));
        assertFalse(CaicaiSpeechPresetLease.mouthParameter("OUT"));
        assertFalse(CaicaiSpeechPresetLease.mouthParameter("ParamEyeLOpen"));
        assertEquals(820_000_000L,CaicaiSpeechPresetLease.releaseAfterNanos("wink"));
        assertEquals(1_220_000_000L,CaicaiSpeechPresetLease.releaseAfterNanos("wink吐舌"));
        assertEquals(1_620_000_000L,CaicaiSpeechPresetLease.releaseAfterNanos("比耶wink吐舌"));
    }
}
