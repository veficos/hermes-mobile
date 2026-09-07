import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_licenses.dart';
import 'core/connectivity_service.dart';
import 'core/notifications_service.dart';
import 'core/performance_metrics.dart';
import 'core/remote_push.dart';
import 'core/app_navigation.dart';
import 'core/deep_link_service.dart';
import 'core/incoming_share.dart';
import 'core/stores/appearance_store.dart';
import 'core/stores/embed_consent_store.dart';
import 'core/stores/embed_runtime_store.dart';
import 'core/stores/active_session_tray_store.dart';
import 'core/stores/chat_store.dart';
import 'core/stores/command_palette_store.dart';
import 'core/stores/command_store.dart';
import 'core/stores/composer_status_store.dart';
import 'core/stores/composer_suggestion_store.dart';
import 'core/stores/mcp_health_store.dart';
import 'core/stores/keybind_store.dart';
import 'core/stores/skin_sync_store.dart';
import 'core/stores/coding_status_store.dart';
import 'core/stores/connection_store.dart';
import 'core/stores/locale_store.dart';
import 'core/stores/mobile_surface_store.dart';
import 'core/stores/notification_store.dart';
import 'core/stores/pane_workspace_store.dart';
import 'core/stores/composer_handoff_store.dart';
import 'core/stores/pet_store.dart';
import 'core/stores/plugin_contribution_store.dart';
import 'core/stores/preview_store.dart';
import 'core/stores/profile_scope_store.dart';
import 'core/stores/pull_request_store.dart';
import 'core/stores/bot_store.dart';
import 'core/stores/billing_store.dart';
import 'core/stores/request_store.dart';
import 'core/stores/session_appearance_store.dart';
import 'core/stores/session_store.dart';
import 'core/stores/session_view_state_store.dart';
import 'core/stores/session_tab_store.dart';
import 'core/session_surface.dart';
import 'core/stores/subagent_store.dart';
import 'core/stores/terminal_store.dart';
import 'core/stores/update_store.dart';
import 'core/stores/voice_store.dart';
import 'core/stores/wake_word_store.dart';
import 'chat/tools/tool_dismiss_store.dart';
import 'kanban/api.dart';
import 'kanban/store.dart';
import 'l10n/l10n.dart';
import 'l10n/runtime_l10n.dart';
import 'screens/app_shell.dart';
import 'theme/hermes_theme.dart';
import 'widgets/mobile/mobile_tour_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ClientFrameMetricsBinding.start();
  registerAppLicenses();
  runApp(const HermesMobileApp());
}

