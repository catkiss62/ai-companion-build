import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MCP outcome preserves typed content instead of flattening it', () {
    final image = McpContentBlock.fromJson(<String, Object?>{
      'type': 'image',
      'data': 'YWJj',
      'mimeType': 'image/png',
    });
    final link = McpContentBlock.fromJson(<String, Object?>{
      'type': 'resource_link',
      'name': 'live view',
      'uri': 'https://toy.cedarstar.org/view/1',
      'mimeType': 'text/html',
    });
    final outcome = McpToolOutcome(
      content: <McpContentBlock>[
        const McpContentBlock(kind: McpContentKind.text, text: 'real result'),
        image,
        link,
      ],
      isError: false,
      structuredContent: <String, Object?>{'turn': 2},
    );

    expect(outcome.images.single.mimeType, 'image/png');
    expect(outcome.text, contains('real result'));
    expect(outcome.text, contains('MCP_IMAGE'));
    expect(outcome.text, contains('https://toy.cedarstar.org/view/1'));
    expect(outcome.text, contains('"turn":2'));
  });

  test('generic MCP server config contains transport metadata', () {
    final config = McpServerConfig(
      id: 'example',
      displayName: 'Example',
      endpoint: Uri.parse('https://example.com/mcp'),
      transport: McpTransportKind.sse,
    );
    expect(config.transport.key, 'sse');
    expect(config.enabled, isTrue);
    expect(config.endpoint.scheme, 'https');
  });
}
