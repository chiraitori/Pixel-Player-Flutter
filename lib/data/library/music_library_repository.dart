import '../../core/models/song.dart';

/// Flutter boundary for the Kotlin MediaStore/database repository layer.
///
/// Provider-backed libraries can implement the same contract and merge their
/// results without coupling presentation state to a particular Android API.
abstract interface class MusicLibraryRepository {
  Future<List<Song>> loadSongs({String? allowedDirectory});
}
