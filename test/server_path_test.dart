import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_mobile/core/server_path.dart';

void main() {
  group('ServerPath POSIX', () {
    test('parent walks up without inventing backslashes', () {
      expect(
        ServerPath.parent('/home/veficos/hermes-mobile/server'),
        '/home/veficos/hermes-mobile',
      );
      expect(ServerPath.parent('/home/veficos'), '/home');
      expect(ServerPath.parent('/home'), '/');
      expect(ServerPath.parent('/'), '');
    });

    test('join keeps forward slashes', () {
      expect(
        ServerPath.join('/home/veficos', 'hermes-mobile'),
        '/home/veficos/hermes-mobile',
      );
      expect(
        ServerPath.join('/home/veficos/', 'hermes-mobile'),
        '/home/veficos/hermes-mobile',
      );
    });

    test('normalize converts stray backslashes', () {
      expect(
        ServerPath.normalize(r'/home\veficos\hermes-mobile'),
        '/home/veficos/hermes-mobile',
      );
    });

    test('basename and extension are style-aware', () {
      expect(ServerPath.basename('/home/veficos/a.txt'), 'a.txt');
      expect(ServerPath.extension('/home/veficos/a.txt'), '.txt');
      expect(ServerPath.basename(r'C:\Users\foo\a.txt'), 'a.txt');
      expect(ServerPath.extension(r'C:\Users\foo\a.txt'), '.txt');
    });
  });

  group('ServerPath Windows', () {
    test('parent keeps drive roots', () {
      expect(
        ServerPath.parent(r'C:\Users\veficos\project'),
        r'C:\Users\veficos',
      );
      expect(ServerPath.parent(r'C:\Users'), r'C:\');
      expect(ServerPath.parent(r'C:\'), '');
      expect(ServerPath.parent(r'C:'), '');
    });

    test('join keeps backslashes', () {
      expect(ServerPath.join(r'C:\Users', 'veficos'), r'C:\Users\veficos');
      expect(ServerPath.join(r'C:\Users\', 'veficos'), r'C:\Users\veficos');
    });

    test('accepts forward-slash Windows paths', () {
      expect(ServerPath.normalize('C:/Users/veficos'), r'C:\Users\veficos');
      expect(ServerPath.parent('C:/Users/veficos'), r'C:\Users');
    });
  });
}
