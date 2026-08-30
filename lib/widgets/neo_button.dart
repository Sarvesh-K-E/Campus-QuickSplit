import 'package:flutter/material.dart';

class NeoButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final double shadowOffset;

  const NeoButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    this.borderWidth = 3.0,
    this.shadowOffset = 4.0,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark ? Colors.white : Colors.black;
    final bool isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          top: _isPressed ? widget.shadowOffset : 0,
          left: _isPressed ? widget.shadowOffset : 0,
          bottom: _isPressed ? 0 : widget.shadowOffset,
          right: _isPressed ? 0 : widget.shadowOffset,
        ),
        decoration: BoxDecoration(
          color: isDisabled 
              ? Colors.grey.shade400 
              : (widget.color ?? Theme.of(context).primaryColor),
          border: Border.all(
            color: borderColor,
            width: widget.borderWidth,
          ),
          boxShadow: _isPressed || isDisabled
              ? []
              : [
                  BoxShadow(
                    color: borderColor,
                    offset: Offset(widget.shadowOffset, widget.shadowOffset),
                    blurRadius: 0,
                  )
                ],
        ),
        padding: widget.padding,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.black, // Dark text is standard on vibrant backgrounds
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Space Grotesk',
          ),
          child: IconTheme(
            data: const IconThemeData(color: Colors.black),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
