import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/widgets/session/session_list_meta.dart';

void main() {
  test('sessionLocationLabel uses cwd basename and git branch', () {
    final row = SessionRow(
      id: 's1',
      cwd: '/home/u/projects/hermes-mobile',
      gitBranch: 'feat/session-meta',
    );
    expect(sessionLocationLabel(row), 'hermes-mobile · feat/session-meta');
    expect(sessionPathBasename(r'C:\work\app\'), 'app');
  });

  test('sessionActivityTime prefers lastMessageAt', () {
    final row = SessionRow(
      id: 's1',
      startedAt: DateTime.utc(2026, 1, 1),
      lastMessageAt: DateTime.utc(2026, 8, 24, 3).millisecondsSinceEpoch,
    );
    expect(sessionActivityTime(row)?.toUtc().month, 8);
  });

  test('needsAttention and isActivelyWorking split streaming states', () {
    final pending = SessionRow(
      id: 'a',
      pendingUserMessage: true,
      isStreaming: true,
    );
    expect(pending.needsAttention, isTrue);
    expect(pending.isActivelyWorking, isTrue);
    expect(pending.effectivelyStreaming, isTrue);

    final streaming = SessionRow(id: 'b', isStreaming: true);
    expect(streaming.needsAttention, isFalse);
    expect(streaming.isActivelyWorking, isTrue);
  });

  test('compression failure only needs attention during its cooldown', () {
    final now = DateTime.utc(2026, 8, 25, 8);
    final expired = SessionRow(
      id: 'expired',
      compressionFailureError: 'Connection error.',
      compressionFailureCooldownUntil: now.subtract(const Duration(hours: 1)),
    );
    final active = SessionRow(
      id: 'active',
      compressionFailureError: 'Connection error.',
      compressionFailureCooldownUntil: now.add(const Duration(minutes: 5)),
    );

    expect(hasActiveCompressionFailure(expired, now: now), isFalse);
    expect(hasActiveCompressionFailure(active, now: now), isTrue);
  });
}
