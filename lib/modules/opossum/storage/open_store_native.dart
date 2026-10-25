import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../tournament_store.dart';

Future<TournamentStore> openTournamentStore() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return TournamentStore.open(
      databaseFactoryFfi,
      path.join(directory.path, 'opossum-v1.sqlite'),
    );
  }
  return TournamentStore.open(
    mobile.databaseFactory,
    path.join(directory.path, 'opossum-v1.sqlite'),
  );
}
