import 'package:flutter/material.dart';

/// Intro breve (primo paragrafo) da una descrizione piano multi-blocco.
String planDescriptionIntro(String description) {
  final intro = description
      .split('\n\n')
      .map((block) => block.trim())
      .firstWhere((block) => block.isNotEmpty, orElse: () => '');
  if (intro.startsWith('• ')) return '';
  return intro;
}

/// Elenco descrittivo piano (intro + punti), come pagina prezzi CreditPlanet.
class PlanDescriptionList extends StatelessWidget {
  const PlanDescriptionList({
    super.key,
    required this.description,
    this.fontSize = 15,
    this.textColor,
  });

  final String description;
  final double fontSize;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: textColor ?? Colors.grey.shade800,
      height: 1.5,
      fontSize: fontSize,
    );
    final blocks = description
        .split('\n\n')
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBlock(blocks[i], textStyle),
        ],
      ],
    );
  }

  Widget _buildBlock(String block, TextStyle textStyle) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isNotEmpty && lines.every((line) => line.startsWith('• '))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < lines.length - 1 ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: textStyle),
                  Expanded(
                    child: Text(lines[i].substring(2), style: textStyle),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (block.contains(' · ')) {
      final items = block
          .split(' · ')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < items.length - 1 ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: textStyle),
                  Expanded(child: Text(items[i], style: textStyle)),
                ],
              ),
            ),
        ],
      );
    }

    return Text(block, style: textStyle);
  }
}
