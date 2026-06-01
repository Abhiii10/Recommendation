import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectivityOfflineStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield initial.contains(ConnectivityResult.none);

  yield* connectivity.onConnectivityChanged.map(
    (results) => results.contains(ConnectivityResult.none),
  );
});

final offlineProvider = Provider<bool>((ref) {
  return ref.watch(_connectivityOfflineStreamProvider).maybeWhen(
        data: (isOffline) => isOffline,
        orElse: () => false,
      );
});
