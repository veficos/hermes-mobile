import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:hermes_mobile/screens/file_editor_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tablet split view: the embedded FileEditorScreen has no route of its own,
/// so PopScope cannot guard it. Tapping another file (or navigating) used to
/// silently destroy unsaved edits; the split view must now confirm first.
class _FilesApi extends ApiClient {
  _FilesApi() : super(baseUrl: 'http://files.invalid', apiKey: 'test');
  Completer<Map<String, dynamic>>? pendingWrite;
  Completer<String>? pendingRead;
  int writes = 0;

  @override
  Future<Map<String, dynamic>> fsWriteText(
    String path,
    String content, {
    String? profile,
  }) async {
    writes++;
    final result =
        await (pendingWrite?.future ?? Future.value(<String, dynamic>{}));
    fileContents[path] = content;
    return result;
  }

  final Map<String, String> fileContents = {
    '/workspace/a.txt': 'aaa',
    '/workspace/b.txt': 'bbb',
  };

  @override
  Future<String> fsDefaultCwd() async => '/workspace';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async => {
    'entries': [
      {
        'name': 'a.txt',
        'path': '/workspace/a.txt',
        'is_directory': false,
        'size': 3,
      },
      {
        'name': 'b.txt',
        'path': '/workspace/b.txt',
        'is_directory': false,
        'size': 3,
      },
    ],
  };

  @override
  Future<String> fsReadText(String path, {String? profile}) async =>
      pendingRead == null ? fileContents[path]! : await pendingRead!.future;
}

