/// Versioned description of the native surfaces this app can service for an
/// agent session. The snapshot is sent only when a session is created/resumed;
/// changing a running app never mutates an agent's tools mid-conversation.
library;

const int hermesMobileCapabilityVersion = 2;

const Set<String> hermesMobileSurfaceCapabilities = {
  'terminal.read',
  'terminal.close',
  'preview.open',
  'preview.close',
  'preview.read',
  'preview.act',
  'preview.annotate',
  'pane.reveal',
  'layout.apply',
  'message.reaction',
  'mcp.setup',
  'tour.preview',
  'tour.app',
};

Map<String, dynamic> hermesMobileClientCapabilities() => {
  'version': hermesMobileCapabilityVersion,
  'surfaces': hermesMobileSurfaceCapabilities.toList(growable: false)..sort(),
};

Map<String, dynamic> hermesMobileSessionClientFields() => {
  'source': 'mobile',
  'client_capabilities': hermesMobileClientCapabilities(),
};
