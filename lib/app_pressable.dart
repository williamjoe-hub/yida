import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 全局轻按反馈。只改变缩放，不影响布局，也不会制造涟漪噪音。
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = .97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool pressed = false;

  void _setPressed(bool value) {
    if (pressed == value || widget.onTap == null) return;
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppTheme.reduceMotion(context);
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: pressed ? widget.scale : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 110),
          curve: AppTheme.spring,
          child: widget.child,
        ),
      ),
    );
  }
}
