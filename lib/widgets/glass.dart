import 'dart:ui';
import 'package:flutter/material.dart';
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.intensity = .35, this.padding = EdgeInsets.zero});
  final Widget child;
  final double intensity;
  final EdgeInsetsGeometry padding;
  @override Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    return ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: intensity * 12, sigmaY: intensity * 12), child: Container(padding: padding, decoration: BoxDecoration(color: color.withValues(alpha: .92 - intensity * .25), border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .35)))), child: child)));
  }
}
