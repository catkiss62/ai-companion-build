import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/features/chat/chat_tail_follower.dart';

void main() {
  testWidgets('instant long reply and later layout growth settle at the tail', (tester) async {
    final scroll = ScrollController();
    var follow = true;
    final follower = ChatTailFollower(controller: scroll, canFollow: () => follow);
    var count = 20;
    var height = 40.0;
    late StateSetter change;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, set) {
      change = set;
      return Scaffold(body: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) { follower.request(); return false; },
        child: ListView.builder(controller: scroll, itemCount: count,
          itemBuilder: (_, i) => SizedBox(height: i == count - 1 ? height : 40,
            child: Text('message $i')))));
    })));
    follower.request();
    await tester.pumpAndSettle();
    change(() { count++; height = 1600; });
    follower.request();
    await tester.pumpAndSettle();
    expect(scroll.position.extentAfter, lessThan(1));
    change(() { height = 2000; });
    await tester.pumpAndSettle();
    expect(scroll.position.extentAfter, lessThan(1));
    follow = false;
    scroll.jumpTo(200);
    change(() { height = 2400; });
    await tester.pumpAndSettle();
    expect(scroll.offset, 200);
    follower.dispose();
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets('queued follow obeys cancellation and disposal', (tester) async {
    final scroll = ScrollController();
    var follow = true;
    final follower = ChatTailFollower(controller: scroll, canFollow: () => follow);
    await tester.pumpWidget(MaterialApp(home: ListView(controller: scroll,
      children: const [SizedBox(height: 3000)])));
    follower.request();
    follow = false;
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    follow = true;
    follower.request();
    follower.dispose();
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
