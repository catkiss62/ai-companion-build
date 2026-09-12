import 'dart:convert';

enum McpTransportKind {
  streamableHttp('streamable_http'),
  sse('sse');

  const McpTransportKind(this.key);
  final String key;

  static McpTransportKind fromKey(String? value) =>
      value == sse.key ? sse : streamableHttp;
}

/// Secret-free server metadata. Credentials and private headers remain in
/// platform secure storage and are never serialized with this configuration.
class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.displayName,
    required this.endpoint,
    this.transport = McpTransportKind.streamableHttp,
    this.enabled = true,
    this.builtIn = false,
    this.headers = const <String, String>{},
  });

  final String id;
  final String displayName;
  final Uri endpoint;
  final McpTransportKind transport;
  final bool enabled;
  final bool builtIn;
  final Map<String, String> headers;
}

class McpToolDescriptor {
  const McpToolDescriptor({
    required this.name,
    this.description = '',
    this.inputSchema,
    this.outputSchema,
    this.annotations,
  });

  final String name;
  final String description;
  final Object? inputSchema;
  final Object? outputSchema;
  final Object? annotations;

  factory McpToolDescriptor.fromJson(Map<Object?, Object?> json) =>
      McpToolDescriptor(
        name: json['name']?.toString().trim() ?? '',
        description: json['description']?.toString().trim() ?? '',
        inputSchema: json['inputSchema'],
        outputSchema: json['outputSchema'],
        annotations: json['annotations'],
      );
}

enum McpContentKind {
  text,
  image,
  audio,
  resource,
  resourceLink,
  unknown,
}

class McpContentBlock {
  const McpContentBlock({
    required this.kind,
    this.text = '',
    this.data = '',
    this.mimeType = '',
    this.uri = '',
    this.name = '',
    this.rawType = '',
  });

  final McpContentKind kind;
  final String text;
  final String data;
  final String mimeType;
  final String uri;
  final String name;
  final String rawType;

  factory McpContentBlock.fromJson(Map<Object?, Object?> json) {
    final type = json['type']?.toString().trim() ?? '';
    if (type == 'text') {
      return McpContentBlock(
        kind: McpContentKind.text,
        text: json['text']?.toString() ?? '',
        rawType: type,
      );
    }
    if (type == 'image' || type == 'audio') {
      return McpContentBlock(
        kind: type == 'image' ? McpContentKind.image : McpContentKind.audio,
        data: json['data']?.toString() ?? '',
        mimeType: json['mimeType']?.toString().trim() ?? '',
        rawType: type,
      );
    }
    if (type == 'resource_link') {
      return McpContentBlock(
        kind: McpContentKind.resourceLink,
        uri: json['uri']?.toString().trim() ?? '',
        name: json['name']?.toString().trim() ?? '',
        mimeType: json['mimeType']?.toString().trim() ?? '',
        text: json['description']?.toString() ?? '',
        rawType: type,
      );
    }
    if (type == 'resource' && json['resource'] is Map) {
      final resource = Map<Object?, Object?>.from(json['resource'] as Map);
      return McpContentBlock(
        kind: McpContentKind.resource,
        uri: resource['uri']?.toString().trim() ?? '',
        mimeType: resource['mimeType']?.toString().trim() ?? '',
        text: resource['text']?.toString() ?? '',
        data: resource['blob']?.toString() ?? '',
        rawType: type,
      );
    }
    return McpContentBlock(
      kind: McpContentKind.unknown,
      text: jsonEncode(json.map((key, value) => MapEntry('$key', value))),
      rawType: type,
    );
  }

  String promptProjection() => switch (kind) {
        McpContentKind.text => text,
        McpContentKind.image =>
          '[MCP_IMAGE mime=${mimeType.isEmpty ? 'unknown' : mimeType} bytes_base64=${data.length}]',
        McpContentKind.audio =>
          '[MCP_AUDIO mime=${mimeType.isEmpty ? 'unknown' : mimeType} bytes_base64=${data.length}]',
        McpContentKind.resource => text.isNotEmpty
            ? '[MCP_RESOURCE uri=$uri mime=$mimeType]\n$text'
            : '[MCP_RESOURCE uri=$uri mime=$mimeType blob_base64=${data.length}]',
        McpContentKind.resourceLink =>
          '[MCP_RESOURCE_LINK name=$name uri=$uri mime=$mimeType]${text.isEmpty ? '' : '\n$text'}',
        McpContentKind.unknown => '[MCP_CONTENT type=$rawType]\n$text',
      };
}

class McpToolOutcome {
  const McpToolOutcome({
    required this.content,
    required this.isError,
    this.structuredContent,
  });

  final List<McpContentBlock> content;
  final bool isError;
  final Object? structuredContent;

  Iterable<McpContentBlock> get images =>
      content.where((item) => item.kind == McpContentKind.image);

  String get text {
    final parts = content
        .map((item) => item.promptProjection().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: true);
    if (structuredContent != null) {
      parts.add('[MCP_STRUCTURED_CONTENT]\n${jsonEncode(structuredContent)}');
    }
    return parts.join('\n').trim();
  }
}
