import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/rich_link_embed.dart';
import 'package:hermes_mobile/core/stores/embed_consent_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('detects the full mobile provider parity set narrowly', () {
    final cases = <String, RichLinkKind>{
      'https://youtube.com/watch?v=dQw4w9WgXcQ': RichLinkKind.youtube,
      'https://vimeo.com/1234': RichLinkKind.vimeo,
      'https://open.spotify.com/track/abc': RichLinkKind.spotify,
      'https://maps.google.com/maps?q=Paris': RichLinkKind.maps,
      'https://x.com/hermes/status/123': RichLinkKind.twitter,
      'https://instagram.com/reel/abc': RichLinkKind.instagram,
      'https://fr.pinterest.com/pin/1234567890/': RichLinkKind.pinterest,
      'https://www.tiktok.com/@hermes/video/123': RichLinkKind.tiktok,
      'https://openstreetmap.org/#map=12/1/2': RichLinkKind.openStreetMap,
    };
    for (final entry in cases.entries) {
      expect(detectRichLink(entry.key)?.kind, entry.value, reason: entry.key);
    }
    expect(detectRichLink('https://example.com/status/123'), isNull);
    expect(detectRichLink('https://x.com/hermes'), isNull);
    expect(detectRichLink('javascript:alert(1)'), isNull);
  });

  test('builds desktop-compatible provider descriptors', () {
    expect(
      detectRichLink('https://youtu.be/dQw4w9WgXcQ?t=1m30s')!.embedUrl,
      contains('start=90'),
    );
    expect(detectRichLink('https://youtube.com/watch?v=short'), isNull);
    expect(
      detectRichLink('https://vimeo.com/channels/staff/76979871')!.embedUrl,
      'https://player.vimeo.com/video/76979871',
    );
    expect(
      detectRichLink(
        'https://open.spotify.com/intl-de/playlist/37i9dQZF1DXcBWIGoYBM5M',
      )!.embedUrl,
      'https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M',
    );
    expect(
      detectRichLink(
        'https://www.tiktok.com/@user/video/7212345678901234567',
      )!.embedUrl,
      'https://www.tiktok.com/player/v1/7212345678901234567',
    );
    final maps = detectRichLink(
      'https://www.google.com/maps/@40.7128,-74.0060,12z',
    )!;
    expect(maps.embedUrl, contains('output=embed'));
    expect(maps.embedUrl, contains('q=40.7128%2C-74.0060'));
    expect(maps.embedUrl, contains('z=12'));
  });

  Future<EmbedConsentStore> pump(WidgetTester tester) async {
    final store = EmbedConsentStore();
    await store.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RichLinkEmbed(
              info: const RichLinkInfo(
                RichLinkKind.youtube,
                'https://youtu.be/dQw4w9WgXcQ',
                youtubeId: 'dQw4w9WgXcQ',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return store;
  }

  testWidgets('ask mode creates no network image before consent', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.byKey(const ValueKey('rich-link-consent-youtube')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('load once reveals preview without persisting provider grant', (
    tester,
  ) async {
    final store = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rich-link-load-once')));
    await tester.pump();
    expect(find.byKey(const ValueKey('rich-link-youtube')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(store.allowedProviders, isEmpty);
  });

  testWidgets('off mode renders a plain link and no network image', (
    tester,
  ) async {
    final store = await pump(tester);
    await store.setMode(EmbedMode.off);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('rich-link-disabled-youtube')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });
}
