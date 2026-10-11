import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/features/creative/creative_pages.dart';
import 'package:ai_companion_localfirst/features/creative/creative_player_layout.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/widgets/action_tint_text.dart';

void main() {
  testWidgets('work card is title-only until expanded; collapse removes details and cover', (tester) async {
    var opened=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CreativeWorkCard(
      work:const {'id':'w','title':'一张贺卡','intro':'点击星星下雪','note':'做好了'},onOpen:()=>opened++))));
    expect(find.text('一张贺卡'),findsOneWidget);
    expect(find.text('打开作品'),findsNothing);
    expect(find.textContaining('点击星星下雪'),findsNothing);
    await tester.tap(find.text('一张贺卡'));await tester.pump();
    expect(find.textContaining('点击星星下雪'),findsOneWidget);
    await tester.tap(find.text('打开作品'));expect(opened,1);
    await tester.tap(find.text('一张贺卡'));await tester.pump();
    expect(find.text('打开作品'),findsNothing);
  });
  testWidgets('commission history stays a progress record after completion', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CreativeWorkCard(work:const {
      'id':'w','title':'棋盘','card_kind':'progress','status':'ready'},onOpen:(){}))));
    await tester.tap(find.text('棋盘'));await tester.pump();
    expect(find.text('制作记录 · 已完成'),findsOneWidget);
    expect(find.text('打开作品'),findsNothing);
  });
  testWidgets('player messages have distinct sides and use the selected dialogue tint', (tester) async {
    final user=ChatMessage(id:'u',role:'user',content:'看看星星',createdAt:DateTime(2026));
    final assistant=ChatMessage(id:'a',role:'assistant',content:'「星星亮起来了。」',createdAt:DateTime(2026));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ChatDialogueColorScope(option:ChatDialogueColorOption.pink,
      child:Column(children:[CreativeChatBubble(message:user),CreativeChatBubble(message:assistant)])))));
    final aligns=tester.widgetList<Align>(find.descendant(of:find.byType(CreativeChatBubble),matching:find.byType(Align))).toList();
    expect(aligns.first.alignment,Alignment.centerRight);expect(aligns.last.alignment,Alignment.centerLeft);
    final rich=tester.widget<RichText>(find.descendant(of:find.byType(ActionTintText),matching:find.byType(RichText)).first);
    final colors=<Color?>[];
    void walk(InlineSpan span) {if(span is TextSpan){colors.add(span.style?.color);for(final child in span.children??<InlineSpan>[])walk(child);}}
    walk(rich.text);expect(colors,contains(chatDialoguePink));
  });
  testWidgets('keyboard moves chat without resizing or recreating the native-page child', (tester) async {
    const page=ColoredBox(key:ValueKey('page'),color:Colors.blue);
    const panel=ColoredBox(key:ValueKey('panel'),color:Colors.black);
    Future<void> show(double inset) async {
      await tester.pumpWidget(MaterialApp(home:Scaffold(resizeToAvoidBottomInset:false,body:MediaQuery(
        data:MediaQueryData(size:const Size(800,600),viewInsets:EdgeInsets.only(bottom:inset)),
        child:const CreativePlayerLayout(page:page,chat:panel)))));
    }
    await show(0);final size=tester.getSize(find.byKey(const ValueKey('page')));
    final element=tester.element(find.byKey(const ValueKey('page')));
    await show(250);expect(tester.getSize(find.byKey(const ValueKey('page'))),size);
    expect(tester.element(find.byKey(const ValueKey('page'))),same(element));
    expect(tester.getBottomLeft(find.byKey(const ValueKey('panel'))).dy,350);
    await show(0);expect(tester.getSize(find.byKey(const ValueKey('page'))),size);
    expect(tester.takeException(),isNull);
  });
}
