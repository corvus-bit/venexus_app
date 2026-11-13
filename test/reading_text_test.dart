import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venexus/widgets/reading_text.dart';

void main() {
  test('bionic reading bolds half of each word without changing the text', () {
    const original = 'Coração, ação! 👩‍👩‍👧‍👦 2026';
    final spans = bionicSpans(original).cast<TextSpan>();

    expect(spans.map((span) => span.text).join(), original);
    expect(
      spans
          .where((span) => span.style?.fontWeight == FontWeight.w800)
          .map((span) => span.text),
      ['Cora', 'aç', '20'],
    );
  });
}
