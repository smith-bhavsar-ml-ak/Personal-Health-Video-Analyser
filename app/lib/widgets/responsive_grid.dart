import 'package:flutter/material.dart';

/// Renders [children] in a 3-column grid on screens ≥ 768 px wide,
/// and as a single-column list on smaller screens.
///
/// Usage:
/// ```dart
/// ResponsiveGrid(
///   children: [CardA(), CardB(), CardC(), CardD()],
/// )
/// ```
/// Cards are distributed left-to-right, top-to-bottom across columns.
/// Each row uses [IntrinsicHeight] so siblings in the same row stretch
/// to match the tallest card.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double columnSpacing;
  final double rowSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columnSpacing = 16,
    this.rowSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    if (!isDesktop || children.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: rowSpacing),
          ],
        ],
      );
    }

    // Build rows of 3
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += 3) {
      final rowChildren = children.sublist(i, (i + 3).clamp(0, children.length));

      // Pad to 3 items so columns stay aligned
      final padded = List<Widget>.from(rowChildren);
      while (padded.length < 3) {
        padded.add(const SizedBox.shrink());
      }

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < padded.length; j++) ...[
                Expanded(child: padded[j]),
                if (j < padded.length - 1) SizedBox(width: columnSpacing),
              ],
            ],
          ),
        ),
      );

      if (i + 3 < children.length) {
        rows.add(SizedBox(height: rowSpacing));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
