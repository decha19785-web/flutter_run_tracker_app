import 'dart:typed_data';

class RunEntry {
  RunEntry({
    required this.place,
    required this.distance,
    required this.minutes,
    required this.date,
    this.note = '',
    this.imageBytes,
    this.imageExtension,
    this.imagePath,
    this.imageUrl,
  });

  final String place;
  final double distance;
  final int minutes;
  final DateTime date;
  final String note;
  // Set only on a new entry before upload. These bytes are never stored in Postgres.
  final Uint8List? imageBytes;
  final String? imageExtension;
  final String? imagePath;
  final String? imageUrl;

  String get pace {
    final seconds = (minutes * 60 / distance).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
