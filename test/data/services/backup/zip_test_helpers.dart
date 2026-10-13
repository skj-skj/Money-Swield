import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One entry for [buildZip]. `stored` keeps it uncompressed, so a test can
/// flip a byte of its data without breaking the deflate stream.
typedef ZipEntry = ({String name, List<int> bytes, bool stored});

ZipEntry entry(String name, List<int> bytes, {bool stored = false}) =>
    (name: name, bytes: bytes, stored: stored);

ZipEntry textEntry(String name, String text) => entry(name, utf8.encode(text));

/// A zip with exactly [entries], in order, duplicates included (unlike
/// `Archive`, which keeps one entry per name).
Uint8List buildZip(List<ZipEntry> entries) {
  final output = OutputMemoryStream();
  final encoder = ZipEncoder()..startEncode(output);
  for (final e in entries) {
    final file = ArchiveFile.bytes(e.name, e.bytes);
    if (e.stored) file.compression = CompressionType.none;
    encoder.add(file);
  }
  encoder.endEncode();
  return output.getBytes();
}

/// A manifest as JSON text; [overrides] replace or add fields, and a null
/// value removes one.
String manifestJson([Map<String, Object?> overrides = const {}]) {
  final fields = <String, Object?>{
    'app': 'money_swield',
    'format': 1,
    'app_version': '1.0.0+1',
    'schema_version': 1790960267,
    'created_at': '2026-10-03T08:35:12Z',
    'includes_photos': false,
    'photos': <Object>[],
  };
  for (final MapEntry(:key, :value) in overrides.entries) {
    if (value == null) {
      fields.remove(key);
    } else {
      fields[key] = value;
    }
  }
  return jsonEncode(fields);
}

const _localHeader = 0x04034b50;
const _centralHeader = 0x02014b50;

/// Rewrites the uncompressed size [name] declares, in both its local and
/// its central directory header, the way a zip bomb lies about it.
void patchDeclaredSize(Uint8List zip, String name, int size) {
  final data = ByteData.sublistView(zip);
  var patched = 0;
  for (var i = 0; i + 46 <= zip.length; i++) {
    final signature = data.getUint32(i, Endian.little);
    if (signature == _localHeader && _nameAt(zip, data, i, 26, 30) == name) {
      data.setUint32(i + 22, size, Endian.little);
      patched++;
    } else if (signature == _centralHeader &&
        _nameAt(zip, data, i, 28, 46) == name) {
      data.setUint32(i + 24, size, Endian.little);
      patched++;
    }
  }
  if (patched != 2) throw StateError('Patched $patched headers of $name');
}

/// Offset of [name]'s first data byte (after its local header).
int dataOffsetOf(Uint8List zip, String name) {
  final data = ByteData.sublistView(zip);
  for (var i = 0; i + 30 <= zip.length; i++) {
    if (data.getUint32(i, Endian.little) == _localHeader &&
        _nameAt(zip, data, i, 26, 30) == name) {
      final nameLength = data.getUint16(i + 26, Endian.little);
      final extraLength = data.getUint16(i + 28, Endian.little);
      return i + 30 + nameLength + extraLength;
    }
  }
  throw StateError('No local header for $name');
}

String _nameAt(Uint8List zip, ByteData data, int at, int lengthAt, int from) {
  final length = data.getUint16(at + lengthAt, Endian.little);
  final start = at + from;
  if (start + length > zip.length) return '';
  return latin1.decode(zip.sublist(start, start + length));
}
