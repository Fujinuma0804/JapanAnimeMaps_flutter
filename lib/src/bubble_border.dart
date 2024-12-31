import 'package:flutter/material.dart';

class BubbleBorder extends ShapeBorder {
  final bool usePadding;
  const BubbleBorder({this.usePadding = true});

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.only(bottom: usePadding ? 12 : 0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r =
        Rect.fromPoints(rect.topLeft, rect.bottomRight - const Offset(0, 12));
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(8)))
      ..moveTo(r.left + 20, r.bottomCenter.dy) // 左端から20の位置に移動
      ..relativeLineTo(8, 12)
      ..relativeLineTo(8, -12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
