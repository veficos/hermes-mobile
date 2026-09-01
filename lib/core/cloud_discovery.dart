library;

import 'dart:convert';

const defaultHermesCloudPortal = 'https://portal.nousresearch.com';

class HermesCloudAgent {
  final String id;
  final String name;
  final String status;
  final String? dashboardUrl;
  final String dashboardGatewayState;

  const HermesCloudAgent({
    required this.id,
    required this.name,
    required this.status,
    required this.dashboardUrl,
    required this.dashboardGatewayState,
  });

  factory HermesCloudAgent.fromJson(Map<String, dynamic> json) =>
      HermesCloudAgent(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        dashboardUrl: json['dashboardUrl']?.toString(),
        dashboardGatewayState:
            json['dashboardGatewayState']?.toString() ?? 'unknown',
      );
}

class HermesCloudOrg {
  final String id;
  final String? slug;
  final String name;
  final bool isPersonal;
  final String role;

  const HermesCloudOrg({
    required this.id,
    required this.slug,
    required this.name,
    required this.isPersonal,
    required this.role,
  });

  String get selector => slug?.trim().isNotEmpty == true ? slug! : id;

  factory HermesCloudOrg.fromJson(Map<String, dynamic> json) => HermesCloudOrg(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString(),
    name: json['name']?.toString() ?? json['id']?.toString() ?? '',
    isPersonal: json['isPersonal'] == true,
    role: json['role']?.toString() ?? 'MEMBER',
  );
}

class HermesCloudDiscoveryResult {
  final int statusCode;
  final List<HermesCloudAgent> agents;
  final List<HermesCloudOrg> orgs;
  final HermesCloudOrg? org;
  final String? error;

  const HermesCloudDiscoveryResult({
    required this.statusCode,
    this.agents = const [],
    this.orgs = const [],
    this.org,
    this.error,
  });

  bool get needsLogin => statusCode == 401;
  bool get needsOrgSelection => statusCode == 409 && orgs.isNotEmpty;

  factory HermesCloudDiscoveryResult.fromBridgeMessage(String message) {
    final envelope = (jsonDecode(message) as Map).cast<String, dynamic>();
    final status = (envelope['status'] as num?)?.toInt() ?? 0;
    dynamic body = envelope['body'];
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    final json = body is Map
        ? body.cast<String, dynamic>()
        : <String, dynamic>{};
    final agents = (json['agents'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => HermesCloudAgent.fromJson(value.cast<String, dynamic>()),
        )
        .where((agent) => agent.id.isNotEmpty)
        .toList(growable: false);
    final orgs = (json['orgs'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => HermesCloudOrg.fromJson(value.cast<String, dynamic>()))
        .where((org) => org.id.isNotEmpty)
        .toList(growable: false);
    final rawOrg = json['org'];
    return HermesCloudDiscoveryResult(
      statusCode: status,
      agents: agents,
      orgs: orgs,
      org: rawOrg is Map
          ? HermesCloudOrg.fromJson(rawOrg.cast<String, dynamic>())
          : null,
      error: json['error']?.toString(),
    );
  }
}

String hermesCloudDiscoveryScript([String? org]) {
  final query = org?.trim().isNotEmpty == true
      ? '?org=${Uri.encodeQueryComponent(org!.trim())}'
      : '';
  return '''(() => {
    fetch('/api/agents$query', {credentials:'include'})
      .then(async response => {
        const body = await response.text();
        CloudDiscovery.postMessage(JSON.stringify({status:response.status,body}));
      })
      .catch(error => CloudDiscovery.postMessage(JSON.stringify({status:0,body:JSON.stringify({error:String(error)})})));
  })();''';
}
