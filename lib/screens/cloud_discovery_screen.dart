import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/cloud_discovery.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/web_preview.dart' show webViewSupported;

const _cloudUnsupportedErrorCode = 'cloud-discovery-unsupported';

class CloudDiscoveryScreen extends StatefulWidget {
  final String portalUrl;

  const CloudDiscoveryScreen({
    super.key,
    this.portalUrl = defaultHermesCloudPortal,
  });

  @override
  State<CloudDiscoveryScreen> createState() => _CloudDiscoveryScreenState();
}

class _CloudDiscoveryScreenState extends State<CloudDiscoveryScreen> {
  WebViewController? _controller;
  HermesCloudDiscoveryResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!webViewSupported) {
      _error = _cloudUnsupportedErrorCode;
      _loading = false;
      return;
    }
    final portal = Uri.parse(widget.portalUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CloudDiscovery',
        onMessageReceived: (message) => _onDiscovery(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            final current = Uri.tryParse(url);
            if (current?.scheme == portal.scheme &&
                current?.host == portal.host) {
              _discover();
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      )
      ..loadRequest(portal);
  }

  Future<void> _discover([String? org]) async {
    final controller = _controller;
    if (controller == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await controller.runJavaScript(hermesCloudDiscoveryScript(org));
  }

  void _onDiscovery(String message) {
    try {
      final result = HermesCloudDiscoveryResult.fromBridgeMessage(message);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _error = result.statusCode == 0
            ? result.error ?? context.l10n.cloudDiscoveryFailed
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.cloudDiscoveryInvalidData('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes Cloud'),
        actions: [
          IconButton(
            tooltip: context.l10n.cloudDiscoverAgain,
            onPressed: _controller == null ? null : _discover,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _controller == null
          ? HermesErrorState(
              description: _error == _cloudUnsupportedErrorCode
                  ? context.l10n.cloudDiscoveryUnsupported
                  : _error,
            )
          : Column(
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: _discover,
                        child: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                if (_result?.needsLogin == true)
                  MaterialBanner(
                    content: Text(context.l10n.cloudPortalLoginPrompt),
                    actions: const [SizedBox.shrink()],
                  ),
                if (_result?.needsOrgSelection == true)
                  _OrgPicker(result: _result!, onSelected: _discover),
                if (_result?.agents.isNotEmpty == true)
                  _AgentPicker(
                    result: _result!,
                    onSelected: (agent) => Navigator.of(context).pop(agent),
                  ),
                Expanded(child: WebViewWidget(controller: _controller!)),
              ],
            ),
    );
  }
}

class _OrgPicker extends StatelessWidget {
  final HermesCloudDiscoveryResult result;
  final ValueChanged<String> onSelected;

  const _OrgPicker({required this.result, required this.onSelected});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SizedBox(
      height: 150,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          for (final org in result.orgs)
            ListTile(
              dense: true,
              leading: const Icon(Icons.apartment_outlined),
              title: Text(org.name),
              subtitle: Text(org.role),
              onTap: () => onSelected(org.selector),
            ),
        ],
      ),
    ),
  );
}

class _AgentPicker extends StatelessWidget {
  final HermesCloudDiscoveryResult result;
  final ValueChanged<HermesCloudAgent> onSelected;

  const _AgentPicker({required this.result, required this.onSelected});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SizedBox(
      height: 190,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          for (final agent in result.agents)
            ListTile(
              dense: true,
              leading: Icon(
                Icons.cloud_outlined,
                color: agent.dashboardGatewayState == 'active'
                    ? HermesSemantic.green
                    : null,
              ),
              title: Text(agent.name),
              subtitle: Text(
                agent.dashboardUrl == null
                    ? 'Provisioning · ${agent.status}'
                    : '${agent.status} · ${agent.dashboardGatewayState}',
              ),
              enabled: agent.dashboardUrl != null,
              onTap: agent.dashboardUrl == null
                  ? null
                  : () => onSelected(agent),
            ),
        ],
      ),
    ),
  );
}
