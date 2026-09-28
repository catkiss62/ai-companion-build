/// Keep the portrait canvas at its keyboard-closed size. The conversation panel
/// may shrink above the keyboard; its clipped native canvas must not be refitted.
class CaicaiStageViewport {
  double? _height, _width;
  double resolve({required double width, required double availableHeight, required double keyboardInset}) {
    if (_height == null || _width != width || keyboardInset == 0) {
      _height = availableHeight + keyboardInset;
      _width = width;
    }
    return _height!;
  }
}
