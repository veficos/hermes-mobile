library;

import 'dart:async';

import 'api_client.dart';

class McpOAuthCancelled implements Exception {
  const McpOAuthCancelled();
}

class McpOAuthFlow {
  const McpOAuthFlow({
    this.pollInterval = const Duration(seconds: 1),
    this.timeout = const Duration(minutes: 3),
    this.transientFailureLimit = 3,
  });

  final Duration pollInterval;
  final Duration timeout;
  final int transientFailureLimit;

  Future<Map<String, dynamic>> authorize({
    required ApiClient api,
    required String server,
    String? profile,
    String? flowId,
    String? authorizationUrl,
    required Future<bool> Function(Uri url) openAuthorization,
    required bool Function() cancelled,
    void Function(String flowId, String authorizationUrl)? onStarted,
    void Function(String flowId)? onFinished,
  }) async {
    var id = flowId?.trim() ?? '';
    var url = authorizationUrl?.trim() ?? '';
    if (id.isEmpty || url.isEmpty) {
      final started = await api.mcpStartAuth(server, profile: profile);
      if (started['status'] == 'error') {
        throw StateError(
          (started['error'] ?? 'MCP OAuth could not be started').toString(),
        );
      }
      id = started['flow_id']?.toString().trim() ?? '';
      url = started['authorization_url']?.toString().trim() ?? '';
    }
    if (id.isEmpty || url.isEmpty) {
      throw StateError('MCP OAuth did not return an authorization URL');
    }
    onStarted?.call(id, url);
    try {
      if (!await openAuthorization(Uri.parse(url))) {
        throw StateError('Could not open the MCP authorization page');
      }
      final deadline = DateTime.now().add(timeout);
      var failures = 0;
      while (DateTime.now().isBefore(deadline)) {
        if (cancelled()) throw const McpOAuthCancelled();
        try {
          final current = await api.mcpAuthFlow(id, profile: profile);
          failures = 0;
          final status = current['status']?.toString().toLowerCase();
          if (status == 'approved') return current;
          if (status == 'error' || status == 'denied') {
            throw StateError(
              (current['error'] ?? 'MCP authorization failed').toString(),
            );
          }
        } catch (error) {
          if (error is StateError || error is McpOAuthCancelled) rethrow;
          failures++;
          if (failures >= transientFailureLimit) rethrow;
        }
        await Future<void>.delayed(pollInterval);
      }
      throw TimeoutException('MCP authorization timed out', timeout);
    } finally {
      onFinished?.call(id);
    }
  }
}
