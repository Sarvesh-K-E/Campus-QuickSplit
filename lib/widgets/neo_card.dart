import 'package:flutter/material.dart';

class NeoCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const NeoCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = EdgeInsets.zero,
  });

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: Padding(
        padding: widget.margin,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            top: _isPressed ? 4.0 : 0.0,
            left: _isPressed ? 4.0 : 0.0,
            bottom: _isPressed ? 0.0 : 4.0,
            right: _isPressed ? 0.0 : 4.0,
          ),
          decoration: BoxDecoration(
            color: widget.color ?? Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: borderColor,
              width: 3,
            ),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: borderColor,
                      offset: const Offset(4, 4),
                      blurRadius: 0,
                    )
                  ],
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
