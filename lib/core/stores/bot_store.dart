library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/runtime_l10n.dart';

import '../connections/connection_registry.dart';
import '../gateway.dart';
import 'request_store.dart';
import 'connection_store.dart';

const canonicalBotChatTitle = 'Bot Chat';
const _groupChatMaxRounds = 3;
const _groupChatMaxMessages = 10;
const _groupChatHistoryLimit = 24;
const _groupChatRetainedMessages = _groupChatHistoryLimit * 4;
const _groupTurnTimeout = Duration(minutes: 3);
const _groupTurnHardCap = Duration(minutes: 20);
const _groupTurnPollInterval = Duration(seconds: 2);
const _groupProjectionMaxBytes = 48000;
const _legacyDelegatedRoutinePrefix = 'You are running the scheduled routine "';

class BotIdentity {
  final OwnerRoute route;
  final String profile;
  final String displayName;
  final String description;
  final Map<String, dynamic> metadata;

  const BotIdentity({
    required this.route,
    required this.profile,
    required this.displayName,
    this.description = '',
    this.metadata = const {},
  });

  String get key => '${route.connectionId.value}\u0000$profile';
}

class BotGroup {
  final String id;
  final String roomId;
  final String name;
  final List<String> memberKeys;
  final DateTime updatedAt;
  final int revision;

