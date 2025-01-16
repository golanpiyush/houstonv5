import 'package:flutter/material.dart';

class ShadowSliderTrackShape extends SliderTrackShape {
  final Color shadowColor;

  ShadowSliderTrackShape(this.shadowColor);

  @override
  Rect getPreferredRect({
    bool isDiscrete = false,
    bool isEnabled = true,
    Offset offset = Offset.zero,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackWidth = parentBox.size.width;

    return Rect.fromLTWH(
      offset.dx,
      (parentBox.size.height - trackHeight) / 2,
      trackWidth,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = true,
    required RenderBox parentBox,
    Offset? secondaryOffset,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required Offset thumbCenter,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      offset: offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
    );

    // Draw the inactive part of the track
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!;
    canvas.drawRect(trackRect, inactivePaint);

    // Calculate the active part of the track
    final Rect activeTrackRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );

    // Apply shadow and vibrant color to the active part of the track
    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    // Draw shadow to the active part of the slider
    canvas.drawRect(activeTrackRect, activePaint);
  }
}
