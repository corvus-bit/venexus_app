import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../main.dart';

/// Preserva pontuação e espaços; divide a palavra por grafemas para não partir acentos.
List<InlineSpan> bionicSpans(String text) {
  final spans = <InlineSpan>[];
  final words = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
  var cursor = 0;
  for (final match in words.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final letters = match.group(0)!.characters.toList();
    final split = (letters.length + 1) ~/ 2;
    spans.add(
      TextSpan(
        text: letters.take(split).join(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (split < letters.length) {
      spans.add(TextSpan(text: letters.skip(split).join()));
    }
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

class ReadingText extends StatefulWidget {
  const ReadingText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.enableFocus = true,
    this.prefix,
    this.prefixStyle,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool enableFocus;
  final String? prefix;
  final TextStyle? prefixStyle;

  @override
  State<ReadingText> createState() => _ReadingTextState();
}

class _ReadingTextState extends State<ReadingText> {
  int _focusedParagraph = -1;

  @override
  void didUpdateWidget(covariant ReadingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _focusedParagraph = -1;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final baseStyle = defaultStyle.merge(widget.style);
    final spacious = appState.readingSpacing;
    final style = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * appState.readingScale,
      height: spacious ? 1.9 : baseStyle.height,
      letterSpacing: spacious ? 0.4 : baseStyle.letterSpacing,
      wordSpacing: spacious ? 2.0 : baseStyle.wordSpacing,
    );

    if (!appState.readingFocus ||
        !widget.enableFocus ||
        widget.maxLines != null) {
      return _text(widget.text, style, prefix: widget.prefix);
    }

    final paragraphs = widget.text.split(RegExp(r'\n\s*\n'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < paragraphs.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == paragraphs.length - 1 ? 0 : 10,
            ),
            child: InkWell(
              onTap: () => setState(() => _focusedParagraph = index),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: index == _focusedParagraph
                      ? const Color(0x14FAB206)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: index == _focusedParagraph
                          ? AppColors.yellow
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: _text(
                  paragraphs[index],
                  style,
                  prefix: index == 0 ? widget.prefix : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _text(String value, TextStyle style, {String? prefix}) {
    if (!appState.bionicReading && prefix == null) {
      return Text(
        value,
        style: style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          if (prefix != null) TextSpan(text: prefix, style: widget.prefixStyle),
          if (appState.bionicReading)
            ...bionicSpans(value)
          else
            TextSpan(text: value),
        ],
      ),
      style: style,
      semanticsLabel: '${prefix ?? ''}$value',
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
