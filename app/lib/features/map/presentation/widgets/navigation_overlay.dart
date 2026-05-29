import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:rural_tourism_app/core/navigation/models/route_result.dart';
import 'package:rural_tourism_app/core/utils/haversine.dart';

class NavigationOverlay extends StatefulWidget {
  final RouteResult route;
  final List<RouteStep> steps;
  final int currentStepIndex;
  final LatLng? currentPosition;
  final LatLng destination;
  final VoidCallback onStepAdvance;
  final VoidCallback onEndNavigation;

  const NavigationOverlay({
    super.key,
    required this.route,
    required this.steps,
    required this.currentStepIndex,
    required this.currentPosition,
    required this.destination,
    required this.onStepAdvance,
    required this.onEndNavigation,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  bool _arrivedShown = false;
  bool _advanceQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStepAdvance());
  }

  @override
  void didUpdateWidget(covariant NavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.currentStepIndex != widget.currentStepIndex ||
        oldWidget.destination != widget.destination) {
      _checkStepAdvance();
    }
  }

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
              bottom: 16,
              child: _NavigationInfoBar(
                summaryText: _remainingSummary(context),
                modeLabel: widget.route.travelMode.label,
                onEndNavigation: widget.onEndNavigation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  RouteStep? get _currentStep {
    if (widget.steps.isEmpty) return null;
    return widget.steps[_safeStepIndex];
  }

  int get _safeStepIndex {
    if (widget.steps.isEmpty) return 0;
    return widget.currentStepIndex.clamp(0, widget.steps.length - 1);
  }

  double get _remainingDistance {
    if (widget.steps.isEmpty) return widget.route.distanceMeters;
    return widget.steps
        .skip(_safeStepIndex)
        .fold<double>(0, (sum, step) => sum + step.distanceMeters);
  }

  double get _remainingDuration {
    if (widget.steps.isEmpty) return widget.route.durationSeconds;
    return widget.steps
        .skip(_safeStepIndex)
        .fold<double>(0, (sum, step) => sum + step.durationSeconds);
  }

  void _checkStepAdvance() {
    final position = widget.currentPosition;
    if (position == null) return;

    final destinationDistance = _distanceMeters(position, widget.destination);
    if (destinationDistance <= 50 && !_arrivedShown) {
      _arrivedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('You have arrived! 🎉'),
            content: const Text('You have reached your destination.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  widget.onEndNavigation();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      });
      return;
    }

    if (widget.steps.isEmpty ||
        widget.currentStepIndex < 0 ||
        widget.currentStepIndex >= widget.steps.length - 1 ||
        _advanceQueued) {
      return;
    }

    final step = widget.steps[widget.currentStepIndex];
    if (_distanceMeters(position, step.location) <= 30) {
      _advanceQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onStepAdvance();
        _advanceQueued = false;
      });
    }
  }

  double _distanceToStep(RouteStep step) {
    final location = widget.currentPosition;
    if (location == null) return step.distanceMeters;
    return _distanceMeters(location, step.location);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return haversineKm(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) *
        1000;
  }

  String _remainingSummary(BuildContext context) {
    final eta = DateTime.now().add(
      Duration(seconds: _remainingDuration.round()),
    );
    final etaText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(eta),
    );
    return '${_formatDistance(_remainingDistance)} · Arriving ~$etaText';
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
  final String summaryText;
  final String modeLabel;
  final VoidCallback onEndNavigation;

  const _NavigationInfoBar({
    required this.summaryText,
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              modeLabel,
              style: textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEndNavigation,
                icon: const Icon(Icons.close_rounded),
                label: const Text('End Navigation'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
