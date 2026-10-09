import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// SHA-256 as the app names photos by it (phase-6.md §4.3): 64 lower-case
/// hex digits. One implementation for staging, backups and restores.
class Sha256Builder {
  // Closed through [_input] in [close], which every user calls: that is
  // what yields the digest. The lint can't follow it.
  // ignore: close_sinks
  final _digest = _DigestSink();
  late final _input = sha256.startChunkedConversion(_digest);

  void add(List<int> chunk) => _input.add(chunk);

  /// Ends the input; the digest of everything added, as hex.
  String close() {
    _input.close();
    return _digest.value.toString();
  }
}

/// The SHA-256 of the file at [path], read in chunks (a 64 MB original is
/// never held whole).
String sha256OfFileSync(String path) {
  final builder = Sha256Builder();
  final file = File(path).openSync();
  try {
    while (true) {
      final chunk = file.readSync(64 * 1024);
      if (chunk.isEmpty) break;
      builder.add(chunk);
    }
  } finally {
    file.closeSync();
  }
  return builder.close();
}

/// [sha256OfFileSync] on another isolate, so a large file doesn't stall
/// the UI thread.
Future<String> sha256OfFile(String path) =>
    Isolate.run(() => sha256OfFileSync(path));

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
