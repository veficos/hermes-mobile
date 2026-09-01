import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/session/project_dialog.dart';

void main() {
  group('desktop-compatible session move targets', () {
    test('rejects current, home and folderless projects', () {
      expect(
        isSessionMoveTarget({
          'id': 'current',
          'path': r'E:\workspaces',
        }, currentProjectId: 'current'),
        isFalse,
      );
      expect(
        isSessionMoveTarget({'id': 'home', 'is_no_project': true}),
        isFalse,
      );
      expect(isSessionMoveTarget({'id': 'empty', 'repos': const []}), isFalse);
    });

    test('rejects a different project resolving to the current cwd', () {
      expect(
        isSessionMoveTarget({
          'id': 'alias',
          'path': r'E:\Workspaces',
        }, currentCwd: r'e:\workspaces'),
        isFalse,
      );
    });

    test('accepts a project with a different primary or repository path', () {
      expect(
        isSessionMoveTarget({
          'id': 'other',
          'primary_path': r'E:\other',
        }, currentCwd: r'E:\workspaces'),
        isTrue,
      );
      expect(
        isSessionMoveTarget({
          'id': 'repo-project',
          'repos': [
            {'path': r'E:\repo'},
          ],
        }),
        isTrue,
      );
    });
  });
}
