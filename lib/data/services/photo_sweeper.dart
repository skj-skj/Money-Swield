import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/expense_draft.dart';
import '../../domain/photo_sweep.dart';
import '../../domain/photos.dart';
import '../repositories/expense_draft_repository.dart';
import 'photo_store.dart';

/// What one sweep did, for the log and tests.
typedef SweepResult = ({int rows, int files, bool filesSkipped});

/// The only code that deletes photo rows and files. Runs once at startup, after
/// the bin purge, before any form can save, so nothing is half-saved while it
/// looks.
///
/// A file is deleted only when nothing can still need it: the live
/// database's rows, the live draft, the camera's pending shot, and every
/// pre-restore copy's rows and draft ("Undo last restore" brings those
/// back). If the live draft or any copy can't be read, no file is
/// deleted at all, and a copy that keeps failing blocks file deletion
/// until it is pruned: leaving a file costs space, deleting a needed one
/// loses a photo.
///
/// Deliberately stricter than the plain rule: when the live draft can't
/// be read, unlinked **rows** stay too. Its saved photos are known only from
/// it, and deleting such a row would drop that photo from the draft when it is
/// opened.
class PhotoSweeper {
  PhotoSweeper({
    required this._db,
    required this._drafts,
    required this._store,
    required this._preRestoreCopies,
    required this._openReadOnly,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Database _db;
  final ExpenseDraftRepository _drafts;
  final PhotoStore _store;

  /// The paths of the complete pre-restore copies.
  final Future<List<String>> Function() _preRestoreCopies;

  /// Opens another database file read-only, on its own connection.
  final Future<Database> Function(String path) _openReadOnly;

  final DateTime Function() _now;

  /// A camera shot older than this is given up.
  static const captureLifetime = Duration(days: 30);

  Future<SweepResult> sweep() async {
    if (!_store.isAvailable) return (rows: 0, files: 0, filesSkipped: true);
    final paths = <String>{};
    final staging = <String>{};
    var filesBlocked = false;

    // 1. References. The live draft first: its saved ids keep rows.
    ExpenseDraft? liveDraft;
    var draftRead = true;
    try {
      liveDraft = await _drafts.read();
    } catch (error) {
      debugPrint('Photo sweep: the draft can\'t be read: $error');
      draftRead = false;
      filesBlocked = true;
    }
    if (liveDraft != null) _addDraft(liveDraft, paths, staging);

    final capture = await _store.pendingCapture();
    if (capture != null) {
      if (_now().difference(capture.at) > captureLifetime) {
        await _store.clearPendingCapture();
      } else {
        staging.add(capture.name);
      }
    }

    try {
      for (final copy in await _preRestoreCopies()) {
        await _addCopy(copy, paths, staging);
      }
    } catch (error) {
      debugPrint('Photo sweep: a pre-restore copy can\'t be read: $error');
      filesBlocked = true;
    }

    // 2. Rows no expense links and the live draft doesn't name.
    var rows = 0;
    if (draftRead) {
      final draftIds = [
        for (final photo in liveDraft?.photos ?? const <FormPhoto>[])
          if (photo is SavedPhoto) photo.id,
      ]..sort();
      rows = await _db.rawDelete(
        'DELETE FROM photos '
        'WHERE id NOT IN (SELECT photo_id FROM expense_photos) '
        // Ints from our own draft, as literals: no variable limit.
        'AND id NOT IN (${draftIds.join(', ')})',
      );
    }

    // 3. Every live row's file is in use.
    paths.addAll(await photoPathsOf(_db));

    if (filesBlocked) return (rows: rows, files: 0, filesSkipped: true);

    // 4. Files.
    final plan = sweepPlan(
      photoFilesOnDisk: await _names(_store.photosPath),
      stagingFilesOnDisk: await _names(_store.stagingPath),
      referencedPaths: paths,
      referencedStaging: staging,
    );
    var files = 0;
    for (final (folder, names) in [
      (_store.photosPath, plan.photoFiles),
      (_store.stagingPath, plan.stagingFiles),
    ]) {
      for (final name in names) {
        try {
          await File(p.join(folder, name)).delete();
          files++;
        } catch (error) {
          debugPrint('Photo sweep: deleting $name failed: $error');
        }
      }
    }
    return (rows: rows, files: files, filesSkipped: false);
  }

  /// Every `relative_path` of [db]'s `photos`, read as one text per block of
  /// 2,000 ids rather than one row per photo: with 10,000 photos the
  /// row-per-photo read took ~315 ms of a ~470 ms sweep on the Oppo (profile
  /// build), every row a map through sqflite's channel. A block stays far below
  /// Android's 2 MB cursor window (2,000 × ~76 bytes). The live rows and the
  /// pre-restore copies'. A valid path never holds a newline
  /// (`isValidPhotoPath`); one that did would split into more paths to keep,
  /// never fewer.
  static Future<List<String>> photoPathsOf(DatabaseExecutor db) async {
    final blocks = await db.rawQuery(
      'SELECT group_concat(relative_path, char(10)) AS paths FROM photos '
      'GROUP BY id / 2000',
    );
    return [
      for (final block in blocks) ...(block['paths']! as String).split('\n'),
    ];
  }

  static void _addDraft(
    ExpenseDraft draft,
    Set<String> paths,
    Set<String> staging,
  ) {
    for (final photo in draft.photos) {
      switch (photo) {
        case SavedPhoto(:final relativePath):
          paths.add(relativePath);
        case StagedPhoto(:final stagingName):
          staging.add(stagingName);
      }
    }
  }

  /// A pre-restore copy's photo paths (if it has the table: a copy from
  /// before photos existed has none) and its draft's photos. Throws when the copy
  /// can't be read.
  Future<void> _addCopy(
    String path,
    Set<String> paths,
    Set<String> staging,
  ) async {
    final db = await _openReadOnly(path);
    try {
      final hasPhotos = await db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'photos'",
      );
      // In blocks like the live rows: two copies of 10,000 photos read row
      // by row took the sweep from ~240 to ~540 ms on the Oppo.
      if (hasPhotos.isNotEmpty) paths.addAll(await photoPathsOf(db));
      final draft = await ExpenseDraftRepository.readDraft(db);
      if (draft != null) _addDraft(draft, paths, staging);
    } finally {
      await db.close();
    }
  }

  /// The file names in [folder]; none when it doesn't exist yet. Listed here:
  /// on another isolate (`listSync`) the sweep was slower with 10,000 files,
  /// ~290 ms against ~250, the names being sent back.
  static Future<List<String>> _names(String folder) async {
    final directory = Directory(folder);
    if (!await directory.exists()) return const [];
    return [
      await for (final entity in directory.list(followLinks: false))
        if (entity is File) p.basename(entity.path),
    ];
  }
}