Future<void> _pumpTablet(
  WidgetTester tester, {
  _FilesApi? api,
  bool liquid = false,
  double width = 1200,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  Locale locale = const Locale('en'),
  Widget home = const FilesScreen(),
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final connection = ConnectionStore()..api = api ?? _FilesApi();
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionStore>.value(
      value: connection,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        theme: buildHermesTheme(
          brightness: brightness,
          highContrast: highContrast,
          visualStyle: liquid
              ? HermesVisualStyle.liquid
              : HermesVisualStyle.classic,
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  for (final modifier in [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    testWidgets('save shortcut rejects loading and failed file $modifier', (
      tester,
    ) async {
      final api = _FilesApi()..pendingRead = Completer<String>();
      await _pumpTablet(
        tester,
        api: api,
        liquid: true,
        width: 390,
        settle: false,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      Future<void> saveShortcut() async {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }

      await saveShortcut();
      expect(api.writes, 0);
      api.pendingRead!.completeError(StateError('read failed'));
      await tester.pumpAndSettle();
      await saveShortcut();
      expect(api.writes, 0);
      expect(api.fileContents['/workspace/a.txt'], 'aaa');
      api.pendingRead = null;
      final retry = find.text('Retry');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'recovered draft');
      await saveShortcut();
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(api.fileContents['/workspace/a.txt'], 'recovered draft');
      expect(tester.takeException(), isNull);
    });
  }
  for (final stale in [false, true]) {
    testWidgets('Liquid replace respects current source stale=$stale', (
      tester,
    ) async {
      await _pumpTablet(
        tester,
        liquid: true,
        width: 320,
        scale: 2,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      final source = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(GlassAlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, 'a');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(fields.last);
      await tester.pumpAndSettle();
      expect(fields.last.hitTestable(), findsOneWidget);
      await tester.enterText(fields.last, 'z');
      if (stale) source.text = 'new content';
      final replace = find.text('Replace all');
      expect(replace.hitTestable(), findsOneWidget);
      expect(tester.getRect(replace).bottom, lessThanOrEqualTo(500));
      await tester.tap(replace);
      await tester.pumpAndSettle();
      expect(source.text, stale ? 'new content' : 'zzz');
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('find reveals match after wrapped history scale=$scale', (
      tester,
    ) async {
      final api = _FilesApi();
      api.fileContents['/workspace/a.txt'] =
          '${List.filled(80, 'long source text 中文 repeated across the narrow editor width').join('\n')}\nTARGET_MATCH\nend';
      await _pumpTablet(
        tester,
        api: api,
        liquid: true,
        width: 320,
        scale: scale,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      final dialog = find.byType(GlassAlertDialog);
      expect(
        tester
            .widgetList<GlassSurface>(
              find.descendant(of: dialog, matching: find.byType(GlassSurface)),
            )
            .any((surface) => surface.role == HermesGlassRole.overlay),
        isTrue,
      );
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)).first,
        'TARGET_MATCH',
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.byType(FilledButton)),
      );
      await tester.pumpAndSettle();
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      final selected = state.widget.controller.selection;
      expect(selected.textInside(state.widget.controller.text), 'TARGET_MATCH');
      final render = state.renderEditable;
      final caret = render.getLocalRectForCaret(
        TextPosition(offset: selected.start),
      );
      final scroll = tester
          .widget<TextField>(find.byType(TextField))
          .scrollController!;
      expect(scroll.offset, greaterThan(1000));
      expect(caret.top, greaterThanOrEqualTo(-1));
      expect(
        caret.bottom,
        lessThanOrEqualTo(scroll.position.viewportDimension + 1),
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('wrapped source keeps logical gutter alignment scale=$scale', (
      tester,
    ) async {
      final api = _FilesApi();
      final firstLine = List.filled(4, 'alpha beta 中文').join(' ');
      api.fileContents['/workspace/a.txt'] = '$firstLine\nsecond\nthird';
      await _pumpTablet(
        tester,
        api: api,
        liquid: true,
        width: 320,
        scale: scale,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final firstCaret = editable.getLocalRectForCaret(
        const TextPosition(offset: 0),
      );
      final secondCaret = editable.getLocalRectForCaret(
        TextPosition(offset: firstLine.length + 1),
      );
      final rowDelta =
          // Actual editor geometry is used below, not an independent painter.
          tester.getTopLeft(find.text('2')).dy -
          tester.getTopLeft(find.text('1')).dy;
      expect(rowDelta, closeTo(secondCaret.top - firstCaret.top, 1));
      expect(rowDelta, greaterThan(firstCaret.height * 2));
      expect(tester.takeException(), isNull);
    });
  }
  for (final liquid in [false, true]) {
    testWidgets('standalone editor navigation protects draft liquid=$liquid', (
      tester,
    ) async {
      await _pumpTablet(
        tester,
        liquid: liquid,
        width: 320,
        scale: 2,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FileEditorScreen(
                    path: '/workspace/a.txt',
                    name: 'a.txt',
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      if (liquid) {
        expect(
          tester
              .widgetList<GlassSurface>(find.byType(GlassSurface))
              .any((surface) => surface.role == HermesGlassRole.navigation),
          isTrue,
        );
      }
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pump();
      final title = tester.widget<Text>(find.textContaining('● a.txt').first);
      final context = tester.element(find.byType(FileEditorScreen));
      expect(
        title.semanticsLabel,
        AppLocalizations.of(context).fileEditorUnsavedTitle('a.txt'),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(FileEditorScreen), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [
    const Locale('en'),
    const Locale('zh'),
    const Locale('zh', 'Hant'),
    const Locale('ja'),
    const Locale('ar'),
  ]) {
    testWidgets(
      'phone editor secondary actions remain reachable in menu $locale',
      (tester) async {
        await _pumpTablet(
          tester,
          liquid: true,
          width: 320,
          scale: 2,
          locale: locale,
          home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(FileEditorScreen)),
        );
        expect(find.byTooltip(l10n.commonSave).hitTestable(), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('file-editor-actions')));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.fileEditorShowChanges).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.fileEditorShowChanges));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('file-editor-actions')));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.fileEditorEditFile).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.fileEditorEditFile));
        await tester.pumpAndSettle();
        expect(find.text('aaa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('five digit gutter expands for large text', (tester) async {
    final api = _FilesApi();
    api.fileContents['/workspace/a.txt'] = List.filled(10000, 'x').join('\n');
    await _pumpTablet(
      tester,
      api: api,
      liquid: true,
      scale: 2,
      home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
    );
    final style = tester.widget<TextField>(find.byType(TextField)).style;
    final painter = TextPainter(
      text: TextSpan(text: '10000', style: style),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(2),
    )..layout();
    final width = tester
        .getSize(find.byKey(const ValueKey('file-editor-gutter')))
        .width;
    expect(width, greaterThanOrEqualTo(painter.width + 16));
    expect(width, greaterThan(44));
    painter.dispose();
    final gutter = find.byKey(const ValueKey('file-editor-gutter'));
    expect(
      find
          .descendant(of: gutter, matching: find.byType(Text))
          .evaluate()
          .length,
      lessThan(100),
    );
    final editor = tester
        .widget<TextField>(find.byType(TextField))
        .scrollController!;
    editor.jumpTo(editor.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('10000'), findsOneWidget);
    final list = tester.widget<ListView>(
      find.descendant(of: gutter, matching: find.byType(ListView)),
    );
    expect(list.controller!.offset, closeTo(editor.offset, 1));
    expect(
      find
          .descendant(of: gutter, matching: find.byType(Text))
          .evaluate()
          .length,
      lessThan(100),
    );
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('gutter tracks scaled source line height $scale', (
      tester,
    ) async {
      final api = _FilesApi();
      api.fileContents['/workspace/a.txt'] = 'one\ntwo\nthree';
      await _pumpTablet(
        tester,
        api: api,
        liquid: true,
        scale: scale,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      final painter = TextPainter(
        text: TextSpan(text: 'one', style: field.style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
      )..layout();
      final expected = painter.preferredLineHeight;
      painter.dispose();
      final first = tester.getTopLeft(find.text('1')).dy;
      final second = tester.getTopLeft(find.text('2')).dy;
      final third = tester.getTopLeft(find.text('3')).dy;
      expect(second - first, closeTo(expected, .01));
      expect(third - second, closeTo(expected, .01));
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('file editor uses accessible reading palette $brightness', (
      tester,
    ) async {
      await _pumpTablet(
        tester,
        liquid: true,
        brightness: brightness,
        highContrast: true,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      final field = find.byType(TextField);
      final palette = HermesPalette.of(tester.element(field));
      expect(tester.widget<TextField>(field).style!.color, palette.text);
      expect(
        tester
            .widget<ColoredBox>(
              find.ancestor(of: field, matching: find.byType(ColoredBox)).first,
            )
            .color,
        palette.codeBg,
      );
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('file-editor-gutter')))
            .color,
        palette.surface,
      );
      final line = tester.widget<Text>(find.text('1'));
      expect(line.style!.color, palette.text2);
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    for (final overwrite in [false, true]) {
      testWidgets(
        'wide Liquid conflict result overwrite=$overwrite scale=$scale',
        (tester) async {
          final api = _FilesApi();
          await _pumpTablet(
            tester,
            api: api,
            liquid: true,
            scale: scale,
            home: const FileEditorScreen(
              path: '/workspace/a.txt',
              name: 'a.txt',
            ),
          );
          await tester.enterText(find.text('aaa'), 'local draft');
          await tester.pump();
          api.fileContents['/workspace/a.txt'] = 'external update';
          await tester.tap(find.byTooltip('Save'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(FileEditorScreen)),
          );
          expect(
            tester
                .widgetList<GlassSurface>(find.byType(GlassSurface))
                .any((surface) => surface.role == HermesGlassRole.overlay),
            isTrue,
          );
          await tester.tap(
            find.text(
              overwrite ? l10n.fileEditorOverwriteSave : l10n.commonReload,
            ),
          );
          await tester.pumpAndSettle();
          final expected = overwrite ? 'local draft' : 'external update';
          expect(api.fileContents['/workspace/a.txt'], expected);
          expect(find.text(expected), findsOneWidget);
          expect(api.writes, overwrite ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'narrow Liquid conflict actions wrap and cancel preserves draft',
    (tester) async {
      final api = _FilesApi();
      await _pumpTablet(
        tester,
        api: api,
        liquid: true,
        width: 390,
        scale: 2,
        home: const FileEditorScreen(path: '/workspace/a.txt', name: 'a.txt'),
      );
      await tester.enterText(find.text('aaa'), 'local draft');
      await tester.pump();
      api.fileContents['/workspace/a.txt'] = 'external update';
      await tester.tap(find.byTooltip('Save'));
      // Save stays busy while the conflict dialog awaits a choice.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('external update'), findsOneWidget);
      expect(find.byType(OverflowBar), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('local draft'), findsOneWidget);
      expect(api.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Liquid file discard uses shared glass overlay', (tester) async {
    await _pumpTablet(tester, liquid: true);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.text('aaa'), 'glass draft');
    await tester.pump();
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .any((surface) => surface.role == HermesGlassRole.overlay),
      isTrue,
    );
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('glass draft'), findsOneWidget);
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('bbb'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed write preserves draft and permits retry', (tester) async {
    final api = _FilesApi()..pendingWrite = Completer<Map<String, dynamic>>();
    await _pumpTablet(tester, api: api);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.text('aaa'), 'retry draft');
    await tester.pump();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    api.pendingWrite!.completeError(StateError('write unavailable'));
    await tester.pumpAndSettle();
    expect(api.fileContents['/workspace/a.txt'], 'aaa');
    expect(find.text('retry draft'), findsOneWidget);
    expect(find.textContaining('write unavailable'), findsOneWidget);
    expect(find.byTooltip('Save').hitTestable(), findsOneWidget);
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    api.pendingWrite = Completer<Map<String, dynamic>>();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect(api.writes, 2);
    api.pendingWrite!.complete({});
    await tester.pumpAndSettle();
    expect(api.fileContents['/workspace/a.txt'], 'retry draft');
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('bbb'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'saving prevents embedded file replacement until write completes',
    (tester) async {
      final api = _FilesApi()..pendingWrite = Completer<Map<String, dynamic>>();
      await _pumpTablet(tester, api: api);
      await tester.tap(find.text('a.txt'));
      await tester.pumpAndSettle();
      await tester.enterText(find.text('aaa'), 'edited');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await tester.pump();
      expect(api.writes, 1);
      final editorContext = tester.element(find.byType(FileEditorScreen));
      final savingLabel = AppLocalizations.of(editorContext).fileEditorSaving;
      final saving = find.byTooltip(savingLabel);
      expect(tester.getSize(saving).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(saving).height, greaterThanOrEqualTo(44));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == savingLabel,
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.liveRegion == true &&
              widget.properties.label == savingLabel,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('b.txt'));
      await tester.pump();
      expect(find.text('Discard unsaved changes?'), findsNothing);
      expect(find.text('edited'), findsOneWidget);
      expect(find.text('bbb'), findsNothing);
      api.pendingWrite!.complete({});
      await tester.pumpAndSettle();
      expect(api.fileContents['/workspace/a.txt'], 'edited');
      await tester.tap(find.text('b.txt'));
      await tester.pumpAndSettle();
      expect(find.text('bbb'), findsOneWidget);
      expect(api.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('switching files with unsaved edits asks before discarding', (
    tester,
  ) async {
    await _pumpTablet(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('aaa'), findsOneWidget);

    // Dirty the embedded editor.
    await tester.enterText(find.text('aaa'), 'aaa edited');
    await tester.pump();

    // Tapping another file must confirm instead of silently dropping edits.
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    // Keep editing: selection stays on a.txt with the edits intact.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('aaa edited'), findsOneWidget);
    expect(find.text('bbb'), findsNothing);

    // Discard: the new file loads.
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('bbb'), findsOneWidget);
  });

  testWidgets('switching files without edits does not ask', (tester) async {
    await _pumpTablet(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('aaa'), findsOneWidget);

    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.text('bbb'), findsOneWidget);
  });
}