class HermesMobileApp extends StatelessWidget {
  const HermesMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionStore()..load()),
        ChangeNotifierProxyProvider<ConnectionStore, ChatStore>(
          create: (ctx) =>
              ChatStore()
                ..attachRoutedEvents(ctx.read<ConnectionStore>().routedEvents),
          update: (ctx, connection, chat) => chat ?? ChatStore(),
        ),
        ChangeNotifierProxyProvider<ConnectionStore, RequestStore>(
          create: (ctx) =>
              RequestStore()
                ..attachRoutedEvents(ctx.read<ConnectionStore>().routedEvents),
          update: (ctx, connection, requests) => requests ?? RequestStore(),
        ),
        ChangeNotifierProxyProvider<ConnectionStore, NotificationStore>(
          create: (ctx) =>
              NotificationStore(connection: ctx.read<ConnectionStore>()),
          update: (ctx, connection, store) =>
              store ?? NotificationStore(connection: connection),
        ),
        ChangeNotifierProxyProvider<ConnectionStore, ComposerStatusStore>(
          create: (ctx) =>
              ComposerStatusStore()
                ..attachRoutedEvents(ctx.read<ConnectionStore>().routedEvents),
          update: (_, connection, store) =>
              store ??
              (ComposerStatusStore()
                ..attachRoutedEvents(connection.routedEvents)),
        ),
        ChangeNotifierProvider(create: (_) => PaneWorkspaceStore()..load()),
        ChangeNotifierProvider(create: (_) => ComposerHandoffStore()),
        ChangeNotifierProxyProvider<ConnectionStore, BillingStore>(
          create: (ctx) => BillingStore()
            ..attachConnection(ctx.read<ConnectionStore>())
            ..bindApi(ctx.read<ConnectionStore>().api),
          update: (_, connection, store) => (store ?? BillingStore())
            ..attachConnection(connection)
            ..bindApi(connection.api),
        ),
        ChangeNotifierProxyProvider<ConnectionStore, CodingStatusStore>(
          create: (ctx) => CodingStatusStore()
            ..startAutoRefresh()
            ..bindApi(ctx.read<ConnectionStore>().api),
          update: (_, connection, store) => (store ?? CodingStatusStore())
            ..startAutoRefresh()
            ..bindApi(connection.api),
        ),
        ChangeNotifierProvider(create: (_) => ToolDismissStore()),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          NotificationStore,
          KanbanStore
        >(
          create: (ctx) => KanbanStore(
            ctx.read<ConnectionStore>().api == null
                ? null
                : KanbanApi(ctx.read<ConnectionStore>().api!),
          ),
          update: (ctx, connection, notifications, store) {
            final result = store ?? KanbanStore();
            final client = connection.api;
            result.bindApi(client == null ? null : KanbanApi(client));
            result.onEvent = (board, event) {
              final kind = event['kind']?.toString() ?? '';
              if (!const {
                'completed',
                'blocked',
                'block_loop_detected',
                'gave_up',
                'crashed',
                'timed_out',
              }.contains(kind)) {
                return;
              }
              final payload = event['payload'] is Map
                  ? (event['payload'] as Map).cast<String, dynamic>()
                  : const <String, dynamic>{};
              final connectionId = connection.activeConnectionId.value;
              notifications.addExternal(
                key: 'kanban:$connectionId:$board:${event['id'] ?? kind}',
                kind: kind == 'completed'
                    ? NotificationKind.success
                    : NotificationKind.error,
                title: kind == 'completed'
                    ? runtimeL10n.kanbanTaskCompletedNotification
                    : runtimeL10n.kanbanTaskProblemNotification,
                message:
                    payload['title']?.toString() ??
                    payload['task_id']?.toString() ??
                    kind,
                connectionId: connectionId,
                profile: payload['profile']?.toString(),
              );
            };
            return result;
          },
        ),
        ChangeNotifierProxyProvider4<
          ConnectionStore,
          ChatStore,
          RequestStore,
          ComposerStatusStore,
          SessionStore
        >(
          create: (ctx) {
            final composer = ctx.read<ComposerStatusStore>();
            final session = SessionStore(
              connection: ctx.read<ConnectionStore>(),
              chat: ctx.read<ChatStore>(),
              requests: ctx.read<RequestStore>(),
              composerStatus: composer,
            );
            composer.bindRpc(session);
            return session;
          },
          update: (ctx, c, ch, r, composer, session) {
            final store =
                session ??
                SessionStore(
                  connection: c,
                  chat: ch,
                  requests: r,
                  composerStatus: composer,
                );
            composer.bindRpc(store);
            return store;
          },
        ),
        ChangeNotifierProxyProvider3<
          ConnectionStore,
          SessionStore,
          PaneWorkspaceStore,
          MobileSurfaceStore
        >(
          lazy: false,
          create: (ctx) => MobileSurfaceStore(
            ctx.read<ConnectionStore>(),
            ctx.read<SessionStore>(),
            ctx.read<PaneWorkspaceStore>(),
          ),
          update: (_, connection, session, panes, store) =>
              (store ?? MobileSurfaceStore(connection, session, panes))
                ..bindStores(
                  connection: connection,
                  session: session,
                  panes: panes,
                ),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          SessionStore,
          ProfileScopeStore
        >(
          create: (ctx) => ProfileScopeStore()
            ..bindApi(ctx.read<ConnectionStore>().api)
            ..bindBackendSnapshotSink(
              ctx.read<SessionStore>().syncProfilesFromBackend,
            )
            ..startAutoRefresh()
            ..syncFromSession(
              ctx.read<SessionStore>().profiles,
              ctx.read<SessionStore>().activeProfile,
            ),
          update: (_, connection, session, store) =>
              (store ?? ProfileScopeStore())
                ..bindApi(connection.api)
                ..bindBackendSnapshotSink(session.syncProfilesFromBackend)
                ..startAutoRefresh()
                ..syncFromSession(session.profiles, session.activeProfile),
        ),
        ChangeNotifierProxyProvider2<
          SessionStore,
          RequestStore,
          ActiveSessionTrayStore
        >(
          create: (ctx) => ActiveSessionTrayStore(
            ctx.read<SessionStore>(),
            ctx.read<RequestStore>(),
          ),
          update: (_, sessions, requests, store) =>
              (store ?? ActiveSessionTrayStore(sessions, requests))
                ..bind(sessions, requests),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          SessionStore,
          PullRequestStore
        >(
          create: (ctx) {
            final connection = ctx.read<ConnectionStore>();
            final session = ctx.read<SessionStore>();
            return PullRequestStore(
              api: connection.api,
              connectionId: connection.activeConnectionId.value,
              profile: session.sessionListProfile ?? session.activeProfile,
            );
          },
          update: (_, connection, session, store) {
            final result = store ?? PullRequestStore();
            result.bind(
              api: connection.api,
              connectionId: connection.activeConnectionId.value,
              profile: session.sessionListProfile ?? session.activeProfile,
            );
            return result;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionStore, VoiceStore>(
          create: (ctx) => VoiceStore(connection: ctx.read<ConnectionStore>()),
          update: (ctx, connection, voice) =>
              voice ?? VoiceStore(connection: connection),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          VoiceStore,
          WakeWordStore
        >(
          create: (ctx) {
            final wake = WakeWordStore(connection: ctx.read<ConnectionStore>());
            ctx.read<VoiceStore>().bindWakeWord(wake);
            return wake;
          },
          update: (ctx, connection, voice, wake) {
            final result = wake ?? WakeWordStore(connection: connection);
            voice.bindWakeWord(result);
            return result;
          },
        ),
        ChangeNotifierProxyProvider3<
          ConnectionStore,
          SessionStore,
          RequestStore,
          TerminalStore
        >(
          create: (ctx) => TerminalStore(
            connection: ctx.read<ConnectionStore>(),
            sessionStore: ctx.read<SessionStore>(),
            requestStore: ctx.read<RequestStore>(),
          ),
          lazy: false,
          update: (ctx, connection, session, requests, terminal) {
            final store =
                terminal ??
                TerminalStore(
                  connection: connection,
                  sessionStore: session,
                  requestStore: requests,
                );
            store.bindStores(
              connection: connection,
              sessionStore: session,
              requestStore: requests,
            );
            return store;
          },
        ),
        ChangeNotifierProxyProvider<ConnectionStore, SubagentStore>(
          create: (ctx) =>
              SubagentStore(connection: ctx.read<ConnectionStore>()),
          update: (ctx, connection, subagents) =>
              subagents ?? SubagentStore(connection: connection),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          SessionStore,
          CommandStore
        >(
          create: (ctx) =>
              CommandStore(connection: ctx.read<ConnectionStore>())
                ..bindProfile(
                  ctx.read<SessionStore>().sessionListProfile ??
                      ctx.read<SessionStore>().activeProfile,
                ),
          update: (ctx, connection, session, cmd) =>
              (cmd ?? CommandStore(connection: connection))..bindProfile(
                session.sessionListProfile ?? session.activeProfile,
              ),
        ),
        ChangeNotifierProxyProvider3<
          ConnectionStore,
          SessionStore,
          CommandStore,
          ComposerSuggestionStore
        >(
          lazy: false,
          create: (ctx) => ComposerSuggestionStore(
            ctx.read<ConnectionStore>(),
            ctx.read<SessionStore>(),
            ctx.read<CommandStore>(),
          ),
          update: (_, connection, session, commands, store) =>
              (store ?? ComposerSuggestionStore(connection, session, commands))
                ..bind(connection, session, commands),
        ),
        ChangeNotifierProxyProvider3<
          ConnectionStore,
          ProfileScopeStore,
          NotificationStore,
          McpHealthStore
        >(
          lazy: false,
          create: (ctx) => McpHealthStore(
            ctx.read<ConnectionStore>(),
            ctx.read<ProfileScopeStore>(),
            ctx.read<NotificationStore>(),
          ),
          update: (_, connection, scope, notifications, store) =>
              (store ?? McpHealthStore(connection, scope, notifications))
                ..bind(connection, scope, notifications),
        ),
        ChangeNotifierProxyProvider<ConnectionStore, PetStore>(
          create: (ctx) => PetStore(connection: ctx.read<ConnectionStore>()),
          update: (ctx, connection, pet) =>
              pet ?? PetStore(connection: connection),
        ),
        ChangeNotifierProxyProvider2<
          SessionStore,
          CommandStore,
          CommandPaletteStore
        >(
          create: (ctx) => CommandPaletteStore(
            session: ctx.read<SessionStore>(),
            commands: ctx.read<CommandStore>(),
          ),
          update: (ctx, session, commands, palette) =>
              palette ??
              CommandPaletteStore(session: session, commands: commands),
        ),
        Provider<NotificationsService>(
          lazy: false,
          create: (ctx) =>
              NotificationsService(store: ctx.read<NotificationStore>()),
          dispose: (_, svc) => svc.dispose(),
        ),
        Provider<DeepLinkService>(
          lazy: false,
          create: (_) => DeepLinkService(),
        ),
        ChangeNotifierProvider<IncomingShareService>(
          lazy: false,
          create: (_) => IncomingShareService(),
        ),
        Provider<ConnectivityService>(
          lazy: false,
          create: (_) => ConnectivityService()..start(),
          dispose: (_, svc) => unawaited(svc.dispose()),
        ),
        ChangeNotifierProvider(create: (_) => AppearanceStore()..load()),
        ChangeNotifierProvider(create: (_) => SessionViewStateStore()),
        ChangeNotifierProxyProvider<ConnectionStore, SessionTabStore>(
          lazy: false,
          create: (ctx) => SessionTabStore()
            ..attachRoutedEvents(
              ctx.read<ConnectionStore>().routedEvents,
              owners: ctx.read<ConnectionStore>().sessionOwners,
            )
            ..restore(),
          update: (ctx, connection, tabs) {
            final store = tabs ?? SessionTabStore();
            store.attachRoutedEvents(
              connection.routedEvents,
              owners: connection.sessionOwners,
            );
            return store;
          },
        ),
        ChangeNotifierProvider(create: (_) => SessionSurfaceStore()),
        ChangeNotifierProvider(create: (_) => EmbedConsentStore()..load()),
        ChangeNotifierProvider(create: (_) => EmbedRuntimeStore()),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          AppearanceStore,
          SkinSyncStore
        >(
          lazy: false,
          create: (ctx) => SkinSyncStore(
            connection: ctx.read<ConnectionStore>(),
            appearance: ctx.read<AppearanceStore>(),
          ),
          update: (ctx, connection, appearance, store) =>
              (store ??
                    SkinSyncStore(
                      connection: connection,
                      appearance: appearance,
                    ))
                ..bind(appearance),
        ),
        ChangeNotifierProvider(create: (_) => LocaleStore()..load()),
        ChangeNotifierProvider(create: (_) => KeybindStore()..load()),
        ChangeNotifierProvider<RemotePushService>(
          lazy: false,
          create: (ctx) {
            final service = RemotePushService(
              connection: ctx.read<ConnectionStore>(),
              session: ctx.read<SessionStore>(),
              locale: ctx.read<LocaleStore>(),
              notifications: ctx.read<NotificationsService>(),
            );
            unawaited(service.start());
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => UpdateStore()..initialize()),
        ChangeNotifierProvider(create: (_) => SessionAppearanceStore()..load()),
        ChangeNotifierProxyProvider<ConnectionStore, BotStore>(
          create: (ctx) =>
              BotStore(ctx.read<ConnectionStore>())..startRosterRefresh(),
          update: (ctx, connection, previous) =>
              (previous ?? BotStore(connection))..startRosterRefresh(),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          NotificationStore,
          PluginContributionStore
        >(
          create: (ctx) => PluginContributionStore(
            ctx.read<ConnectionStore>(),
            notifications: ctx.read<NotificationStore>(),
          ),
          update: (ctx, connection, notifications, previous) =>
              previous ??
              PluginContributionStore(connection, notifications: notifications),
        ),
        ChangeNotifierProxyProvider2<
          ConnectionStore,
          SessionStore,
          PreviewStore
        >(
          create: (ctx) =>
              PreviewStore(ctx.read<ConnectionStore>())..bindVisibleSession(
                owner: () => ctx.read<SessionStore>().owner?.route,
                runtimeId: () => ctx.read<SessionStore>().runtimeId,
                durableId: () => ctx.read<SessionStore>().durableId,
              ),
          update: (ctx, connection, session, previous) =>
              (previous ?? PreviewStore(connection))..bindVisibleSession(
                owner: () => session.owner?.route,
                runtimeId: () => session.runtimeId,
                durableId: () => session.durableId,
              ),
        ),
      ],
      child: Consumer2<AppearanceStore, LocaleStore>(
        builder: (context, appearance, locale, _) {
          final accent = appearance.accent;
          final highContrast = appearance.highContrast;
          // Dynamic Type (spec §162): respect system text scale, clamped to a
          // sensible max so layouts don't break at huge accessibility sizes.
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.6,
            child: MaterialApp(
              navigatorKey: hermesNavigatorKey,
              onGenerateTitle: (context) => context.l10n.appTitle,
              debugShowCheckedModeBanner: false,
              locale: locale.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHermesTheme(
                brightness: Brightness.light,
                accent: accent,
                highContrast: highContrast,
              ),
              darkTheme: buildHermesTheme(
                brightness: Brightness.dark,
                accent: accent,
                highContrast: highContrast,
              ),
              themeMode: appearance.themeMode,
              builder: (context, child) {
                RuntimeL10n.use(context.l10n);
                return MobileTourOverlay(child: child!);
              },
              home: const AppShell(),
            ),
          );
        },
      ),
    );
  }
}
