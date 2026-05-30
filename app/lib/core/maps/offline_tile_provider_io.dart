import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _assetPath = 'assets/maps/pokhara.mbtiles';
const String _fileName = 'pokhara.mbtiles';
const int _minimumUsefulMbTilesBytes = 1024 * 1024;
const int _expectedMbTilesBytes = 8171520;
const Duration _mbTilesCopyTimeout = Duration(seconds: 30);
const _sqliteHeader = <int>[
  0x53,
  0x51,
  0x4c,
  0x69,
  0x74,
  0x65,
  0x20,
  0x66,
  0x6f,
  0x72,
  0x6d,
  0x61,
  0x74,
  0x20,
  0x33,
  0x00,
];

bool get supportsOfflineMbTiles => true;

Future<TileProvider?> createOfflineTileProvider() async {
  final mbtilesPath = await _ensureMbTilesFile();

  if (mbtilesPath == null) {
    return null;
  }

  final mbtilesFile = File(mbtilesPath);
  if (!mbtilesFile.existsSync() || mbtilesFile.lengthSync() == 0) {
    debugPrint(
      'WARNING: Offline MBTiles file is empty or missing; using online tiles.',
    );
    return null;
  }

  return MbTilesTileProvider.fromPath(
    path: mbtilesPath,
    silenceTileNotFound: true,
  );
}

Future<String?> _ensureMbTilesFile() async {
  try {
    final directory = await getApplicationSupportDirectory();
    final mapsDirectory = Directory(p.join(directory.path, 'maps'));

    if (!await mapsDirectory.exists()) {
      await mapsDirectory.create(recursive: true);
    }

    final file = File(p.join(mapsDirectory.path, _fileName));
    if (await _fileLooksUsable(file)) {
      return file.path;
    }

    return _copyBundledMbTiles(file).timeout(
      _mbTilesCopyTimeout,
      onTimeout: () {
        debugPrint(
          'WARNING: Offline MBTiles copy timed out; using online tiles.',
        );
        return null;
      },
    );
  } catch (_) {
    return null;
  }
}

Future<String?> _copyBundledMbTiles(File file) async {
  try {
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    if (!_looksLikeMbTiles(bytes)) {
      return null;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<bool> _fileLooksUsable(File file) async {
  if (!await file.exists()) return false;

  final stat = await file.stat();
  if (stat.size != _expectedMbTilesBytes ||
      stat.size < _minimumUsefulMbTilesBytes) {
    return false;
  }

  try {
    final randomAccessFile = await file.open();
    try {
      final header = await randomAccessFile.read(_sqliteHeader.length);
      return _hasSqliteHeader(header);
    } finally {
      await randomAccessFile.close();
    }
  } catch (_) {
    return false;
  }
}

bool _looksLikeMbTiles(Uint8List bytes) {
  if (bytes.lengthInBytes < _minimumUsefulMbTilesBytes) {
    return false;
  }

  return _hasSqliteHeader(bytes);
}

bool _hasSqliteHeader(Uint8List bytes) {
  if (bytes.lengthInBytes < _sqliteHeader.length) return false;

  for (var index = 0; index < _sqliteHeader.length; index += 1) {
    if (bytes[index] != _sqliteHeader[index]) {
      return false;
    }
  }

  return true;
}
