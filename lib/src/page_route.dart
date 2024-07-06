import 'package:flutter/material.dart';

PageRouteBuilder<Object?> elasticTransition(Widget screen) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final elasticAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
      );
      return ScaleTransition(
        scale: elasticAnimation,
        child: child,
      );
    },
  );
}
