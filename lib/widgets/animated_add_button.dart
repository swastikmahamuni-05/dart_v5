import 'package:flutter/material.dart';

class AnimatedAddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedAddButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<AnimatedAddButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF1565C0);

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: SystemMouseCursors.click,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            if (!_isHovered) _controller.reverse();
            widget.onPressed();
          },
          onTapCancel: () {
            if (!_isHovered) _controller.reverse();
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E88E5), // Light Blue
                  Color(0xFF1565C0), // Dark/Primary Blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(_isHovered ? 0.6 : 0.3),
                  blurRadius: _isHovered ? 16 : 8,
                  spreadRadius: _isHovered ? 3 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: RotationTransition(
                turns: _rotationAnimation,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
