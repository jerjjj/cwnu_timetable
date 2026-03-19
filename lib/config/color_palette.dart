import 'package:flutter/material.dart';

class ColorPalette {
  ColorPalette();

  final Map<String, Color> _cache = <String, Color>{};
  final Set<int> _usedValues = <int>{};
  final List<double> _usedHues = <double>[];

  static const _palette = [
    [210.0, 0.68, 0.60], // 蓝 Blue
    [340.0, 0.60, 0.60], // 玫红 Rose
    [140.0, 0.55, 0.55], // 绿 Green
    [25.0, 0.72, 0.60], // 橙 Orange
    [270.0, 0.52, 0.60], // 紫 Purple
    [175.0, 0.55, 0.52], // 青 Teal
    [45.0, 0.68, 0.58], // 棕黄 Amber
    [195.0, 0.60, 0.56], // 青蓝 Cyan
    [320.0, 0.50, 0.62], // 粉紫 Magenta
    [85.0, 0.48, 0.55], // 橄榄 Olive
    [155.0, 0.50, 0.52], // 深绿 Emerald
    [290.0, 0.48, 0.58], // 暗紫 Violet
    [10.0, 0.60, 0.58], // 红 Red
    [120.0, 0.45, 0.55], // 草绿 Lime
    [230.0, 0.55, 0.56], // 靛蓝 Indigo
    [5.0, 0.55, 0.58], // 赤红 Crimson
    [355.0, 0.55, 0.60], // 洋红 Fuchsia
    [160.0, 0.48, 0.54], // 翠绿 Jade
    [60.0, 0.58, 0.60], // 黄 Olive
    [250.0, 0.48, 0.58], // 蓝紫 Lavender
    [200.0, 0.55, 0.58], // 天蓝 Sky
    [30.0, 0.60, 0.58], // 铜色 Copper
    [130.0, 0.42, 0.52], // 森绿 Forest
    [310.0, 0.45, 0.58], // 藕紫 Plum
  ];

  static const _minHueGap = 60.0;

  double _hueDistance(double a, double b) {
    final rawDiff = (a - b).abs();
    return rawDiff > 180 ? 360 - rawDiff : rawDiff;
  }

  bool _isHueTooClose(double hue) {
    for (final usedHue in _usedHues) {
      if (_hueDistance(hue, usedHue) < _minHueGap) {
        return true;
      }
    }
    return false;
  }

  Color colorFor(String key) {
    final cached = _cache[key];
    if (cached != null) return cached;

    final seed = key.hashCode & 0x7fffffff;

    final paletteStart = seed % _palette.length;
    for (var offset = 0; offset < _palette.length; offset++) {
      final idx = (paletteStart + offset) % _palette.length;
      final hsl = _palette[idx];
      final hue = (hsl[0] + (seed % 20) - 10) % 360;
      final sat = hsl[1];
      final light = hsl[2];

      if (_isHueTooClose(hue)) continue;

      final color = HSLColor.fromAHSL(1, hue, sat, light).toColor();
      final value = color.toARGB32();
      if (!_usedValues.contains(value)) {
        _usedValues.add(value);
        _usedHues.add(hue);
        _cache[key] = color;
        return color;
      }
    }

    for (var i = 0; i < 12; i++) {
      final hue = (seed * 137.508 + i * 30) % 360;
      if (_isHueTooClose(hue)) continue;

      final sat = 0.55 + (i % 3) * 0.06;
      final light = 0.55 + (i % 4) * 0.03;
      final color = HSLColor.fromAHSL(1, hue, sat, light).toColor();
      final value = color.toARGB32();
      if (!_usedValues.contains(value)) {
        _usedValues.add(value);
        _usedHues.add(hue);
        _cache[key] = color;
        return color;
      }
    }

    final fallback = HSLColor.fromAHSL(
      1,
      (seed % 360).toDouble(),
      0.55,
      0.58,
    ).toColor();
    _usedValues.add(fallback.toARGB32());
    _usedHues.add((seed % 360).toDouble());
    _cache[key] = fallback;
    return fallback;
  }
}
