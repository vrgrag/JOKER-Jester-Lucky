import 'package:flutter/material.dart';

/// Renders "Loading" followed by an animated cycle of 0-3 dots.
class LoadingDotsText extends StatefulWidget {
  const LoadingDotsText({super.key, this.style, this.label = 'Loading'});

  final TextStyle? style;
  final String label;

  @override
  State<LoadingDotsText> createState() => _LoadingDotsTextState();
}

class _LoadingDotsTextState extends State<LoadingDotsText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dots = (_controller.value * 4).floor() % 4;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: 0,
              child: Text('${widget.label}...', style: widget.style),
            ),
            Text('${widget.label}${'.' * dots}', style: widget.style),
          ],
        );
      },
    );
  }
}
