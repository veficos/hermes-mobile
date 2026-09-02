import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_gateway_event_family.dart';

void main() {
  test('gateway events are partitioned by state authority', () {
    expect(
      chatGatewayEventFamily('message.delta'),
      ChatGatewayEventFamily.message,
    );
    expect(chatGatewayEventFamily('tool.start'), ChatGatewayEventFamily.tool);
    expect(
      chatGatewayEventFamily('clarify.request'),
      ChatGatewayEventFamily.input,
    );
    expect(
      chatGatewayEventFamily('subagent.start'),
      ChatGatewayEventFamily.delegation,
    );
    expect(
      chatGatewayEventFamily('subagent.progress'),
      ChatGatewayEventFamily.delegation,
    );
    expect(
      chatGatewayEventFamily('reaction'),
      ChatGatewayEventFamily.message,
    );
    expect(
      chatGatewayEventFamily('browser.progress'),
      ChatGatewayEventFamily.preview,
    );
    expect(
      chatGatewayEventFamily('status.update'),
      ChatGatewayEventFamily.status,
    );
    expect(
      chatGatewayEventFamily('future.event'),
      ChatGatewayEventFamily.unknown,
    );
  });
}
