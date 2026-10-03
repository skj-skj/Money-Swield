import '../data/repositories/restore_repository.dart';
import '../data/services/database/app_database.dart';
import '../data/services/document_service.dart';
import 'app_dependencies.dart';

/// What a restore needs that doesn't depend on an open database. Built once
/// in `main()`, so a restore can also start from the startup-failed screen,
/// where there are no [AppDependencies] (phase-3.md §6.6).
class RestoreTools {
  RestoreTools({
    required this.appDatabase,
    required this.documents,
    required this.deviceCurrency,
  });

  final AppDatabase appDatabase;
  final DocumentService documents;

  /// The default currency when a restored database stores none.
  final String deviceCurrency;

  late final repository = RestoreRepository(
    appDatabase: appDatabase,
    probe: (db) => AppDependencies.probe(db, deviceCurrency: deviceCurrency),
  );
}
