/// Unit tests for FileTreeStore helpers used by FilesScreen / FileTreePanel.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/file_tree_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final Map<String, List<Map<String, dynamic>>> entriesByPath = {
    '/work': [
      {'name': 'src', 'path': '/work/src', 'is_directory': true},
      {
        'name': 'readme.md',
        'path': '/work/readme.md',
        'is_directory': false,
        'size': 12,
      },
    ],
    '/work/src': [
      {
        'name': 'main.dart',
        'path': '/work/src/main.dart',
        'is_directory': false,
      },
    ],
  };

  @override
  Future<String> fsDefaultCwd() async => '/work';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async {
    return {'entries': entriesByPath[path] ?? const []};
  }

  @override
  Future<Map<String, dynamic>> fsWriteText(String path, String content) async {
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> fsMkdir(String path) async => {'ok': true};

  @override
  Future<void> fsDelete(String path, {bool recursive = false}) async {}

  @override
  Future<Map<String, dynamic>> fsMove(
    String path,
    String dest, {
    bool overwrite = false,
  }) async => {'ok': true};

  @override
  Future<Map<String, dynamic>> fsCopy(
    List<String> sources,
    String destination, {
    bool overwrite = false,
  }) async => {'ok': true};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('init loads default cwd and breadcrumb segments', () async {
    final api = _FakeApi();
    final store = FileTreeStore(() => api);
    await store.init();

    expect(store.cwd, '/work');
    expect(store.root, '/work');
    expect(store.bootstrapping, isFalse);
    expect(store.treeMode, isFalse);
    expect(store.visibleListRows().map((e) => e.name), ['src', 'readme.md']);

    final crumbs = store.breadcrumbSegments();
    expect(crumbs.first.label, '/');
    expect(crumbs.last.label, 'work');
    expect(crumbs.last.path, '/work');

    store.dispose();
  });

  test('selection clipboard and paste bookkeeping', () async {
    final api = _FakeApi();
    final store = FileTreeStore(() => api);
    await store.init();

    store.addToSelection('/work/readme.md');
    expect(store.selecting, isTrue);
    store.copySelectionToClipboard(cut: true);
    expect(store.hasClipboard, isTrue);
    expect(store.clipboardIsCut, isTrue);

    await store.navigateTo('/work/src');
    expect(store.cwd, '/work/src');
    expect(store.selection, isEmpty);

    await store.pasteClipboard();
    expect(store.hasClipboard, isFalse);
    expect(store.clipboardIsCut, isFalse);

    store.dispose();
  });

  test('selectPreview tracks tablet editor target', () async {
    final api = _FakeApi();
    final store = FileTreeStore(() => api);
    await store.init();

    store.selectPreview(
      FsEntry(name: 'readme.md', path: '/work/readme.md', isDirectory: false),
    );
    expect(store.selectedPath, '/work/readme.md');
    expect(store.selectedEntry?.name, 'readme.md');

    store.dispose();
  });

  test(
    'file mutations fail while disconnected without clearing state',
    () async {
      ApiClient? api = _FakeApi();
      final store = FileTreeStore(() => api);
      await store.init();
      store.addToSelection('/work/readme.md');
      store.copySelectionToClipboard(cut: true);
      api = null;

      final entry = FsEntry(
        name: 'readme.md',
        path: '/work/readme.md',
        isDirectory: false,
      );
      await expectLater(store.createFile('new.txt'), throwsStateError);
      await expectLater(store.createDirectory('new'), throwsStateError);
      await expectLater(
        store.renameEntry(entry, 'renamed.md'),
        throwsStateError,
      );
      await expectLater(store.deleteEntry(entry), throwsStateError);
      await expectLater(store.deleteSelection(), throwsStateError);
      await expectLater(store.pasteClipboard(), throwsStateError);
      await expectLater(store.revealInExplorer(entry), throwsStateError);
      expect(store.hasClipboard, isTrue);
      expect(store.selection, contains('/work/readme.md'));

      store.dispose();
    },
  );
}
