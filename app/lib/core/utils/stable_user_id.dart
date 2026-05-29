import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:rural_tourism_app/features/auth/data/services/auth_session_service.dart';

Future<String> resolveStableUserId() async {
  try {
    final authenticatedUserId =
        await AuthSessionService.instance.currentUserId();
    if (authenticatedUserId != null && authenticatedUserId.isNotEmpty) {
      return authenticatedUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('stable_user_id');

    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('stable_user_id', id);
    }

    return id;
  } catch (_) {
    return 'anonymous';
  }
}
