library;

enum ChatGatewayEventFamily {
  lifecycle,
  message,
  tool,
  input,
  status,
  delegation,
  preview,
  unknown,
}

const _messageEvents = {
  'message.start',
  'message.delta',
  'message.interim',
  'message.complete',
  'message.reaction',
  'reaction',
  'reasoning.delta',
  'thinking.delta',
  'reasoning.available',
};
const _toolEvents = {
  'tool.start',
  'tool.generating',
  'tool.progress',
  'tool.complete',
};
const _inputEvents = {
  'approval.request',
  'clarify.request',
  'sudo.request',
  'secret.request',
  'mcp.setup.request',
  'interactive.expire',
  'interactive.expired',
};
const _delegationEvents = {
  'subagent.start',
  'subagent.spawn_requested',
  'subagent.text',
  'subagent.thinking',
  'subagent.tool',
  'subagent.progress',
  'subagent.complete',
  'moa.reference',
  'moa.progress',
  'moa.phase',
  'moa.aggregating',
};
const _previewEvents = {
  'browser.progress',
  'preview.restart.progress',
  'preview.restart.complete',
  'preview.restart.error',
};
const _statusEvents = {
  'status.update',
  'review.summary',
  'notification.show',
  'notification.clear',
  'background.complete',
  'error',
};

ChatGatewayEventFamily chatGatewayEventFamily(String type) {
  if (_messageEvents.contains(type)) return ChatGatewayEventFamily.message;
  if (_toolEvents.contains(type)) return ChatGatewayEventFamily.tool;
  if (_inputEvents.contains(type)) return ChatGatewayEventFamily.input;
  if (_delegationEvents.contains(type)) {
    return ChatGatewayEventFamily.delegation;
  }
  if (_previewEvents.contains(type)) return ChatGatewayEventFamily.preview;
  if (_statusEvents.contains(type)) return ChatGatewayEventFamily.status;
  if (type == 'session.reclaimed') return ChatGatewayEventFamily.lifecycle;
  return ChatGatewayEventFamily.unknown;
}
