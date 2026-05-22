import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability/app_telemetry.dart';
import 'data/datasources/user_profile_local_datasource.dart';
import 'data/repositories/shared_preferences_user_profile_repository.dart';
import 'data/repositories/user_profile_repository_impl.dart';
import 'l10n/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'services/local_data_service.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';

late final UserProfileService userProfileService;

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await AppTelemetry.instance.initialize();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(
          AppTelemetry.instance.captureException(
            details.exception,
            details.stack ?? StackTrace.current,
            context: {'library': details.library},
          ),
        );
      };

      if (kIsWeb) {
        userProfileService = UserProfileService(
          const SharedPreferencesUserProfileRepository(),
        );
      } else {
        await LocalDataService.instance.init();

        final db = LocalDataService.instance.database;
        final datasource = UserProfileLocalDatasource(db);
        final repo = UserProfileRepositoryImpl(datasource);
        userProfileService = UserProfileService(repo);
      }

      await userProfileService.initOnLaunch();

      runApp(
        const ProviderScope(
          child: RuralTourismApp(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        AppTelemetry.instance.captureException(
          error,
          stackTrace,
          context: {'source': 'runZonedGuarded'},
        ),
      );
    },
  );
}

class RuralTourismApp extends StatefulWidget {
  const RuralTourismApp({super.key});

  @override
  State<RuralTourismApp> createState() => _RuralTourismAppState();
}

class _RuralTourismAppState extends State<RuralTourismApp> {
  final ValueNotifier<ThemeMode> _themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardScreen(themeMode: _themeMode),
        );
      },
    );
  }
}