  const BotGroup({
    required this.id,
    String? roomId,
    required this.name,
    required this.memberKeys,
    required this.updatedAt,
    this.revision = 0,
  }) : roomId = roomId ?? id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_id': roomId,
    'name': name,
    'members': memberKeys,
    'updated_at': updatedAt.toIso8601String(),
    'revision': revision,
  };

  factory BotGroup.fromJson(Map<String, dynamic> json) => BotGroup(
    id: json['id']?.toString() ?? '',
    roomId: json['room_id']?.toString(),
    name: json['name']?.toString() ?? '',
    memberKeys: (json['members'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
  );
}

class BotRoomMessage {
  final String id, groupId, author, text, threadId;
  final DateTime at;
  final bool pending;
  const BotRoomMessage({
    required this.id,
    required this.groupId,
    required this.author,
    required this.text,
    required this.at,
    this.threadId = 'legacy',
    this.pending = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'author': author,
    'text': text,
    'at': at.toIso8601String(),
    'thread': threadId,
  };
  factory BotRoomMessage.fromJson(Map<String, dynamic> json) => BotRoomMessage(
    id: '${json['id'] ?? ''}',
    groupId: '${json['group_id'] ?? ''}',
    author: '${json['author'] ?? ''}',
    text: '${json['text'] ?? ''}',
    at: DateTime.tryParse('${json['at'] ?? ''}') ?? DateTime.now(),
    threadId: '${json['thread'] ?? 'legacy'}',
  );
}

class BotGroupPendingRequest {
  final String groupId;
  final String memberKey;
  final String memberName;
  final OwnerRoute route;
  final PendingRequest request;

  const BotGroupPendingRequest({
    required this.groupId,
    required this.memberKey,
    required this.memberName,
    required this.route,
    required this.request,
  });

  String get key => '$groupId\u0000$memberKey';
}

class _BotStrandedTurn {
  final int before;
  final String threadId;

  const _BotStrandedTurn({required this.before, required this.threadId});

  Map<String, dynamic> toJson() => {'before': before, 'thread': threadId};

  factory _BotStrandedTurn.fromJson(Map<String, dynamic> json) =>
      _BotStrandedTurn(
        before: (json['before'] as num?)?.toInt() ?? 0,
        threadId: '${json['thread'] ?? 'legacy'}',
      );
}

class _BotMemberHold {
  final int at;
  final String messageId;
  final String threadId;
  final bool noted;

  const _BotMemberHold({
    required this.at,
    required this.messageId,
    required this.threadId,
    this.noted = false,
  });

  _BotMemberHold copyWith({bool? noted}) => _BotMemberHold(
    at: at,
    messageId: messageId,
    threadId: threadId,
    noted: noted ?? this.noted,
  );

  Map<String, dynamic> toJson() => {
    'at': at,
    'message_id': messageId,
    'thread': threadId,
    'noted': noted,
  };

  factory _BotMemberHold.fromJson(Map<String, dynamic> json) => _BotMemberHold(
    at: (json['at'] as num?)?.toInt() ?? 0,
    messageId: '${json['message_id'] ?? ''}',
    threadId: '${json['thread'] ?? 'legacy'}',
    noted: json['noted'] == true,
  );
}

class _BotRoomState {
  int epoch = 0;
  final Map<String, int> watermarks = {};
  final Map<String, String> sessions = {};
  final Map<String, _BotStrandedTurn> stranded = {};
  final Map<String, _BotMemberHold> holds = {};
  bool running = false;
  String? speaker;
  String? activeThread;

  _BotRoomState();

  Map<String, dynamic> toJson() => {
    'epoch': epoch,
    'watermarks': watermarks,
    'sessions': sessions,
    'stranded': stranded.map((key, value) => MapEntry(key, value.toJson())),
    'holds': holds.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory _BotRoomState.fromJson(Map<String, dynamic> json) {
    final state = _BotRoomState()
      ..epoch = (json['epoch'] as num?)?.toInt() ?? 0;
    final watermarks = json['watermarks'];
    if (watermarks is Map) {
      state.watermarks.addAll(
        watermarks.map(
          (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0),
        ),
      );
    }
    final sessions = json['sessions'];
    if (sessions is Map) {
      state.sessions.addAll(
        sessions.map((key, value) => MapEntry('$key', '$value')),
      );
    }
    final stranded = json['stranded'];
    if (stranded is Map) {
      for (final entry in stranded.entries) {
        if (entry.value is Map) {
          state.stranded['${entry.key}'] = _BotStrandedTurn.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
        }
      }
    }
    final holds = json['holds'];
    if (holds is Map) {
      for (final entry in holds.entries) {
        if (entry.value is Map) {
          state.holds['${entry.key}'] = _BotMemberHold.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
        }
      }
    }
    return state;
  }
}

class BotGroupAttachment {
  final String name;
  final String dataUrl;
  final bool image;

  const BotGroupAttachment({
    required this.name,
    required this.dataUrl,
    this.image = false,
  });
}

class BotRoutine {
  final String id;
  final String name;
  final String title;
  final String schedule;
  final String promptPreview;
  final bool enabled;
  final String state;
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastStatus;
  final String? deliver;
  final String? model;
  final String? workdir;
  final String? repeat;
  final String? issue;
  final bool legacyUnsafe;

  const BotRoutine({
    required this.id,
    required this.name,
    required this.title,
    required this.schedule,
    required this.promptPreview,
    required this.enabled,
    required this.state,
    this.nextRunAt,
    this.lastRunAt,
    this.lastStatus,
    this.deliver,
    this.model,
    this.workdir,
    this.repeat,
    this.issue,
    this.legacyUnsafe = false,
  });

  bool get active => !legacyUnsafe && enabled && state != 'paused';

  factory BotRoutine.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final title = name.replaceFirst(
      RegExp(r'^\[bot:[a-z0-9][a-z0-9_-]*\]\s*', caseSensitive: false),
      '',
    );
    final preview = (json['prompt_preview'] ?? json['prompt'] ?? '').toString();
    final issues =
        [
              json['last_fire_error'],
              json['last_delivery_error'],
              json['paused_reason'],
              json['last_error'],
            ]
            .map((value) => value?.toString().trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty);
    return BotRoutine(
      id: (json['job_id'] ?? json['id'] ?? name).toString(),
      name: name,
      title: title.isEmpty ? runtimeL10n.botUntitledTask : title,
      schedule: (json['schedule'] ?? '').toString(),
      promptPreview: preview,
      enabled: json['enabled'] != false,
      state:
          (json['state'] ?? (json['enabled'] == false ? 'paused' : 'scheduled'))
              .toString(),
      nextRunAt: json['next_run_at']?.toString(),
      lastRunAt: json['last_run_at']?.toString(),
      lastStatus: json['last_status']?.toString(),
      deliver: json['deliver']?.toString(),
      model: json['model']?.toString(),
      workdir: json['workdir']?.toString(),
      repeat: json['repeat']?.toString(),
      issue: issues.firstOrNull,
      legacyUnsafe:
          RegExp(
            r'^\[bot:[a-z0-9][a-z0-9_-]*\]',
            caseSensitive: false,
          ).hasMatch(name) &&
          preview.startsWith(_legacyDelegatedRoutinePrefix),
    );
  }
}

class BotRoutineDraft {
  final String title;
  final String instruction;
  final String schedule;
  final int? repeat;
  final bool continuity;
  final bool deliverToBotChat;

  const BotRoutineDraft({
    required this.title,
    required this.instruction,
    required this.schedule,
    this.repeat,
    this.continuity = false,
    this.deliverToBotChat = false,
  });
}

/// Multi-connection Bot roster and canonical-chat registry.
class BotStore extends ChangeNotifier {
  static const _groupsKey = 'hermes_mobile_bot_groups_v1';
  static const _roomsKey = 'hermes_mobile_bot_rooms_v1';
  static const _roomStatesKey = 'hermes_mobile_bot_room_states_v1';
  static const _deletionsKey = 'hermes_mobile_bot_group_deletions_v1';
  static const _syncMetaKey = 'hermes-bots-groups';
  static const maxGroupMembers = 6;
  final ConnectionStore connection;
  final Map<String, Future<String?>> _canonicalFlights = {};
  final Map<
    String,
    ({
      String groupId,
      String author,
      String memberKey,
      OwnerRoute route,
      String turnId,
      String threadId,
    })
  >
  _roomSessions = {};
  final Map<String, StringBuffer> _roomBuffers = {};
  final Map<String, Completer<String?>> _roomReplyCompleters = {};
  final Map<String, _BotRoomState> _roomStates = {};
  final Map<String, Future<void>> _groupFlights = {};
  final Map<String, Map<String, List<String>>> _attachmentRefs = {};
  final Map<String, BotGroupPendingRequest> _groupRequests = {};
  final Map<String, Timer> _harvestTimers = {};
  final Set<String> _pendingGroups = {};
  final Map<String, int> _deletedRooms = {};
  StreamSubscription<RoutedGatewayEvent>? _events;
  Timer? _syncTimer;
  bool _disposed = false;
  int _refreshGeneration = 0;

  List<BotIdentity> bots = const [];
  List<BotGroup> groups = const [];
  List<BotRoomMessage> roomMessages = const [];
  bool loading = false;
  String? error;

  bool isGroupBusy(String groupId) => _pendingGroups.contains(groupId);
  String? groupSpeaker(String groupId) => _roomStates[groupId]?.speaker;
  bool isMemberHeld(String groupId, String memberKey) =>
      _roomStates[groupId]?.holds.containsKey(memberKey) == true;
  List<BotGroupPendingRequest> pendingRequestsFor(String groupId) =>
      _groupRequests.values
          .where((request) => request.groupId == groupId)
          .toList(growable: false);

  _BotRoomState _stateFor(String groupId) =>
      _roomStates.putIfAbsent(groupId, () => _BotRoomState());

  BotStore(this.connection) {
    unawaited(loadGroups());
    _events = connection.routedEvents.listen(_onRoomEvent);
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    loading = true;
    error = null;
    notifyListeners();
    final found = <BotIdentity>[];
    final failures = <String>[];
    final remoteSnapshots =
        <({Map<String, dynamic> value, ConnectionId source})>[];
    await Future.wait(
      connection.registry.runtimes.map((runtime) async {
        try {
          final result = await connection.requestForOwner(
            OwnerRoute(connectionId: runtime.id),
            'profiles.list',
            {'include_sessions': false},
          );
          for (final raw in result['profiles'] as List? ?? const []) {
            if (raw is! Map) continue;
            final row = raw.cast<String, dynamic>();
            final profile = row['name']?.toString() ?? '';
            if (profile.isEmpty) continue;
            final botMeta =
                ((row['ui_meta'] as Map?)?['hermes-bots'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            if (profile == 'default') {
              final snapshot = (row['ui_meta'] as Map?)?[_syncMetaKey];
              if (snapshot is Map) {
                remoteSnapshots.add((
                  value: snapshot.cast<String, dynamic>(),
                  source: runtime.id,
                ));
              }
            }
            found.add(
              BotIdentity(
                route: OwnerRoute(connectionId: runtime.id, profile: profile),
                profile: profile,
                displayName:
                    (botMeta['title'] ?? row['display_name'] ?? profile)
                        .toString(),
                description: row['description']?.toString() ?? '',
                metadata: botMeta,
              ),
            );
          }
        } catch (e) {
          failures.add('${runtime.id}: $e');
        }
      }),
    );
    if (generation != _refreshGeneration) return;
    found.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    bots = List.unmodifiable(found);
    for (final snapshot in remoteSnapshots) {
      _mergeRemoteSnapshot(snapshot.value, snapshot.source);
    }
    error = failures.isEmpty ? null : failures.join('\n');
    loading = false;
    notifyListeners();
  }

  /// Resolves exactly one hidden `Bot Chat`. Lookup errors fail closed.
  Future<String?> ensureCanonicalChat(BotIdentity bot) {
    return _canonicalFlights.putIfAbsent(bot.key, () async {
      try {
        final params = <String, dynamic>{
          'profile': bot.profile,
          'title': canonicalBotChatTitle,
          'limit': 200,
          'include_hidden': true,
        };
        final listed = await connection.requestForOwner(
          bot.route,
          'session.list',
          params,
        );
        for (final raw in listed['sessions'] as List? ?? const []) {
          if (raw is! Map) continue;
          final row = raw.cast<String, dynamic>();
          final rootTitle = row['root_title']?.toString().trim() ?? '';
          final title = row['title']?.toString().trim() ?? '';
          if (rootTitle == canonicalBotChatTitle ||
              (rootTitle.isEmpty && title == canonicalBotChatTitle)) {
            final durable = row['id']?.toString();
            final resolved = row['resolved_id']?.toString();
            if (durable != null && durable.isNotEmpty) {
              connection.sessionOwners.remember(
                SessionOwner(
                  durableId: durable,
                  lineageRootId: durable,
                  route: bot.route,
                ),
              );
            }
            return resolved?.isNotEmpty == true ? resolved : durable;
          }
        }
        final created = await connection
            .requestForOwner(bot.route, 'session.create', {
              'profile': bot.profile,
              'title': canonicalBotChatTitle,
              'hidden': true,
              'source': 'mobile-bots',
              'cols': 48,
            });
        final durable = created['stored_session_id']?.toString();
        final runtime = created['session_id']?.toString();
        if (runtime?.isNotEmpty == true) {
          try {
            await connection.requestForOwner(bot.route, 'session.title', {
              'session_id': runtime,
              'title': canonicalBotChatTitle,
            });
          } catch (_) {}
        }
        if (durable?.isNotEmpty == true) {
          connection.sessionOwners.remember(
            SessionOwner(
              durableId: durable!,
              runtimeId: runtime,
              route: bot.route,
            ),
          );
        }
        return durable;
      } finally {
        _canonicalFlights.remove(bot.key);
      }
    });
  }

  Future<void> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupsKey);
    if (raw != null) {
      try {
        groups = List.unmodifiable(
          (jsonDecode(raw) as List).map(
            (e) => BotGroup.fromJson((e as Map).cast<String, dynamic>()),
          ),
        );
      } catch (_) {}
    }
    final roomRaw = prefs.getString(_roomsKey);
    if (roomRaw != null) {
      try {
        roomMessages = List.unmodifiable(
          (jsonDecode(roomRaw) as List).map(
            (e) => BotRoomMessage.fromJson((e as Map).cast<String, dynamic>()),
          ),
        );
      } catch (_) {}
    }
    final stateRaw = prefs.getString(_roomStatesKey);
    if (stateRaw != null) {
      try {
        final decoded = jsonDecode(stateRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              _roomStates['${entry.key}'] = _BotRoomState.fromJson(
                (entry.value as Map).cast<String, dynamic>(),
              );
            }
          }
        }
      } catch (_) {}
    }
    final deletionRaw = prefs.getString(_deletionsKey);
    if (deletionRaw != null) {
      try {
        _deletedRooms.addAll(
          (jsonDecode(deletionRaw) as Map).map(
            (key, value) => MapEntry('$key', (value as num).toInt()),
          ),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<BotGroup> createGroup(
    String name,
    Iterable<BotIdentity> members,
  ) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('group name is empty');
    final keys = members.map((e) => e.key).toSet().toList();
    if (keys.length < 2) throw ArgumentError('a group needs at least two bots');
    if (keys.length > maxGroupMembers) {
      throw ArgumentError('a group supports at most $maxGroupMembers bots');
    }
    final roomId =
        'r${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final group = BotGroup(
      id: roomId,
      roomId: roomId,
      name: clean,
      memberKeys: keys,
      updatedAt: DateTime.now(),
    );
    groups = List.unmodifiable([
      ...groups.where((g) => g.name != clean),
      group,
    ]);
    await _saveGroups();
    _scheduleServerSync();
    notifyListeners();
    return group;
  }

  Future<void> removeGroup(String id) async {
    final removed = groups.where((group) => group.id == id).firstOrNull;
    groups = List.unmodifiable(groups.where((g) => g.id != id));
    roomMessages = List.unmodifiable(
      roomMessages.where((message) => message.groupId != id),
    );
    if (removed != null) {
      _deletedRooms['id:${removed.roomId}'] =
          DateTime.now().millisecondsSinceEpoch;
    }
    _roomStates.remove(id);
    _groupRequests.removeWhere((_, request) => request.groupId == id);
    _harvestTimers.remove(id)?.cancel();
    final messageIds = _attachmentRefs.keys
        .where(
          (messageId) =>
              !roomMessages.any((message) => message.id == messageId),
        )
        .toList();
    for (final messageId in messageIds) {
      _attachmentRefs.remove(messageId);
    }
    await _saveGroups();
    await _saveRooms();
    await _saveRoomStates();
    _scheduleServerSync(allowEmpty: true);
    notifyListeners();
  }

  Future<void> updateGroup(
    BotGroup group, {
    required String name,
    required Iterable<BotIdentity> members,
  }) async {
    final clean = name.trim();
    final keys = members.map((member) => member.key).toSet().toList();
    if (clean.isEmpty) throw ArgumentError('group name is empty');
    if (keys.length < 2 || keys.length > maxGroupMembers) {
      throw ArgumentError('a group needs 2-$maxGroupMembers bots');
    }
    final updated = BotGroup(
      id: group.id,
      roomId: group.roomId,
      name: clean,
      memberKeys: keys,
      updatedAt: DateTime.now(),
      revision: group.revision + 1,
    );
    groups = List.unmodifiable([
      for (final item in groups) item.id == group.id ? updated : item,
    ]);
    await _saveGroups();
    _scheduleServerSync();
    notifyListeners();
  }

  /// Appends one user message and starts a bounded, serial round-robin drive.
  /// A second send supersedes the current drive at its next member boundary
  /// and is serialized behind it, so two loops never own the same room.
  Future<void> sendGroupPrompt(
    BotGroup group,
    String text, {
    List<BotGroupAttachment> attachments = const [],
    String? threadId,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty && attachments.isEmpty) return;
    final members = _membersForGroup(group);
    if (members.isEmpty) throw StateError('no available group member');
    final turnId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final targetThread = threadId?.trim().isNotEmpty == true
        ? threadId!.trim()
        : 't$turnId';
    final uploaded = await _uploadGroupAttachments(
      members,
      attachments,
      turnId,
    );
    final attachmentLabel = attachments.isEmpty
        ? ''
        : '\n📎 ${attachments.map((item) => item.name).join(', ')}';
    final message = BotRoomMessage(
      id: 'user-$turnId',
      groupId: group.id,
      author: 'You',
      text: '$clean$attachmentLabel'.trim(),
      at: DateTime.now(),
      threadId: targetThread,
    );
    _attachmentRefs[message.id] = uploaded;
    _appendRoom(message);
    final state = _stateFor(group.id);
    state.epoch += 1;
    state.running = true;
    state.activeThread = targetThread;
    _applyHoldDirective(state, members, clean, message);
    _pendingGroups.add(group.id);
    unawaited(_saveRoomStates());
    notifyListeners();

    final epoch = state.epoch;
    final previous = _groupFlights[group.id];
    final started = Completer<void>();
    late final Future<void> flight;
    flight = (previous ?? Future<void>.value())
        .catchError((_) {})
        .then(
          (_) => _runGroupRounds(group, members, targetThread, epoch, started),
        );
    _groupFlights[group.id] = flight;
    unawaited(
      flight.whenComplete(() {
        if (identical(_groupFlights[group.id], flight)) {
          _groupFlights.remove(group.id);
        }
      }),
    );
    // A superseding send is already durably queued; do not wait for the old
    // member turn to reach its boundary. A fresh room waits until the first
    // prompt is accepted so immediate transport failures remain visible.
    if (previous == null) await started.future;
  }

  Future<Map<String, List<String>>> _uploadGroupAttachments(
    List<BotIdentity> responders,
    List<BotGroupAttachment> attachments,
    String turnId,
  ) async {
    if (attachments.isEmpty) return const {};
    final routes = <String, OwnerRoute>{
      for (final bot in responders) bot.route.connectionId.value: bot.route,
    };
    final uploaded = <String, List<String>>{};
    for (final entry in routes.entries) {
      final api = connection.runtimeFor(entry.value).api;
      final refs = <String>[];
      for (var index = 0; index < attachments.length; index++) {
        final attachment = attachments[index];
        final safeName = attachment.name.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
        final result = await api.uploadFile(
          '/hm-attachments/group_${turnId}_${index}_$safeName',
          attachment.dataUrl,
        );
        final path = result['path']?.toString() ?? '';
        if (path.isNotEmpty) {
          refs.add(attachment.image ? '@image:$path' : path);
        }
      }
      uploaded[entry.key] = refs;
    }
    return uploaded;
  }

  String _groupPromptWithAttachments(String text, List<String> refs) {
    if (refs.isEmpty) return text;
    final images = refs.where((ref) => ref.startsWith('@image:')).toList();
    final files = refs.where((ref) => !ref.startsWith('@image:')).toList();
    return [
      text,
      if (images.isNotEmpty) images.join(' '),
      if (files.isNotEmpty) '[Attached files: ${files.join(', ')}]',
    ].where((part) => part.trim().isNotEmpty).join('\n\n');
  }

  List<BotIdentity> _membersForGroup(BotGroup group) => group.memberKeys
      .map((key) => bots.where((bot) => bot.key == key).firstOrNull)
      .whereType<BotIdentity>()
      .toList();

  ({Set<String> members, bool everyone}) _parseMentions(
    String text,
    List<BotIdentity> members,
  ) {
    final mentioned = <String>{};
    var everyone = false;
    String collapsed(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[\s._-]+'), '');
    final handles = <String, String>{};
    for (final bot in members) {
      for (final form in {
        bot.profile.toLowerCase(),
        collapsed(bot.profile),
        bot.displayName.toLowerCase(),
        collapsed(bot.displayName),
        bot.displayName.toLowerCase().split(RegExp(r'\s+')).first,
      }) {
        if (form.isNotEmpty) handles[form] = bot.key;
      }
    }
    final pattern = RegExp(r'@(?:"([^"]+)"|([A-Za-z0-9._-]+))');
    for (final match in pattern.allMatches(text)) {
      final value = (match.group(1) ?? match.group(2) ?? '').toLowerCase();
      if (value == 'all' || value == 'everyone') {
        everyone = true;
        continue;
      }
      if (value == 'user') continue;
      final key = handles[value] ?? handles[collapsed(value)];
      if (key != null) mentioned.add(key);
    }
    return (members: mentioned, everyone: everyone);
  }

  List<BotIdentity> _resolveResponders(
    List<BotRoomMessage> log,
    List<BotIdentity> members,
  ) {
    var start = 0;
    for (var index = log.length - 1; index >= 0; index--) {
      if (log[index].author == 'You') {
        start = index;
        break;
      }
    }
    final mentioned = <String>{};
    var everyone = false;
    for (final message in log.skip(start)) {
      final parsed = _parseMentions(message.text, members);
      mentioned.addAll(parsed.members);
      everyone = everyone || parsed.everyone;
    }
    if (everyone || mentioned.isEmpty) return members;
    return members.where((member) => mentioned.contains(member.key)).toList();
  }

  List<BotIdentity> _rotateMembers(List<BotIdentity> members, int round) {
    if (members.length < 2) return members;
    final shift = round % members.length;
    return [...members.skip(shift), ...members.take(shift)];
  }

  void _applyHoldDirective(
    _BotRoomState state,
    List<BotIdentity> members,
    String text,
    BotRoomMessage message,
  ) {
    final mentions = _parseMentions(text, members);
    final stop = RegExp(
      r'\b(stop|halt|pause)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final resume = RegExp(
      r'\b(resume|continue|go|proceed)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final keys = mentions.everyone
        ? members.map((member) => member.key)
        : mentions.members;
    if (stop) {
      for (final key in keys) {
        state.holds[key] = _BotMemberHold(
          at: message.at.millisecondsSinceEpoch,
          messageId: message.id,
          threadId: message.threadId,
        );
      }
      return;
    }
    if (resume && mentions.everyone) {
      state.holds.clear();
      return;
    }
    // Addressing a held member directly is an explicit release, even without
    // the word "resume"; bot-authored messages never call this method.
    for (final key in keys) {
      state.holds.remove(key);
    }
  }

  bool _isGroupPass(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ||
        RegExp(r'^\(?\s*pass\s*\)?\.?$', caseSensitive: false).hasMatch(text);
  }

  String _formatGroupLine(BotRoomMessage message, BotIdentity viewer) {
    if (message.author == 'You') return 'You (user): ${message.text}';
    final suffix = message.author == viewer.displayName ? ' (you)' : '';
    return '${message.author}$suffix: ${message.text}';
  }

  String _buildGroupTurnPrompt(
    BotGroup group,
    List<BotIdentity> members,
    BotIdentity viewer,
    List<BotRoomMessage> delta,
  ) {
    final peers = members
        .where((member) => member.key != viewer.key)
        .map((member) => '@${member.displayName} (${member.profile})')
        .join(', ');
    final refs = <String>[];
    for (final message in delta) {
      refs.addAll(
        _attachmentRefs[message.id]?[viewer.route.connectionId.value] ??
            const [],
      );
    }
    return [
      '[Group chat: "${group.name}"] You are @${viewer.displayName} '
          '(${viewer.profile}), one participant in a group chat with '
          '${peers.isEmpty ? 'no one else yet' : peers} and the user.',
      '',
      'New messages in the room since your last turn (oldest first):',
      ...delta
          .takeLast(_groupChatHistoryLimit)
          .map((message) => '  ${_formatGroupLine(message, viewer)}'),
      if (refs.isNotEmpty) '',
      if (refs.isNotEmpty)
        _groupPromptWithAttachments('Attachments for the new messages:', refs),
      '',
      'Rules for this room:',
      '- Reply with one conversational message only when you have something '
          'new worth adding, work to claim or hand off, a requested answer, '
          'or a real result.',
      '- Reply exactly "(pass)" when you have nothing new to add. Passing is '
          'good and lets the conversation settle.',
      '- Mention a teammate as @name to pull them into the next round. Mention '
          '@user only for a judgment call or result the user needs.',
      '- Never reveal private 1:1 chat content. Your reply is copied to the '
          'room verbatim.',
    ].join('\n');
  }

  Future<void> _runGroupRounds(
    BotGroup group,
    List<BotIdentity> members,
    String threadId,
    int epoch,
    Completer<void> started,
  ) async {
    final state = _stateFor(group.id);
    var posted = 0;
    try {
      for (var round = 0; round < _groupChatMaxRounds; round++) {
        if (_disposed) return;
        for (final member in members) {
          if (state.epoch != epoch) return;
          await _harvestStrandedReply(group, member);
        }
        final threadLog = messagesFor(
          group.id,
        ).where((message) => message.threadId == threadId).toList();
        final responders = _rotateMembers(
          _resolveResponders(threadLog, members),
          round,
        ).where((member) => !state.stranded.containsKey(member.key));
        var spokeThisRound = 0;
        for (final member in responders) {
          if (_disposed ||
              state.epoch != epoch ||
              posted >= _groupChatMaxMessages) {
            return;
          }
          final roomLog = messagesFor(group.id);
          final markKey = '$threadId\u0000${member.key}';
          final seen = state.watermarks[markKey] ?? 0;
          final delta = roomLog
              .skip(seen.clamp(0, roomLog.length))
              .where((message) => message.threadId == threadId)
              .toList();
          if (delta.isEmpty) continue;
          final hold = state.holds[member.key];
          if (hold != null) {
            state.watermarks[markKey] = roomLog.length;
            if (!hold.noted) {
              state.holds[member.key] = hold.copyWith(noted: true);
              _appendRoom(
                BotRoomMessage(
                  id: 'held-${DateTime.now().microsecondsSinceEpoch}',
                  groupId: group.id,
                  author: 'System',
                  text: runtimeL10n.botMemberPaused(member.displayName),
                  at: DateTime.now(),
                  threadId: threadId,
                ),
              );
            }
            continue;
          }
          state.speaker = member.displayName;
          notifyListeners();
          final anchorId = roomLog.isEmpty ? null : roomLog.last.id;
          String? reply;
          try {
            reply = await _runGroupMemberTurn(
              group,
              members,
              member,
              threadId,
              epoch,
              _buildGroupTurnPrompt(group, members, member, delta),
              started,
            );
          } catch (error) {
            if (!started.isCompleted) started.completeError(error);
            _appendRoom(
              BotRoomMessage(
                id: 'error-${DateTime.now().microsecondsSinceEpoch}',
                groupId: group.id,
                author: 'System',
                text: '${member.displayName}: $error',
                at: DateTime.now(),
                threadId: threadId,
              ),
            );
            reply = null;
          }
          final now = messagesFor(group.id);
          final anchor = anchorId == null
              ? -1
              : now.indexWhere((message) => message.id == anchorId);
          final tail = anchor < 0 ? now : now.skip(anchor + 1);
          final newerUserInThread = tail.any(
            (message) =>
                message.author == 'You' && message.threadId == threadId,
          );
          if (state.epoch != epoch && newerUserInThread) return;
          state.watermarks[markKey] = now.length;
          if (!_isGroupPass(reply)) {
            _appendRoom(
              BotRoomMessage(
                id: '${member.key.hashCode}-${DateTime.now().microsecondsSinceEpoch}',
                groupId: group.id,
                author: member.displayName,
                text: reply!.trim(),
                at: DateTime.now(),
                threadId: threadId,
              ),
            );
            state.watermarks[markKey] = messagesFor(group.id).length;
            posted += 1;
            spokeThisRound += 1;
          }
        }
        if (spokeThisRound == 0) return;
      }
    } finally {
      if (!started.isCompleted) started.complete();
      if (state.epoch == epoch) {
        state.running = false;
        state.speaker = null;
        state.activeThread = null;
        _pendingGroups.remove(group.id);
        _scheduleServerSync();
        unawaited(_saveRoomStates());
        if (!_disposed) notifyListeners();
        if (state.stranded.isNotEmpty) {
          _scheduleStrandedHarvest(group, members);
        }
      }
    }
  }

  Future<({String runtime, String? stored, Map<String, dynamic>? snapshot})>
  _ensureGroupSession(BotGroup group, BotIdentity member) async {
    final state = _stateFor(group.id);
    final title = 'Group: ${group.roomId}';
    var stored = state.sessions[member.key];
    if (stored != null && stored.isNotEmpty) {
      try {
        final resumed = await connection
            .requestForOwner(member.route, 'session.resume', {
              'session_id': stored,
              'profile': member.profile,
              'cols': 48,
              'source': 'mobile-bot-group',
            });
        final runtime = resumed['session_id']?.toString();
        if (runtime?.isNotEmpty == true) {
          return (runtime: runtime!, stored: stored, snapshot: resumed);
        }
      } catch (_) {
        state.sessions.remove(member.key);
      }
    }

    final listed = await connection
        .requestForOwner(member.route, 'session.list', {
          'profile': member.profile,
          'title': title,
          'limit': 200,
          'include_hidden': true,
        });
    final matching = (listed['sessions'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .where(
          (row) =>
              row['root_title']?.toString() == title ||
              row['title']?.toString() == title,
        )
        .firstOrNull;
    if (matching != null) {
      stored = (matching['id'] ?? matching['resolved_id'])?.toString();
      if (stored?.isNotEmpty == true) {
        final resumed = await connection
            .requestForOwner(member.route, 'session.resume', {
              'session_id': stored,
              'profile': member.profile,
              'cols': 48,
              'source': 'mobile-bot-group',
            });
        final runtime = resumed['session_id']?.toString();
        if (runtime?.isNotEmpty == true) {
          state.sessions[member.key] = stored!;
          unawaited(_saveRoomStates());
          connection.sessionOwners.remember(
            SessionOwner(
              durableId: stored,
              runtimeId: runtime,
              route: member.route,
            ),
          );
          return (runtime: runtime!, stored: stored, snapshot: resumed);
        }
      }
    }

    final created = await connection
        .requestForOwner(member.route, 'session.create', {
          'profile': member.profile,
          'title': title,
          'hidden': true,
          'source': 'mobile-bot-group',
          'cols': 48,
        });
    final runtime = created['session_id']?.toString();
    stored = created['stored_session_id']?.toString();
    if (runtime?.isNotEmpty != true) {
      throw StateError('${member.displayName} group session did not start');
    }
    if (stored?.isNotEmpty == true) {
      state.sessions[member.key] = stored!;
      unawaited(_saveRoomStates());
      connection.sessionOwners.remember(
        SessionOwner(
          durableId: stored,
          runtimeId: runtime,
          route: member.route,
        ),
      );
    }
    return (runtime: runtime!, stored: stored, snapshot: null);
  }

  Future<String?> _runGroupMemberTurn(
    BotGroup group,
    List<BotIdentity> members,
    BotIdentity member,
    String threadId,
    int epoch,
    String prompt,
    Completer<void> started,
  ) async {
    final session = await _ensureGroupSession(group, member);
    final before = _messageCount(session.snapshot);
    final turnId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final reply = Completer<String?>();
    _roomSessions[session.runtime] = (
      groupId: group.id,
      author: member.displayName,
      memberKey: member.key,
      route: member.route,
      turnId: turnId,
      threadId: threadId,
    );
    _roomReplyCompleters[session.runtime] = reply;
    try {
      await connection.requestForOwner(member.route, 'prompt.submit', {
        'session_id': session.runtime,
        'text': prompt,
      });
      if (!started.isCompleted) started.complete();

      // A compatibility gateway may not expose resume snapshots. In that
      // case event completion remains authoritative and no polling timer is
      // created. Current gateways support both, which closes dropped-event
      // and long-running-background-session gaps.
      Map<String, dynamic>? firstSnapshot;
      try {
        firstSnapshot = await connection
            .requestForOwner(member.route, 'session.resume', {
              'session_id': session.stored ?? session.runtime,
              'profile': member.profile,
            });
      } catch (_) {}
      if (firstSnapshot == null) return await reply.future;

      final polled = _pollGroupMemberTurn(
        group,
        member,
        session.runtime,
        session.stored,
        threadId,
        before,
        firstSnapshot,
        reply,
      );
      return await Future.any([reply.future, polled]);
    } finally {
      _releaseRoomSession(session.runtime);
    }
  }

  int _messageCount(Map<String, dynamic>? snapshot) {
    final messages = snapshot?['messages'];
    if (messages is List) return messages.length;
    return (snapshot?['message_count'] as num?)?.toInt() ?? 0;
  }

  String? _latestAssistantAfter(Map<String, dynamic> snapshot, int before) {
    final messages = snapshot['messages'];
    if (messages is! List || messages.length <= before) return null;
    for (var index = messages.length - 1; index >= before; index--) {
      final raw = messages[index];
      if (raw is! Map || raw['role']?.toString() != 'assistant') continue;
      final content = raw['content'];
      if (content is String) return content.trim();
      if (content is List) {
        return content
            .map(
              (part) => part is String
                  ? part
                  : part is Map
                  ? (part['text'] ?? '').toString()
                  : '',
            )
            .join()
            .trim();
      }
      return (raw['text'] ?? '').toString().trim();
    }
    return null;
  }

  Future<String?> _pollGroupMemberTurn(
    BotGroup group,
    BotIdentity member,
    String runtime,
    String? stored,
    String threadId,
    int before,
    Map<String, dynamic> firstSnapshot,
    Completer<String?> eventReply,
  ) async {
    final startedAt = DateTime.now();
    var deadline = startedAt.add(_groupTurnTimeout);
    var snapshot = firstSnapshot;
    while (_roomSessions.containsKey(runtime) && !eventReply.isCompleted) {
      final busy = snapshot['inflight'] == true || snapshot['running'] == true;
      final awaitingUser = _syncGroupRequest(group, member, runtime, snapshot);
      final text = _latestAssistantAfter(snapshot, before);
      if (!busy && !awaitingUser && text != null) return text;
      final now = DateTime.now();
      if (busy || awaitingUser) {
        final extended = now.add(_groupTurnTimeout);
        final hard = startedAt.add(_groupTurnHardCap);
        deadline = extended.isBefore(hard) ? extended : hard;
      }
      if (!now.isBefore(deadline)) break;
      await Future<void>.delayed(_groupTurnPollInterval);
      if (!_roomSessions.containsKey(runtime) || eventReply.isCompleted) break;
      try {
        snapshot = await connection.requestForOwner(
          member.route,
          'session.resume',
          {'session_id': stored ?? runtime, 'profile': member.profile},
        );
      } catch (_) {
        // A transient resume failure does not retarget or abandon the turn.
      }
    }
    if (!eventReply.isCompleted && _roomSessions.containsKey(runtime)) {
      _stateFor(group.id).stranded[member.key] = _BotStrandedTurn(
        before: before,
        threadId: threadId,
      );
      unawaited(_saveRoomStates());
    }
    return null;
  }

  bool _syncGroupRequest(
    BotGroup group,
    BotIdentity member,
    String runtime,
    Map<String, dynamic> snapshot,
  ) {
    final clarify = snapshot['pending_clarify'];
    final approval = snapshot['pending_approval'];
    final raw = clarify is Map
        ? clarify.cast<String, dynamic>()
        : approval is Map
        ? approval.cast<String, dynamic>()
        : null;
    final key = '${group.id}\u0000${member.key}';
    if (raw == null || (raw['request_id'] ?? '').toString().isEmpty) {
      if (_groupRequests.remove(key) != null) notifyListeners();
      return false;
    }
    final type = clarify is Map ? 'clarify.request' : 'approval.request';
    final request = PendingRequest.fromEvent(
      GatewayEvent(
        type: type,
        payload: raw,
        sessionId: snapshot['session_id']?.toString() ?? runtime,
        profile: member.profile,
      ),
    ).withScope(ownerRoute: member.route);
    final current = _groupRequests[key];
    if (current?.request.requestId != request.requestId) {
      _groupRequests[key] = BotGroupPendingRequest(
        groupId: group.id,
        memberKey: member.key,
        memberName: member.displayName,
        route: member.route,
        request: request,
      );
      notifyListeners();
    }
    return true;
  }

  void _setGroupRequestFromEvent(
    ({
      String groupId,
      String author,
      String memberKey,
      OwnerRoute route,
      String turnId,
      String threadId,
    })
    binding,
    GatewayEvent event,
  ) {
    final request = PendingRequest.fromEvent(
      event,
    ).withScope(ownerRoute: binding.route);
    if (request.requestId.isEmpty) return;
    final pending = BotGroupPendingRequest(
      groupId: binding.groupId,
      memberKey: binding.memberKey,
      memberName: binding.author,
      route: binding.route,
      request: request,
    );
    _groupRequests[pending.key] = pending;
    notifyListeners();
  }

  Future<void> respondToGroupRequest(
    BotGroupPendingRequest pending, {
    String? choice,
    String? answer,
    Map<String, String> answers = const {},
  }) async {
    final request = pending.request;
    if (request.kind == RequestKind.approval) {
      await connection.requestForOwner(pending.route, 'approval.respond', {
        if (request.sessionId != null) 'session_id': request.sessionId,
        'request_id': request.requestId,
        'choice': choice?.isNotEmpty == true ? choice : 'deny',
      });
    } else if (request.questions.isNotEmpty) {
      for (final question in request.questions) {
        await connection.requestForOwner(pending.route, 'clarify.respond', {
          'request_id': request.requestId,
          'question_id': question.id,
          'answer': answers[question.id] ?? '',
        });
      }
    } else {
      await connection.requestForOwner(pending.route, 'clarify.respond', {
        'request_id': request.requestId,
        'answer': answer ?? choice ?? '',
      });
    }
    if (_groupRequests[pending.key]?.request.requestId == request.requestId) {
      _groupRequests.remove(pending.key);
      notifyListeners();
    }
  }

  Future<void> _harvestStrandedReply(BotGroup group, BotIdentity member) async {
    final state = _stateFor(group.id);
    final marker = state.stranded[member.key];
    if (marker == null) return;
    final stored = state.sessions[member.key];
    if (stored == null || stored.isEmpty) {
      state.stranded.remove(member.key);
      return;
    }
    Map<String, dynamic> snapshot;
    try {
      snapshot = await connection.requestForOwner(
        member.route,
        'session.resume',
        {'session_id': stored, 'profile': member.profile},
      );
    } catch (_) {
      return;
    }
    if (snapshot['inflight'] == true || snapshot['running'] == true) return;
    if (_syncGroupRequest(
      group,
      member,
      snapshot['session_id']?.toString() ?? stored,
      snapshot,
    )) {
      return;
    }
    state.stranded.remove(member.key);
    final reply = _latestAssistantAfter(snapshot, marker.before);
    if (!_isGroupPass(reply)) {
      _appendRoom(
        BotRoomMessage(
          id: 'late-${DateTime.now().microsecondsSinceEpoch}',
          groupId: group.id,
          author: member.displayName,
          text: reply!.trim(),
          at: DateTime.now(),
          threadId: marker.threadId,
        ),
      );
    }
    unawaited(_saveRoomStates());
  }

  void _scheduleStrandedHarvest(BotGroup group, List<BotIdentity> members) {
    _harvestTimers[group.id]?.cancel();
    var attempts = 0;
    _harvestTimers[group.id] = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      attempts += 1;
      final state = _stateFor(group.id);
      if (state.running || state.stranded.isEmpty || attempts >= 60) {
        timer.cancel();
        _harvestTimers.remove(group.id);
        return;
      }
      for (final member in members) {
        if (state.stranded.containsKey(member.key)) {
          await _harvestStrandedReply(group, member);
        }
      }
    });
  }

  void _releaseRoomSession(String sessionId) {
    _roomBuffers.remove(sessionId);
    _roomReplyCompleters.remove(sessionId);
    _roomSessions.remove(sessionId);
  }

  Future<void> stopGroup(BotGroup group) async {
    final state = _stateFor(group.id);
    state.epoch += 1;
    final active = _roomSessions.entries
        .where((entry) => entry.value.groupId == group.id)
        .toList();
    await Future.wait(
      active.map((entry) async {
        try {
          await connection.requestForOwner(entry.value.route, 'session.stop', {
            'session_id': entry.key,
          });
        } catch (_) {}
        final completer = _roomReplyCompleters.remove(entry.key);
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
        }
        _releaseRoomSession(entry.key);
      }),
    );
    state.running = false;
    state.speaker = null;
    state.activeThread = null;
    _pendingGroups.remove(group.id);
    unawaited(_saveRoomStates());
    notifyListeners();
  }

  Future<void> duplicateBot(BotIdentity bot) async {
    String? candidate;
    for (var suffix = 2; suffix < 100; suffix++) {
      final ending = '-$suffix';
      final base = bot.profile.substring(
        0,
        bot.profile.length.clamp(0, 64 - ending.length),
      );
      final value = '$base$ending';
      if (!bots.any(
        (item) =>
            item.route.connectionId == bot.route.connectionId &&
            item.profile == value,
      )) {
        candidate = value;
        break;
      }
    }
    if (candidate == null) throw StateError('no free profile name');
    await connection.requestForOwner(bot.route, 'profiles.create', {
      'name': candidate,
      'clone_from': bot.profile,
      'description': bot.description,
    });
    await refresh();
  }

  Future<List<BotRoutine>> listBotRoutines(BotIdentity bot) async {
    final result = await connection.requestForOwner(bot.route, 'cron.manage', {
      'action': 'list',
      'include_disabled': true,
      'profile': bot.profile,
    });
    final all = (result['jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => BotRoutine.fromJson(row.cast<String, dynamic>()))
        .toList();
    final scoped = result['scoped']?.toString().trim().toLowerCase();
    final routines = scoped == bot.profile.trim().toLowerCase()
        ? all
        : all.where((routine) {
            final match = RegExp(
              r'^\[bot:([a-z0-9][a-z0-9_-]*)\]',
              caseSensitive: false,
            ).firstMatch(routine.name);
            final owner = match?.group(1)?.toLowerCase() ?? 'default';
            return owner == bot.profile.toLowerCase();
          }).toList();
    await Future.wait(
      routines.where((routine) => routine.legacyUnsafe && routine.enabled).map((
        routine,
      ) async {
        try {
          await mutateBotRoutine(bot, routine.id, 'pause');
        } catch (_) {}
      }),
    );
    return [
      for (final routine in routines)
        if (routine.legacyUnsafe && routine.enabled)
          BotRoutine(
            id: routine.id,
            name: routine.name,
            title: routine.title,
            schedule: routine.schedule,
            promptPreview: routine.promptPreview,
            enabled: false,
            state: 'paused',
            nextRunAt: routine.nextRunAt,
            lastRunAt: routine.lastRunAt,
            lastStatus: routine.lastStatus,
            deliver: routine.deliver,
            model: routine.model,
            workdir: routine.workdir,
            repeat: routine.repeat,
            issue: routine.issue,
            legacyUnsafe: true,
          )
        else
          routine,
    ];
  }

  Future<void> createBotRoutine(BotIdentity bot, BotRoutineDraft draft) async {
    final title = draft.title.trim();
    final instruction = draft.instruction.trim();
    final schedule = draft.schedule.trim();
    if (title.isEmpty || instruction.isEmpty || schedule.isEmpty) {
      throw ArgumentError(runtimeL10n.botRoutineFieldsRequired);
    }
    if (title.contains('\u0000') ||
        instruction.contains('\u0000') ||
        schedule.contains('\u0000')) {
      throw ArgumentError(runtimeL10n.botRoutineNulForbidden);
    }
    await connection.requestForOwner(bot.route, 'cron.manage', {
      'action': 'add',
      'name': '[bot:${bot.profile}] $title',
      'schedule': schedule,
      'prompt': instruction,
      'profile': bot.profile,
      if (draft.repeat != null && draft.repeat! > 0) 'repeat': draft.repeat,
      if (draft.continuity) 'continuity': true,
      if (draft.deliverToBotChat) 'deliver': 'bot-chat',
    });
  }

  Future<void> mutateBotRoutine(
    BotIdentity bot,
    String routineId,
    String action,
  ) async {
    if (!{'pause', 'resume', 'remove'}.contains(action)) {
      throw ArgumentError.value(action, 'action', 'unsupported routine action');
    }
    await connection.requestForOwner(bot.route, 'cron.manage', {
      'action': action,
      'name': routineId,
      'profile': bot.profile,
    });
  }

  Future<void> deleteBot(BotIdentity bot) async {
    if (bot.profile.toLowerCase() == 'default') {
      throw StateError('the default profile cannot be deleted');
    }
    final runtime = connection.registry.runtimes
        .where((item) => item.id == bot.route.connectionId)
        .firstOrNull;
    if (runtime == null) throw StateError('bot connection is unavailable');
    await runtime.api.deleteProfile(bot.profile);
    groups = List.unmodifiable(
      groups
          .map(
            (group) => BotGroup(
              id: group.id,
              roomId: group.roomId,
              name: group.name,
              memberKeys: group.memberKeys
                  .where((key) => key != bot.key)
                  .toList(),
              updatedAt: DateTime.now(),
              revision: group.revision + 1,
            ),
          )
          .where((group) => group.memberKeys.length >= 2),
    );
    await _saveGroups();
    _scheduleServerSync(allowEmpty: true);
    await refresh();
  }

  List<BotRoomMessage> messagesFor(String groupId) => roomMessages
      .where((message) => message.groupId == groupId)
      .toList(growable: false);

  void _onRoomEvent(RoutedGatewayEvent routed) {
    final sessionId = routed.event.sessionId;
    final binding = sessionId == null ? null : _roomSessions[sessionId];
    if (binding == null) return;
    final event = routed.event;
    if (event.type == 'message.delta') {
      final value = event.payload['text'];
      final text = value is String
          ? value
          : value is Map
          ? '${value['text'] ?? value['output_text'] ?? ''}'
          : '';
      if (text.isNotEmpty) {
        (_roomBuffers[sessionId!] ??= StringBuffer()).write(text);
      }
    }
    if (event.type == 'clarify.request' || event.type == 'approval.request') {
      _setGroupRequestFromEvent(binding, event);
      return;
    }
    if (event.type == 'message.complete') {
      final direct = event.payload['text']?.toString() ?? '';
      final text = direct.isNotEmpty
          ? direct
          : _roomBuffers.remove(sessionId)?.toString() ?? '';
      final completer = _roomReplyCompleters[sessionId];
      if (completer != null && !completer.isCompleted) {
        completer.complete(text.trim());
      }
    } else if (event.type == 'error') {
      final message =
          (event.payload['message'] ??
                  event.payload['error'] ??
                  'Bot turn failed')
              .toString();
      final completer = _roomReplyCompleters[sessionId];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(StateError(message));
      }
    }
  }

  void _appendRoom(BotRoomMessage message) {
    final combined = [...roomMessages, message];
    final groupLog = combined
        .where((item) => item.groupId == message.groupId)
        .toList();
    final removed = (groupLog.length - _groupChatRetainedMessages).clamp(
      0,
      groupLog.length,
    );
    if (removed > 0) {
      final removedIds = groupLog.take(removed).map((item) => item.id).toSet();
      roomMessages = List.unmodifiable(
        combined.where((item) => !removedIds.contains(item.id)),
      );
      _attachmentRefs.removeWhere((id, _) => removedIds.contains(id));
      final state = _stateFor(message.groupId);
      for (final key in state.watermarks.keys.toList()) {
        state.watermarks[key] = (state.watermarks[key]! - removed).clamp(
          0,
          _groupChatRetainedMessages,
        );
      }
      unawaited(_saveRoomStates());
    } else {
      roomMessages = List.unmodifiable(combined);
    }
    unawaited(_saveRooms());
    _scheduleServerSync();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final state in _roomStates.values) {
      state.epoch += 1;
    }
    _events?.cancel();
    _syncTimer?.cancel();
    for (final timer in _harvestTimers.values) {
      timer.cancel();
    }
    _harvestTimers.clear();
    for (final completer in _roomReplyCompleters.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _roomReplyCompleters.clear();
    _roomSessions.clear();
    super.dispose();
  }

  Future<void> _saveGroups() async =>
      (await SharedPreferences.getInstance()).setString(
        _groupsKey,
        jsonEncode(groups.map((g) => g.toJson()).toList()),
      );

  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _roomsKey,
      jsonEncode(roomMessages.map((message) => message.toJson()).toList()),
    );
    await prefs.setString(_deletionsKey, jsonEncode(_deletedRooms));
  }

  Future<void> _saveRoomStates() async =>
      (await SharedPreferences.getInstance()).setString(
        _roomStatesKey,
        jsonEncode(
          _roomStates.map((key, value) => MapEntry(key, value.toJson())),
        ),
      );

  void _scheduleServerSync({bool allowEmpty = false}) {
    _syncTimer?.cancel();
    _syncTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_syncServerState(allowEmpty: allowEmpty)),
    );
  }

  Map<String, dynamic> _serverSnapshot() {
    final rankedGroups = [...groups]
      ..sort((left, right) {
        final leftLog = messagesFor(left.id);
        final rightLog = messagesFor(right.id);
        final leftAt = leftLog.isEmpty
            ? 0
            : leftLog.last.at.millisecondsSinceEpoch;
        final rightAt = rightLog.isEmpty
            ? 0
            : rightLog.last.at.millisecondsSinceEpoch;
        return rightAt.compareTo(leftAt);
      });
    final rooms = <String, dynamic>{};
    final deletedEntries = _deletedRooms.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final envelope = <String, dynamic>{
      'version': 3,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'rooms': rooms,
      if (deletedEntries.isNotEmpty)
        'deleted': Map.fromEntries(deletedEntries.take(64)),
    };
    for (final group in rankedGroups) {
      final log = messagesFor(group.id).takeLast(16).map((message) {
        final isUser = message.author == 'You';
        return {
          'id': _truncate(message.id, 160),
          'from': {'kind': isUser ? 'user' : 'member', 'name': message.author},
          'text': _truncate(message.text, 1200),
          'at': message.at.millisecondsSinceEpoch,
          'thread': _truncate(message.threadId, 128),
        };
      }).toList();
      final key = 'id:${group.roomId}';
      final compact = <String, dynamic>{
        'name': _truncate(group.name, 64),
        'roomId': _truncate(group.roomId, 128),
        'log': log,
        'revision': group.revision,
        'members': group.memberKeys.take(maxGroupMembers).map((key) {
          final bot = bots.where((item) => item.key == key).firstOrNull;
          return {
            'name': _truncate(bot?.profile ?? key.split('\u0000').last, 128),
            if (bot != null) 'handle': _truncate(bot.displayName, 128),
            'connectionId': _truncate(
              bot?.route.connectionId.value ?? key.split('\u0000').first,
              128,
            ),
            'sourceScoped': true,
          };
        }).toList(),
      };
      rooms[key] = compact;
      while (log.length > 1 &&
          _conservativeJsonBytes(envelope) > _groupProjectionMaxBytes) {
        log.removeAt(0);
      }
      if (_conservativeJsonBytes(envelope) > _groupProjectionMaxBytes) {
        rooms.remove(key);
      }
    }
    return envelope;
  }

  @visibleForTesting
  Map<String, dynamic> debugServerSnapshot() => _serverSnapshot();

  @visibleForTesting
  int debugServerSnapshotBytes() => _conservativeJsonBytes(_serverSnapshot());

  @visibleForTesting
  Future<void> debugSyncServerState({bool allowEmpty = false}) =>
      _syncServerState(allowEmpty: allowEmpty);

  String _truncate(String value, int maxChars) =>
      value.length > maxChars ? value.substring(0, maxChars) : value;

  int _conservativeJsonBytes(Object? value) {
    var bytes = 0;
    for (final rune in jsonEncode(value).runes) {
      if (rune <= 0x7f) {
        bytes += 1;
        if (rune == 0x2c || rune == 0x3a) bytes += 1;
      } else {
        bytes += rune <= 0xffff ? 6 : 12;
      }
    }
    return bytes;
  }

  Future<void> _syncServerState({bool allowEmpty = false}) async {
    if (groups.isEmpty && !allowEmpty) return;
    await Future.wait(
      connection.registry.runtimes.map((runtime) async {
        final route = OwnerRoute(connectionId: runtime.id, profile: 'default');
        for (var attempt = 0; attempt < 4; attempt++) {
          try {
            final result = await connection.requestForOwner(
              route,
              'profiles.list',
              {'include_sessions': false},
            );
            final profile = (result['profiles'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .where((item) => item['name'] == 'default')
                .firstOrNull;
            final remote = (profile?['ui_meta'] as Map?)?[_syncMetaKey];
            if (remote is Map) {
              _mergeRemoteSnapshot(remote.cast<String, dynamic>(), runtime.id);
            }
            final supportsCas =
                profile?.containsKey('ui_meta_revisions') == true;
            final revision =
                ((profile?['ui_meta_revisions'] as Map?)?[_syncMetaKey] as num?)
                    ?.toInt() ??
                0;
            final configured = await connection.requestForOwner(
              route,
              'profiles.configure',
              {
                'name': 'default',
                'ui_meta': {_syncMetaKey: _serverSnapshot()},
                if (supportsCas)
                  'ui_meta_expected_revisions': {_syncMetaKey: revision},
              },
            );
            final applied = configured['applied'];
            if (applied is! Map || applied['ui_meta'] != true) {
              throw StateError('gateway rejected group chat metadata');
            }
            if (supportsCas) {
              final appliedRevision =
                  ((applied['ui_meta_revisions'] as Map?)?[_syncMetaKey]
                          as num?)
                      ?.toInt();
              if (appliedRevision != revision + 1) {
                throw StateError('group chat metadata CAS conflict');
              }
            }
            return;
          } catch (_) {
            if (attempt == 3) return;
            await Future<void>.delayed(
              Duration(milliseconds: 100 * (1 << attempt)),
            );
          }
        }
      }),
    );
  }

  void _mergeRemoteSnapshot(
    Map<String, dynamic> snapshot,
    ConnectionId source,
  ) {
    final deleted =
        (snapshot['deleted'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in deleted.entries) {
      final revision = (entry.value as num?)?.toInt() ?? 0;
      if (revision > (_deletedRooms[entry.key] ?? 0)) {
        _deletedRooms[entry.key] = revision;
      }
    }
    final remoteRooms =
        (snapshot['rooms'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in remoteRooms.entries) {
      if (_deletedRooms.containsKey(entry.key) || entry.value is! Map) continue;
      final room = (entry.value as Map).cast<String, dynamic>();
      final roomId =
          (room['roomId'] ??
                  entry.key.replaceFirst(RegExp(r'^(id:|name:)'), ''))
              .toString();
      final groupId = roomId;
      final members = (room['members'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final member = raw.cast<String, dynamic>();
            final profile = (member['name'] ?? '').toString();
            final connectionId = (member['connectionId'] ?? source.value)
                .toString();
            return '$connectionId\u0000$profile';
          })
          .where((key) => !key.endsWith('\u0000'))
          .toList();
      final remoteGroup = BotGroup(
        id: groupId,
        roomId: roomId,
        name: (room['name'] ?? roomId).toString(),
        memberKeys: members,
        updatedAt: DateTime.now(),
        revision: (room['revision'] as num?)?.toInt() ?? 0,
      );
      final current = groups
          .where((group) => group.roomId == roomId)
          .firstOrNull;
      if (current == null) {
        groups = List.unmodifiable([...groups, remoteGroup]);
      } else if (remoteGroup.revision > current.revision) {
        groups = List.unmodifiable([
          for (final group in groups)
            group.roomId == roomId ? remoteGroup : group,
        ]);
      }
      for (final raw in room['log'] as List? ?? const []) {
        if (raw is! Map) continue;
        final row = raw.cast<String, dynamic>();
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty && roomMessages.any((message) => message.id == id)) {
          continue;
        }
        final from = (row['from'] as Map?)?.cast<String, dynamic>() ?? const {};
        final at = (row['at'] as num?)?.toInt() ?? 0;
        roomMessages = List.unmodifiable([
          ...roomMessages,
          BotRoomMessage(
            id: id.isEmpty ? '$roomId-$at-${roomMessages.length}' : id,
            groupId: groupId,
            author: from['kind'] == 'user'
                ? 'You'
                : (from['name'] ?? 'Bot').toString(),
            text: (row['text'] ?? '').toString(),
            at: DateTime.fromMillisecondsSinceEpoch(at),
            threadId: (row['thread'] ?? 'legacy').toString(),
          ),
        ]);
      }
    }
    roomMessages = List.unmodifiable(
      [...roomMessages]..sort((left, right) => left.at.compareTo(right.at)),
    );
    unawaited(_saveGroups());
    unawaited(_saveRooms());
    // `_syncServerState` calls this outside of `refresh()`'s notify, so a
    // remote merge (another device's groups/messages) must notify here too.
    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList();
    return values.skip(values.length > count ? values.length - count : 0);
  }
}
