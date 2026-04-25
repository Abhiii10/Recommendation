import 'package:flutter/material.dart';

import '../models/recommendation_components.dart';

class ScoreBreakdownWidget extends StatelessWidget {
  final RecommendationComponents components;
  final bool compact;
  final String? title;

  const ScoreBreakdownWidget({
    super.key,
    required this.components,
    this.compact = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final signals = [...components.signals()]
      ..sort((a, b) => b.value.compareTo(a.value));

    if (signals.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleSignals = compact ? signals.take(6).toList() : signals;
    final heading = title ??
        (compact ? 'Recommendation signals' : 'Recommendation score breakdown');

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              compact ? Icons.insights_outlined : Icons.auto_graph_rounded,
              size: compact ? 18 : 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              heading,
              style: (compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final signal in visibleSignals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BreakdownBar(
              label: signal.label,
              value: signal.value,
              compact: compact,
            ),
          ),
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.32),
        ),
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final double value;
  final bool compact;

  const _BreakdownBar({
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = _barColor(colorScheme, clamped);

    return Row(
      children: [
        SizedBox(
          width: compact ? 110 : 132,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: compact ? 8 : 10,
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '${(clamped * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Color _barColor(ColorScheme colorScheme, double value) {
    if (value >= 0.75) {
      return colorScheme.primary;
    }
    if (value >= 0.5) {
      return colorScheme.secondary;
    }
    if (value >= 0.3) {
      return colorScheme.tertiary;
    }
    return colorScheme.error;
  }
}
