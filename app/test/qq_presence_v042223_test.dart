import 'package:ai_companion_localfirst/integrations/qq_private/qq_runtime.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one stable waking window across restarts and no replay outside it',() {
    var opportunities=0;
    var pictures=0;
    for(var i=0;i<365;i++) {
      final date=DateTime(2026,1,1+i);
      final window=QqPresenceWindow('test-device',date);
      final start=date.add(Duration(minutes:540+window.roll(6,840)));
      expect(window.due(date),false);
      expect(QqPresenceWindow('test-device',start).due(start),window.offered);
      expect(window.due(start.add(const Duration(minutes:10))),false);
      if(window.offered) {opportunities++;if(window.offerPicture)pictures++;}
    }
    expect(opportunities,inInclusiveRange(85,175));
    expect(pictures,inInclusiveRange(12,60));
  });
  test('group opt-in follows authorized groups',() {
    const options=QqOptions(groups:{'a','b'},presenceGroups:{'a'});
    expect(options.copy(groups:{'b'}).presenceGroups,isEmpty);
    expect(options.copy(core:'updated').presenceGroups,{'a'});
  });
}
