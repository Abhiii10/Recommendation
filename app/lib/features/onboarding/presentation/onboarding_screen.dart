import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/profile/application/user_profile_service.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  static const completionKey = 'onboarding_complete';

  final UserProfileService userProfileService;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.userProfileService,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _travelStyles = [
    _OnboardingOption(
      id: 'trekking',
      label: 'Trekking',
      icon: Icons.hiking_rounded,
    ),
    _OnboardingOption(
      id: 'cultural',
      label: 'Cultural',
      icon: Icons.account_balance_rounded,
    ),
    _OnboardingOption(
      id: 'relaxation',
      label: 'Relaxation',
      icon: Icons.spa_rounded,
    ),
    _OnboardingOption(
      id: 'adventure',
      label: 'Adventure',
      icon: Icons.terrain_rounded,
    ),
  ];

  static const _budgetLevels = [
    _OnboardingOption(
      id: 'budget',
      label: 'Budget',
      icon: Icons.savings_rounded,
    ),
    _OnboardingOption(
      id: 'medium',
      label: 'Medium',
      icon: Icons.wallet_rounded,
    ),
    _OnboardingOption(
      id: 'premium',
      label: 'Premium',
      icon: Icons.diamond_rounded,
    ),
  ];

  static const _seasons = [
    _OnboardingOption(
      id: 'spring',
      label: 'Spring',
      icon: Icons.local_florist_rounded,
    ),
    _OnboardingOption(
      id: 'summer',
      label: 'Summer',
      icon: Icons.wb_sunny_rounded,
    ),
    _OnboardingOption(
      id: 'autumn',
      label: 'Autumn',
      icon: Icons.forest_rounded,
    ),
    _OnboardingOption(
      id: 'winter',
      label: 'Winter',
      icon: Icons.ac_unit_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  final Set<String> _selectedStyles = {};
  final Set<String> _selectedSeasons = {};

  int _page = 0;
  String _budget = 'medium';
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSetValue(Set<String> values, String value) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else {
        values.add(value);
      }
    });
  }

  void _selectBudget(String value) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _budget = value);
  }

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _back() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _complete({required bool savePreferences}) async {
    if (_saving) return;

    unawaited(HapticFeedback.selectionClick());
    setState(() => _saving = true);

    if (savePreferences) {
      await widget.userProfileService.recordBookmark(_preferenceDestination());
      if (!mounted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await prefs.setBool(OnboardingScreen.completionKey, true);
    if (!mounted) return;

    widget.onComplete();
  }

  Destination _preferenceDestination() {
    final categories = _selectedStyles.isEmpty
        ? const ['cultural']
        : _selectedStyles.toList(growable: false);
    final seasons = _selectedSeasons.isEmpty
        ? const ['spring', 'autumn']
        : _selectedSeasons.toList(growable: false);

    return Destination(
      id: 'onboarding-preference-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Onboarding Preference',
      province: 'Nepal',
      category: categories,
      activities: categories,
      bestSeason: seasons,
      budgetLevel: _budget,
      accessibility: 'moderate',
      familyFriendly: true,
      shortDescription: 'Preference signal from onboarding.',
      fullDescription: 'Preference signal from onboarding.',
      tags: [
        'budget_$_budget',
        ...seasons.map((season) => 'season_$season'),
      ],
      source: 'onboarding',
      confidence: 'high',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: AppTheme.scaffoldDecorationFor(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: _page == 0
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _saving ? null : _back,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back'),
                              ),
                            ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => unawaited(
                                _complete(savePreferences: false),
                              ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _OnboardingPage(
                      eyebrow: 'Travel style',
                      title: 'How do you like to explore Nepal?',
                      subtitle:
                          'Pick the styles that feel like your kind of trip.',
                      child: _OptionWrap(
                        options: _travelStyles,
                        selectedValues: _selectedStyles,
                        onSelected: (value) =>
                            _toggleSetValue(_selectedStyles, value),
                      ),
                    ),
                    _OnboardingPage(
                      eyebrow: 'Budget level',
                      title: 'Choose your comfort zone',
                      subtitle:
                          'This helps shape destination and stay suggestions.',
                      child: _OptionWrap(
                        options: _budgetLevels,
                        selectedValues: {_budget},
                        onSelected: _selectBudget,
                      ),
                    ),
                    _OnboardingPage(
                      eyebrow: 'Preferred season',
                      title: 'When do you want to travel?',
                      subtitle:
                          'Select one or more seasons for better matching.',
                      child: _OptionWrap(
                        options: _seasons,
                        selectedValues: _selectedSeasons,
                        onSelected: (value) =>
                            _toggleSetValue(_selectedSeasons, value),
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressDots(activeIndex: _page, count: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: _page == 2
                      ? FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () => unawaited(
                                    _complete(savePreferences: true),
                                  ),
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.explore_rounded),
                          label: Text(
                            _saving ? 'Saving...' : 'Get Started',
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _saving ? null : _next,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingPage({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.64),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      eyebrow,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  final List<_OnboardingOption> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onSelected;

  const _OptionWrap({
    required this.options,
    required this.selectedValues,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final selected = selectedValues.contains(option.id);
        return FilterChip(
          selected: selected,
          avatar: Icon(
            option.icon,
            size: 16,
            color: selected ? cs.onPrimaryContainer : cs.primary,
          ),
          label: Text(option.label),
          labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: cs.surfaceContainerHighest,
          selectedColor: cs.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          onSelected: (_) => onSelected(option.id),
        );
      }).toList(),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int activeIndex;
  final int count;

  const _ProgressDots({
    required this.activeIndex,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.mountainTeal : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _OnboardingOption {
  final String id;
  final String label;
  final IconData icon;

  const _OnboardingOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}
