import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/config/color_palette.dart';

void main() {
  group('ColorPalette', () {
    late ColorPalette palette;

    setUp(() {
      palette = ColorPalette();
    });

    test('returns same color for same key', () {
      final color1 = palette.colorFor('高等数学');
      final color2 = palette.colorFor('高等数学');
      expect(color1, equals(color2));
    });

    test('returns different colors for different keys', () {
      final color1 = palette.colorFor('高等数学');
      final color2 = palette.colorFor('普通物理');
      final color3 = palette.colorFor('线性代数');

      // 至少有两个不同的颜色
      final colors = {color1, color2, color3};
      expect(colors.length, greaterThan(1));
    });

    test('color has full opacity', () {
      final color = palette.colorFor('test');
      expect(color.a, equals(1.0));
    });

    test('color is valid', () {
      final color = palette.colorFor('test');
      expect(color, isNotNull);
      expect(color, isA<Color>());
    });

    test('singleton returns same instance', () {
      final palette1 = ColorPalette();
      final palette2 = ColorPalette();
      expect(identical(palette1, palette2), isTrue);
    });

    test('generates colors for many keys', () {
      final colors = <Color>{};
      for (var i = 0; i < 50; i++) {
        colors.add(palette.colorFor('course_$i'));
      }
      // 应该有多种不同的颜色
      expect(colors.length, greaterThan(5));
    });
  });
}
