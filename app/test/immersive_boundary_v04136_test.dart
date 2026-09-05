import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('immersive room reserves only the explicit system inspection prefix', () {
    expect(
      ImmersiveRoomController.isReservedSystemInspectionCommand(
        '【检查系统】看看你有哪些系统',
      ),
      isTrue,
    );
    expect(
      ImmersiveRoomController.isReservedSystemInspectionCommand(
        '  【检查系统】检查真实能力',
      ),
      isTrue,
    );

    expect(
      ImmersiveRoomController.isReservedSystemInspectionCommand(
        '她问：“【检查系统】是什么意思？”',
      ),
      isFalse,
    );
    expect(
      ImmersiveRoomController.isReservedSystemInspectionCommand(
        '检查一下房间里的控制系统',
      ),
      isFalse,
    );
  });
}
