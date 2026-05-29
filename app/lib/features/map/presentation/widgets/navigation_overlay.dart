import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:rural_tourism_app/core/navigation/models/route_result.dart';

class NavigationOverlay extends StatelessWidget {
  final RouteResult route;
  final int currentStepIndex;
  final LatLng? currentLocation;
  final VoidCallback onEndNavigation;

  const NavigationOverlay({
    super.key,
    required this.route,
    required this.currentStepIndex,
    required this.currentLocation,
    required this.onEndNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: 14,
              child: _InstructionCard(
                icon: _iconFor(step),
                instruction: step?.instruction ?? 'Continue to destination',
                distanceText: step == null
                    ? ''
                    : 'in ${_formatDistance(_distanceToStep(step))}',
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _NavigationInfoBar(
                distanceText: _formatDistance(_remainingDistance),
                arrivalText: _arrivalTime(context),
                modeLabel: route.travelMode.label,
                onEndNavigation: onEndNavigation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  RouteStep? get _currentStep {
    if (route.steps.isEmpty) return null;
    final safeIndex = currentStepIndex < 0
        ? 0
        : currentStepIndex >= route.steps.length
            ? route.steps.length - 1
            : currentStepIndex;
    return route.steps[safeIndex];
  }

  double get _remainingDistance {
    if (route.steps.isEmpty) return route.distanceMeters;
    return route.steps
        .skip(currentStepIndex)
        .fold<double>(0, (sum, step) => sum + step.distanceMeters);
  }

  double get _remainingDuration {
    if (route.steps.isEmpty) return route.durationSeconds;
    return route.steps
        .skip(currentStepIndex)
        .fold<double>(0, (sum, step) => sum + step.durationSeconds);
  }

  double _distanceToStep(RouteStep step) {
    final location = currentLocation;
    if (location == null) return step.distanceMeters;
    return const Distance().as(LengthUnit.Meter, location, step.location);
  }

  String _arrivalTime(BuildContext context) {
    final eta = DateTime.now().add(
      Duration(seconds: _remainingDuration.round()),
    );
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(eta),
    );
  }

  IconData _iconFor(RouteStep? step) {
    if (step == null) return Icons.navigation_rounded;
    if (step.maneuverType == 'arrive') return Icons.flag_rounded;
    if (step.maneuverType == 'roundabout' ||
        step.maneuverType == 'rotary' ||
        step.maneuverType == 'roundabout turn') {
      return Icons.alt_route_rounded;
    }

    return switch (step.maneuverDirection) {
      'left' || 'sharp left' || 'slight left' => Icons.turn_left_rounded,
      'right' || 'sharp right' || 'slight right' => Icons.turn_right_rounded,
      'uturn' => Icons.rotate_left_rounded,
      'straight' => Icons.straight_rounded,
      _ => Icons.navigation_rounded,
    };
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }
}

class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String instruction;
  final String distanceText;

  const _InstructionCard({
    required this.icon,
    required this.instruction,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: cs.surface.withValues(alpha: 0.96),
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: cs.onPrimary, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (distanceText.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      distanceText,
                      style: textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationInfoBar extends StatelessWidget {
  final String distanceText;
  final String arrivalText;
  final String modeLabel;
  final VoidCallback onEndNavigation;

  const _NavigationInfoBar({
    required this.distanceText,
    required this.arrivalText,
    required this.modeLabel,
    required this.onEndNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: cs.surface.withValues(alpha: 0.96),
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _Metric(
                    label: 'Remaining',
                    value: distanceText,
                  ),
                  const SizedBox(width: 18),
                  _Metric(
                    label: 'ETA',
                    value: arrivalText,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onEndNavigation,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('End'),
              style: FilledButton.styleFrom(
                foregroundColor: cs.error,
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
