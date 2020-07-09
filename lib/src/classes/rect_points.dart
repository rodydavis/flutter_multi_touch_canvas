import 'dart:ui';

class RectPoints {
  RectPoints(this.start, this.end);

  Offset start, end;

  Rect get rect => Rect.fromPoints(start, end);
}