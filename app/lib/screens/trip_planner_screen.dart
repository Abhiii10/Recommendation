import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/haversine.dart';
import '../models/destination.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';

class TripPlannerScreen extends StatefulWidget {
  final List<Destination> savedDestinations;

  const TripPlannerScreen({
    super.key,
    required this.savedDestinations,
  });

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final List<List<Destination>> _days = [];

  bool get _hasStops => _days.any((day) => day.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _days.add(List<Destination>.of(widget.savedDestinations));
  }

  List<_PlannerEntry> get _entries {
    final entries = <_PlannerEntry>[];

    for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) {
      entries.add(_PlannerEntry.header(dayIndex));

      final stops = _days[dayIndex];
      if (stops.isEmpty) {
        entries.add(_PlannerEntry.empty(dayIndex));
        continue;
      }

      for (var stopIndex = 0; stopIndex < stops.length; stopIndex++) {
        entries.add(
          _PlannerEntry.stop(
            dayIndex: dayIndex,
            stopIndex: stopIndex,
            destination: stops[stopIndex],
          ),
        );
      }
    }

    return entries;
  }

  void _addDay() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _days.add([]);
    });
  }

  void _reorderStop(int oldIndex, int newIndex) {
    final before = _entries;
    final moving = before[oldIndex];
    if (moving.type != _PlannerEntryType.stop) return;

    unawaited(HapticFeedback.selectionClick());

    setState(() {
      final destination = _days[moving.dayIndex].removeAt(moving.stopIndex!);
      final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final target = _targetForInsertion(_entries, adjustedIndex);
      _days[target.dayIndex].insert(target.stopIndex, destination);
    });
  }

  _InsertionTarget _targetForInsertion(
    List<_PlannerEntry> entries,
    int insertIndex,
  ) {
    if (insertIndex <= 0) return const _InsertionTarget(0, 0);

    if (insertIndex >= entries.length) {
      final dayIndex = _days.length - 1;
      return _InsertionTarget(dayIndex, _days[dayIndex].length);
    }

    final target = entries[insertIndex];
    switch (target.type) {
      case _PlannerEntryType.header:
        if (target.dayIndex == 0) return const _InsertionTarget(0, 0);
        final previousDay = target.dayIndex - 1;
        return _InsertionTarget(previousDay, _days[previousDay].length);
      case _PlannerEntryType.empty:
        return _InsertionTarget(target.dayIndex, 0);
      case _PlannerEntryType.stop:
        return _InsertionTarget(target.dayIndex, target.stopIndex!);
    }
  }

  Destination? _nextStopFor(int dayIndex, int stopIndex) {
    final nextIndex = stopIndex + 1;
    if (dayIndex < 0 || dayIndex >= _days.length) return null;
    if (nextIndex >= _days[dayIndex].length) return null;
    return _days[dayIndex][nextIndex];
  }

  Future<void> _shareItinerary() async {
    unawaited(HapticFeedback.selectionClick());
    if (!_hasStops) return;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'Trip Itinerary',
        text: _itineraryText(),
      ),
    );
  }

  String _itineraryText() {
    final lines = <String>[];

    for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) {
      final stops = _days[dayIndex];
      final names = stops.isEmpty
          ? 'No stops planned yet'
          : stops.map((destination) => destination.name).join(' → ');
      lines.add('Day ${dayIndex + 1}: $names');
    }

    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Planner'),
        actions: [
          IconButton(
            tooltip: 'Share itinerary',
            onPressed: _hasStops ? _shareItinerary : null,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      floatingActionButton: _hasStops
          ? FloatingActionButton.extended(
              onPressed: _shareItinerary,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share Itinerary'),
            )
          : null,
      body: DecoratedBox(
        decoration: AppTheme.scaffoldDecorationFor(context),
        child: widget.savedDestinations.isEmpty
            ? const EmptyStateWidget(
                title: 'No destinations saved yet',
                subtitle: 'Save some destinations first to build your trip',
                icon: Icons.route_rounded,
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.savedDestinations.length} saved stop${widget.savedDestinations.length == 1 ? '' : 's'} across ${_days.length} day${_days.length == 1 ? '' : 's'}',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _addDay,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Day'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                      itemCount: _entries.length,
                      onReorder: _reorderStop,
                      proxyDecorator: (child, index, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 1, end: 1.02).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final entry = _entries[index];

                        return switch (entry.type) {
                          _PlannerEntryType.header => _DayHeader(
                              key: ValueKey('day-${entry.dayIndex}'),
                              dayNumber: entry.dayIndex + 1,
                              stopCount: _days[entry.dayIndex].length,
                            ),
                          _PlannerEntryType.empty => _EmptyDaySlot(
                              key: ValueKey('empty-${entry.dayIndex}'),
                              dayNumber: entry.dayIndex + 1,
                            ),
                          _PlannerEntryType.stop => Padding(
                              key: ValueKey('stop-${entry.destination!.id}'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DestinationStopCard(
                                destination: entry.destination!,
                                nextStop: _nextStopFor(
                                  entry.dayIndex,
                                  entry.stopIndex!,
                                ),
                                dragHandle: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: const Tooltip(
                                    message: 'Long-press to reorder',
                                    child: Icon(Icons.drag_handle_rounded),
                                  ),
                                ),
                              ),
                            ),
                        };
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final int dayNumber;
  final int stopCount;

  const _DayHeader({
    super.key,
    required this.dayNumber,
    required this.stopCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Day $dayNumber',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$stopCount stop${stopCount == 1 ? '' : 's'}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyDaySlot extends StatelessWidget {
  final int dayNumber;

  const _EmptyDaySlot({
    super.key,
    required this.dayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Drag a destination here for Day $dayNumber',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationStopCard extends StatelessWidget {
  final Destination destination;
  final Destination? nextStop;
  final Widget dragHandle;

  const _DestinationStopCard({
    required this.destination,
    required this.nextStop,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final activities = destination.activities.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.mountainTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.place_rounded,
                  color: cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _distanceLabel(destination, nextStop),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              dragHandle,
            ],
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activities.map((activity) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    activity,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _distanceLabel(Destination current, Destination? next) {
    if (next == null) return 'Final stop for this day';

    final currentLat = current.latitude;
    final currentLng = current.longitude;
    final nextLat = next.latitude;
    final nextLng = next.longitude;

    if (currentLat == null ||
        currentLng == null ||
        nextLat == null ||
        nextLng == null) {
      return 'Distance to ${next.name} unavailable';
    }

    final distance = haversineKm(currentLat, currentLng, nextLat, nextLng);
    final formatted =
        distance < 10 ? distance.toStringAsFixed(1) : distance.round();
    return '$formatted km to ${next.name}';
  }
}

enum _PlannerEntryType { header, stop, empty }

class _PlannerEntry {
  final _PlannerEntryType type;
  final int dayIndex;
  final int? stopIndex;
  final Destination? destination;

  const _PlannerEntry._({
    required this.type,
    required this.dayIndex,
    this.stopIndex,
    this.destination,
  });

  const _PlannerEntry.header(int dayIndex)
      : this._(
          type: _PlannerEntryType.header,
          dayIndex: dayIndex,
        );

  const _PlannerEntry.empty(int dayIndex)
      : this._(
          type: _PlannerEntryType.empty,
          dayIndex: dayIndex,
        );

  const _PlannerEntry.stop({
    required int dayIndex,
    required int stopIndex,
    required Destination destination,
  }) : this._(
          type: _PlannerEntryType.stop,
          dayIndex: dayIndex,
          stopIndex: stopIndex,
          destination: destination,
        );
}

class _InsertionTarget {
  final int dayIndex;
  final int stopIndex;

  const _InsertionTarget(this.dayIndex, this.stopIndex);
}
