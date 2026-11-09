import 'dart:async';

import 'package:flutter/material.dart';

/// Clever Project brand colours.
class CleverColors {
  static const purple = Color(0xFF7B3AED);
  static const ink = Color(0xFF15112B);
  static const lilac = Color(0xFFB794FF);
  static const lime = Color(0xFFD5FD44); // cursor on dark / purple
  static const darkLime = Color(0xFF7AA300); // cursor on white
  static const background = Color(0xFF0C0916); // dark app background
  static const surface = Color(0xFF17122A);
}

enum CleverLogoTheme { dark, light }

/// Animated Clever Project logo.
///
/// Intro (about 2.2 s): the rounded frame draws itself, the ">" prompt draws,
/// the cursor bar slides out, then "clever" / "project" is typed.
/// After that the "_" cursor keeps blinking.
class CleverLogoAnimated extends StatefulWidget {
  const CleverLogoAnimated({
    super.key,
    this.size = 72,
    this.theme = CleverLogoTheme.dark,
    this.showText = true,
    this.onIntroDone,
    this.introDuration = const Duration(milliseconds: 2200),
    this.fontFamily = 'JetBrainsMono',
  });

  /// Size of the square mark. The text scales with it.
  final double size;
  final CleverLogoTheme theme;

  /// false = mark only (e.g. splash screen, small headers).
  final bool showText;

  /// Called once when the intro finishes (use it to reveal the login form).
  final VoidCallback? onIntroDone;
  final Duration introDuration;
  final String fontFamily;

  @override
  State<CleverLogoAnimated> createState() => CleverLogoAnimatedState();
}

class CleverLogoAnimatedState extends State<CleverLogoAnimated>
    with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: widget.introDuration);
  // Blink with a cheap timer (2 repaints/sec) instead of a 60 fps ticker.
  Timer? _blinkTimer;
  bool _cursorOn = true;

  void _startBlink() {
    _blinkTimer?.cancel();
    _cursorOn = true;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  static const _line1 = 'clever';
  static const _line2 = 'project';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect "reduce motion": jump straight to the finished logo.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
      _startBlink();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onIntroDone?.call());
    } else {
      replay();
    }
  }

  /// Play the intro again (e.g. after logout).
  void replay() {
    _blinkTimer?.cancel();
    _cursorOn = true;
    _intro.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _startBlink();
      widget.onIntroDone?.call();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.theme == CleverLogoTheme.dark;
    final frameColor = dark ? CleverColors.lilac : CleverColors.purple;
    final chevronColor = dark ? Colors.white : CleverColors.purple;
    final cursorColor = dark ? CleverColors.lime : CleverColors.darkLime;
    final line1Color = dark ? Colors.white : CleverColors.ink;
    final line2Color = dark ? CleverColors.lilac : CleverColors.purple;

    final fontSize = widget.size * 0.45;
    final base = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: fontSize,
      height: 1.0,
      letterSpacing: -0.045 * fontSize,
    );
    final style1 = base.copyWith(fontWeight: FontWeight.w800, color: line1Color);
    final style2 = base.copyWith(fontWeight: FontWeight.w400, color: line2Color);

    return RepaintBoundary(child: Semantics(
      label: 'Clever Project',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = _intro.value;
          final done = _intro.isCompleted;
          final cursorOn = !done || _cursorOn;

          final frame =
              const Interval(0.0, 0.32, curve: Curves.easeInOutCubic).transform(t);
          final chevron =
              const Interval(0.20, 0.44, curve: Curves.easeOutCubic).transform(t);
          final bar =
              const Interval(0.40, 0.52, curve: Curves.easeOutCubic).transform(t);
          final pop =
              const Interval(0.0, 0.36, curve: Curves.easeOutBack).transform(t);
          final typing = const Interval(0.50, 0.94).transform(t);

          final total = _line1.length + _line2.length;
          final int typed = (typing * total).floor().clamp(0, total).toInt();
          final int shown1 = typed.clamp(0, _line1.length).toInt();
          final int shown2 =
              (typed - _line1.length).clamp(0, _line2.length).toInt();
          final typingStarted = typing > 0;
          final onLine2 = typed >= _line1.length;

          final mark = Transform.scale(
            scale: 0.85 + 0.15 * pop,
            child: Opacity(
              opacity: frame > 0 ? 1 : 0,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _MarkPainter(
                  frame: frame,
                  chevron: chevron,
                  bar: bar,
                  barVisible: !done || cursorOn || widget.showText,
                  frameColor: frameColor,
                  chevronColor: chevronColor,
                  cursorColor: cursorColor,
                ),
              ),
            ),
          );

          if (!widget.showText) return mark;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(width: widget.size * 0.24),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typedLine(_line1, shown1, style1,
                      showCursor: typingStarted && !onLine2,
                      cursorOn: cursorOn,
                      cursorColor: cursorColor),
                  SizedBox(height: fontSize * 0.04),
                  _typedLine(_line2, shown2, style2,
                      showCursor: onLine2,
                      cursorOn: cursorOn,
                      cursorColor: cursorColor),
                ],
              ),
            ],
          );
        },
      ),
    ));
  }

  /// One line of typed text. An invisible full copy keeps the width fixed,
  /// so nothing shifts while the letters appear.
  Widget _typedLine(
    String full,
    int shown,
    TextStyle style, {
    required bool showCursor,
    required bool cursorOn,
    required Color cursorColor,
  }) {
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text('${full}_', style: style)),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: full.substring(0, shown), style: style),
            if (showCursor)
              TextSpan(
                text: '_',
                style: style.copyWith(
                  color: cursorOn ? cursorColor : Colors.transparent,
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

/// Draws the mark in the same 440-unit grid as the SVG logo.
class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.frame,
    required this.chevron,
    required this.bar,
    required this.barVisible,
    required this.frameColor,
    required this.chevronColor,
    required this.cursorColor,
  });

  final double frame, chevron, bar;
  final bool barVisible;
  final Color frameColor, chevronColor, cursorColor;

  static final Path _framePath = Path()
    ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 400, 400), const Radius.circular(96)));
  static final Path _chevronPath = Path()
    ..moveTo(115, 135)
    ..lineTo(195, 200)
    ..lineTo(115, 265);

  Path _trim(Path source, double progress) {
    final out = Path();
    if (progress <= 0) return out;
    for (final m in source.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * progress.clamp(0.0, 1.0)), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 440);
    canvas.translate(20, 20);

    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (frame >= 1) {
      canvas.drawPath(_framePath, stroke(frameColor));
    } else {
      canvas.drawPath(_trim(_framePath, frame), stroke(frameColor));
    }
    canvas.drawPath(_trim(_chevronPath, chevron), stroke(chevronColor));

    if (bar > 0 && barVisible) {
      canvas.drawLine(
        const Offset(225, 268),
        Offset(225 + 70 * bar, 268),
        stroke(cursorColor),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.frame != frame ||
      old.chevron != chevron ||
      old.bar != bar ||
      old.barVisible != barVisible ||
      old.frameColor != frameColor ||
      old.chevronColor != chevronColor ||
      old.cursorColor != cursorColor;
}
