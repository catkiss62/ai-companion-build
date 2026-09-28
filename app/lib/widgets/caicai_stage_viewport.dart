/// Cache the keyboard-closed scene. Flutter's IME inset and layout height can
/// change in different frames; a zero inset is not proof that the window has
/// returned to its full size.
class CaicaiStageViewport {
  double? _height, _width;

  double resolve({
    required double width,
    required double availableHeight,
    required double keyboardInset,
  }) {
    if (_height == null || _width != width) {
      _height = availableHeight + keyboardInset;
      _width = width;
    } else if (keyboardInset == 0 && availableHeight > _height!) {
      _height = availableHeight;
    }
    return _height!;
  }
}
