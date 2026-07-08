import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Primary gradient button for the shell (gray-flow) screens.
///
/// Intentionally distinct from the native game's [JesterButton]: the
/// game button uses a rectangular parchment plate, this pill uses a
/// tall rounded gold-to-crimson gradient with a soft glow. The two
/// coexist so a moderator sees clearly different visual languages
/// between the game menu and the shell veil.
class CarnivalPill extends StatefulWidget {
  const CarnivalPill({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
    this.tone = CarnivalPillTone.gold,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;
  final CarnivalPillTone tone;

  @override
  State<CarnivalPill> createState() => _CarnivalPillState();
}

enum CarnivalPillTone { gold, crimson }

class _CarnivalPillState extends State<CarnivalPill>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  LinearGradient _gradientFor(CarnivalPillTone tone) {
    switch (tone) {
      case CarnivalPillTone.gold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFE9A8),
            Color(0xFFFFC94D),
            Color(0xFFB8860B),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        );
      case CarnivalPillTone.crimson:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFF6B6B),
            Color(0xFFC1272D),
            Color(0xFF6B0F14),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (BuildContext context, Widget? child) {
            final double halo = 0.35 + 0.4 * _glow.value;
            return Container(
              width: widget.width,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 22 : 30,
                vertical: widget.compact ? 12 : 18,
              ),
              decoration: BoxDecoration(
                gradient: _gradientFor(widget.tone),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (widget.tone == CarnivalPillTone.gold
                            ? const Color(0xFFFFC94D)
                            : const Color(0xFFC1272D))
                        .withValues(alpha: halo),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.compact ? 16 : 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  height: 1.0,
                  color: AppColors.ink,
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0x55FFFFFF),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ghost-style button used for the "Skip" action on the beacon invite.
/// Renders as a subtle bordered chip so it is clearly tappable but does
/// NOT compete visually with the primary [CarnivalPill].
class CarnivalGhostChip extends StatefulWidget {
  const CarnivalGhostChip({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  State<CarnivalGhostChip> createState() => _CarnivalGhostChipState();
}

class _CarnivalGhostChipState extends State<CarnivalGhostChip> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 22 : 28,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: AppColors.goldLight.withValues(alpha: 0.7),
              width: 1.6,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.compact ? 14 : 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                height: 1.0,
                color: AppColors.goldLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
