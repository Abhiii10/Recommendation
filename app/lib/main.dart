import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data/datasources/user_profile_local_datasource.dart';
import 'data/repositories/user_profile_repository_impl.dart';
import 'screens/dashboard_screen.dart';
import 'services/local_data_service.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';

late final UserProfileService userProfileService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await LocalDataService.instance.init();

  final db = LocalDataService.instance.database;
  final datasource = UserProfileLocalDatasource(db);
  final repo = UserProfileRepositoryImpl(datasource);
  userProfileService = UserProfileService(repo);

  await userProfileService.initOnLaunch();

  runApp(const RuralTourismApp());
}

class RuralTourismApp extends StatelessWidget {
  const RuralTourismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gandaki Tourism Guide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const DashboardScreen(),
    );
  }
}