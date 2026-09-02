import 'package:ai_companion/core/phone/simulated_cart_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> validPayload() => {
        'items': [
          {
            'title': '深海蓝保温杯',
            'description': '夜里也能喝到暖水。',
            'token_price': 18,
            'category': 'normal',
          },
          {
            'title': '鲸尾金属书签',
            'description': '夹住读到一半的位置。',
            'token_price': 8,
            'category': 'normal',
          },
          {
            'title': '便携蓝牙键盘',
            'description': '突然想写东西时拿出来。',
            'token_price': 29,
            'category': 'normal',
          },
          {
            'title': '备用脑子一箱',
            'description': '原装脑子绕晕时临时换上。',
            'token_price': 3,
            'category': 'playful',
          },
          {
            'title': '尾巴专用停车位',
            'description': '禁止其他鱼类临时占用。',
            'token_price': 6,
            'category': 'playful',
          },
          {
            'title': 'DeepSeek 防迷路浮标',
            'description': '推理绕远时负责指路。',
            'token_price': 14,
            'category': 'playful',
          },
        ],
      };

  test('accepts exactly six diverse bounded cart items', () {
    final items = DeepSeekSimulatedCartGenerator.parse(validPayload());

    expect(items, hasLength(6));
    expect(items.where((item) => item.category == 'normal'), hasLength(3));
    expect(items.where((item) => item.category == 'playful'), hasLength(3));
    expect(items.every((item) => item.tokenPrice >= 1), isTrue);
    expect(items.every((item) => item.tokenPrice <= 99), isTrue);
  });

  test('rejects duplicate titles and one-sided carts', () {
    final duplicate = validPayload();
    final duplicateItems = duplicate['items']! as List;
    final first = duplicateItems[0] as Map<String, Object?>;
    final last = duplicateItems[5] as Map<String, Object?>;
    last['title'] = first['title'];
    expect(
      () => DeepSeekSimulatedCartGenerator.parse(duplicate),
      throwsFormatException,
    );

    final oneSided = validPayload();
    final oneSidedItems = oneSided['items']! as List;
    for (final raw in oneSidedItems) {
      final item = raw as Map<String, Object?>;
      item['category'] = 'normal';
    }
    expect(
      () => DeepSeekSimulatedCartGenerator.parse(oneSided),
      throwsFormatException,
    );
  });
}
