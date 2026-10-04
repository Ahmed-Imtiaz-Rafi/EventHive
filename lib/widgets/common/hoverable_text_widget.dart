import 'package:flutter/material.dart';

class HoverableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  const HoverableText({
    super.key,
    required this.text,
    required this.style,
    required this.onTap,
  });

  @override
  State<HoverableText> createState() => _HoverableTextState();
}

class _HoverableTextState extends State<HoverableText> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final highlightColor = widget.style.color ?? Theme.of(context).primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // The "circle around the text" — a soft pill-shaped
            // highlight that fades in on hover, text itself stays
            // the same size the whole time.
            color: _hovering
                ? highlightColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(widget.text, style: widget.style),
        ),
      ),
    );
  }
}
