import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_run_tracker_app/main.dart';

String legacyJwt(String role) {
  final header = base64UrlEncode(utf8.encode('{"alg":"none"}'))
      .replaceAll('=', '');
  final payload = base64UrlEncode(utf8.encode('{"role":"$role"}'))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  test('accepts Supabase publishable keys', () {
    expect(isAllowedSupabaseClientKey('sb_publishable_example'), isTrue);
  });

  test('accepts a legacy anon JWT', () {
    expect(isAllowedSupabaseClientKey(legacyJwt('anon')), isTrue);
  });

  test('rejects secret and service_role keys', () {
    expect(isAllowedSupabaseClientKey('sb_secret_example'), isFalse);
    expect(isAllowedSupabaseClientKey(legacyJwt('service_role')), isFalse);
  });
}
