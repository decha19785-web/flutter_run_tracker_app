import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/run_entry.dart';

class RunRepository {
  RunRepository(this.client);

  final SupabaseClient client;

  Future<List<RunEntry>> getRuns() async {
    final rows = await client
        .from('run_tb')
        .select(
          'place, distance_km, duration_minutes, run_date, note, image_path',
        )
        .order('run_date', ascending: false);
    final runs = <RunEntry>[];
    for (final row in rows) {
      final imagePath = row['image_path'] as String?;
      final imageUrl = imagePath == null ? null : await _signedUrl(imagePath);
      runs.add(
        RunEntry(
          place: row['place'] as String,
          distance: (row['distance_km'] as num).toDouble(),
          minutes: (row['duration_minutes'] as num).toInt(),
          date: DateTime.parse(row['run_date'] as String),
          note: (row['note'] as String?) ?? '',
          imagePath: imagePath,
          imageUrl: imageUrl,
        ),
      );
    }
    return runs;
  }

  Future<RunEntry> addRun(RunEntry run) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('กรุณาเข้าสู่ระบบก่อนบันทึกข้อมูล');
    String? imagePath;
    if (run.imageBytes != null) {
      final extension = run.imageExtension ?? 'jpg';
      imagePath =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await client.storage
          .from('run-images')
          .uploadBinary(
            imagePath,
            run.imageBytes!,
            fileOptions: FileOptions(
              contentType: switch (extension) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                'heic' => 'image/heic',
                'heif' => 'image/heif',
                _ => 'image/jpeg',
              },
            ),
          );
    }
    try {
      await client.from('run_tb').insert({
        'user_id': user.id,
        'place': run.place,
        'distance_km': run.distance,
        'duration_minutes': run.minutes,
        'run_date': run.date.toIso8601String().split('T').first,
        'note': run.note,
        'image_path': imagePath,
      });
    } catch (_) {
      if (imagePath != null) {
        await client.storage.from('run-images').remove([imagePath]);
      }
      rethrow;
    }
    final imageUrl = imagePath == null ? null : await _signedUrl(imagePath);
    return RunEntry(
      place: run.place,
      distance: run.distance,
      minutes: run.minutes,
      date: run.date,
      note: run.note,
      imagePath: imagePath,
      imageUrl: imageUrl,
    );
  }

  Future<String?> _signedUrl(String path) async {
    try {
      return await client.storage
          .from('run-images')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
