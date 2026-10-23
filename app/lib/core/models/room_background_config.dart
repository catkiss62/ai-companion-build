import 'dart:convert';

/// Geometry is relative to viewport width, including vertical translation.
/// Keyboard/height changes therefore never rescale or recenter the artwork.
class RoomBackgroundConfig {
  const RoomBackgroundConfig({this.mode = 'default', this.scale = 1,
    this.x = 0, this.y = 0});
  static const settingKey = 'immersive_background_v1';
  static const blobKey = 'immersive_background_blob_id_v1';
  final String mode;
  final double scale, x, y;
  bool get visible => mode != 'none';
  RoomBackgroundConfig copyWith({String? mode, double? scale, double? x, double? y}) =>
      RoomBackgroundConfig(mode:mode ?? this.mode, scale:scale ?? this.scale,
        x:x ?? this.x, y:y ?? this.y);
  String encode() {
    if (!const {'default','custom','none'}.contains(mode) ||
        !scale.isFinite || scale < .01 || scale > 100 || !x.isFinite || !y.isFinite ||
        x.abs() > 1000000 || y.abs() > 1000000) {
      throw const FormatException('背景尺寸或位置无效');
    }
    return jsonEncode({'v':1,'mode':mode,'scale':scale,'x':x,'y':y});
  }
  static RoomBackgroundConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RoomBackgroundConfig();
    final data = jsonDecode(raw);
    if (data is! Map || data['v'] != 1) throw const FormatException('背景设置无效');
    final result = RoomBackgroundConfig(mode:data['mode'] as String,
      scale:(data['scale'] as num).toDouble(), x:(data['x'] as num).toDouble(),
      y:(data['y'] as num).toDouble());
    result.encode();
    return result;
  }
}
