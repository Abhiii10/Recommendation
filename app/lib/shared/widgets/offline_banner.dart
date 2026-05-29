import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:rural_tourism_app/l10n/app_localizations.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _onlineTimer;

  bool _offline = false;
  bool _showBackOnline = false;
  bool _hasSeenOffline = false;

  @override
  void initState() {
    super.initState();
    unawaited(_primeConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _primeConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    if (!mounted) return;
    _updateStatus(results, initial: true);
  }

  void _updateStatus(
    List<ConnectivityResult> results, {
    bool initial = false,
  }) {
    final nowOffline = results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none);

    _onlineTimer?.cancel();

    if (nowOffline) {
      setState(() {
        _offline = true;
        _showBackOnline = false;
        _hasSeenOffline = true;
      });
      return;
    }

    setState(() {
      _offline = false;
      _showBackOnline = _hasSeenOffline && !initial;
    });

    if (_showBackOnline) {
      _onlineTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _showBackOnline = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _offline
              ? _Banner(
                  key: const ValueKey('offline'),
                  icon: Icons.wifi_off_rounded,
                  label: AppLocalizations.of(context).noInternet,
                  color: AppTheme.earthOchre,
                )
              : _showBackOnline
                  ? _Banner(
                      key: const ValueKey('online'),
                      icon: Icons.wifi_rounded,
                      label: AppLocalizations.of(context).backOnline,
                      color: AppTheme.mountainTeal,
                    )
                  : const SizedBox.shrink(key: ValueKey('hidden')),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Banner({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
