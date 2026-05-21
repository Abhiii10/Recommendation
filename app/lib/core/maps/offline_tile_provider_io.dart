import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _assetPath = 'assets/maps/pokhara.mbtiles';
const String _fileName = 'pokhara.mbtiles';
const int _minimumUsefulMbTilesBytes = 64 * 1024;

bool get supportsOfflineMbTiles => true;

Future<TileProvider?> createOfflineTileProvider() async {
  final mbtilesPath = await _ensureMbTilesFile();

  if (mbtilesPath == null) {
    return null;
  }

  return MbTilesTileProvider.fromPath(
    path: mbtilesPath,
    silenceTileNotFound: true,
  );
}

Future<String?> _ensureMbTilesFile() async {
  try {
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    if (!_looksLikeMbTiles(bytes)) {
      return null;
    }

    final directory = await getApplicationSupportDirectory();
    final mapsDirectory = Directory(p.join(directory.path, 'maps'));

    if (!await mapsDirectory.exists()) {
      await mapsDirectory.create(recursive: true);
    }

    final file = File(p.join(mapsDirectory.path, _fileName));

    if (!await _fileMatches(file, bytes)) {
      await file.writeAsBytes(bytes, flush: true);
    }

    return file.path;
  } catch (_) {
    return null;
  }
}

Future<bool> _fileMatches(File file, Uint8List bytes) async {
  if (!await file.exists()) return false;

  final stat = await file.stat();
  return stat.size == bytes.length;
}

bool _looksLikeMbTiles(Uint8List bytes) {
  if (bytes.lengthInBytes < _minimumUsefulMbTilesBytes) {
    return false;
  }

  const sqliteHeader = <int>[
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

  for (var index = 0; index < sqliteHeader.length; index += 1) {
    if (bytes[index] != sqliteHeader[index]) {
      return false;
    }
  }

  return true;
}
