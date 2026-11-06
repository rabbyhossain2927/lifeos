import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/services/store.dart';

void main() {
  test('empty [] from the server becomes {} for map fields only', () {
    final d = cleanDoc({'logs': [], 'wins': [], 'license': {'key': 'A'}, 'reset': [], 'n': 1});
    expect(d['logs'], isA<Map>());
    expect(d['reset'], isA<Map>());
    expect(d['wins'], isA<List>());
    expect((d['license'] as Map)['key'], 'A');
    expect(cleanDoc([]), isEmpty);
  });
}
