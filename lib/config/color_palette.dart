import 'package:flutter/material.dart';

class ColorPalette {
  factory ColorPalette() => _instance;
  ColorPalette._internal();

  static final _instance = ColorPalette._internal();

  final Map<String, Color> _cache = <String, Color>{};

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

  Color colorFor(String key) {
    final cached = _cache[key];
    if (cached != null) return cached;

    final seed = key.hashCode & 0x7fffffff;
    final idx = seed % _palette.length;
    final hsl = _palette[idx];
    final hue = (hsl[0] + (seed % 20) - 10) % 360;
    final sat = hsl[1];
    final light = hsl[2];

    final color = HSLColor.fromAHSL(1, hue, sat, light).toColor();
    _cache[key] = color;
    return color;
  }
}
