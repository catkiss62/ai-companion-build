import 'dart:async';

import 'package:flutter/services.dart';

class UsageEventInfo {
  const UsageEventInfo({
    required this.packageName,
    required this.timestamp,
    required this.eventType,
    this.appCategory = 'unknown',
  });

  final String packageName;
  final DateTime timestamp;
  final String eventType;
  final String appCategory;

  factory UsageEventInfo.fromMap(Map<Object?, Object?> map) {
    return UsageEventInfo(
      packageName: map['packageName'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
      eventType: map['eventType'] as String? ?? 'unknown',
      appCategory: map['appCategory'] as String? ?? 'unknown',
    );
  }
}


class DevicePerceptionState {
  const DevicePerceptionState({
    required this.usageAccess,
    required this.screenInteractive,
    required this.deviceLocked,
    required this.notificationListenerConnected,
    required this.accessibilityConnected,
  });

  final bool usageAccess;
  final bool screenInteractive;
  final bool deviceLocked;
  final bool notificationListenerConnected;
  final bool accessibilityConnected;

  factory DevicePerceptionState.fromMap(Map<Object?, Object?> map) {
    bool b(String key) => map[key] == true;
    return DevicePerceptionState(
      usageAccess: b('usageAccess'),
      screenInteractive: b('screenInteractive'),
      deviceLocked: b('deviceLocked'),
      notificationListenerConnected: b('notificationListenerConnected'),
      accessibilityConnected: b('accessibilityConnected'),
    );
  }
}

class CapabilityStatus {
  const CapabilityStatus({
    required this.overlay,
    required this.usage,
    required this.accessibility,
    required this.notificationListener,
    required this.postNotifications,
    required this.overlayRunning,
    required this.backgroundBrainReady,
    required this.overlayUserEnabled,
    required this.overlayVisible,
    required this.overlayChatExpanded,
    required this.overlayBubbleAttached,
    required this.overlayBubbleTouchable,
    required this.overlayPositionSafe,
    required this.overlayChatWindowAttached,
    required this.overlayLastTouchAt,
    required this.overlayLastTouchAction,
    required this.overlaySelfHealCount,
    required this.notificationListenerConnected,
    required this.accessibilityConnected,
    required this.accessibilityLastConnectedAt,
    required this.accessibilityLastDisconnectedAt,
    required this.accessibilityLastInterruptAt,
    required this.accessibilityLastReason,
    required this.appVisible,
    required this.screenInteractive,
    required this.deviceLocked,
    required this.lastServiceStart,
    required this.lastServiceStop,
    required this.lastServiceReason,
  });

  final bool overlay;
  final bool usage;
  final bool accessibility;
  final bool notificationListener;
  final bool postNotifications;
  final bool overlayRunning;
  final bool backgroundBrainReady;
  final bool overlayUserEnabled;
  final bool overlayVisible;
  final bool overlayChatExpanded;
  final bool overlayBubbleAttached;
  final bool overlayBubbleTouchable;
  final bool overlayPositionSafe;
  final bool overlayChatWindowAttached;
  final DateTime? overlayLastTouchAt;
  final String overlayLastTouchAction;
  final int overlaySelfHealCount;
  final bool notificationListenerConnected;
  final bool accessibilityConnected;
  final DateTime? accessibilityLastConnectedAt;
  final DateTime? accessibilityLastDisconnectedAt;
  final DateTime? accessibilityLastInterruptAt;
  final String accessibilityLastReason;
  final bool appVisible;
  final bool screenInteractive;
  final bool deviceLocked;
  final DateTime? lastServiceStart;
  final DateTime? lastServiceStop;
  final String lastServiceReason;

  factory CapabilityStatus.fromMap(Map<Object?, Object?> map) {
    bool b(String key) => map[key] == true;
    DateTime? date(String key) {
      final value = (map[key] as num?)?.toInt() ?? 0;
      return value <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(value);
    }
    return CapabilityStatus(
      overlay: b('overlay'),
      usage: b('usage'),
      accessibility: b('accessibility'),
      notificationListener: b('notificationListener'),
      postNotifications: b('postNotifications'),
      overlayRunning: b('overlayRunning'),
      backgroundBrainReady: b('backgroundBrainReady'),
      overlayUserEnabled: b('overlayUserEnabled'),
      overlayVisible: b('overlayVisible'),
      overlayChatExpanded: b('overlayChatExpanded'),
      overlayBubbleAttached: b('overlayBubbleAttached'),
      overlayBubbleTouchable: b('overlayBubbleTouchable'),
      overlayPositionSafe: b('overlayPositionSafe'),
      overlayChatWindowAttached: b('overlayChatWindowAttached'),
      overlayLastTouchAt: date('overlayLastTouchAt'),
      overlayLastTouchAction: map['overlayLastTouchAction'] as String? ?? '',
      overlaySelfHealCount: (map['overlaySelfHealCount'] as num?)?.toInt() ?? 0,
      notificationListenerConnected: b('notificationListenerConnected'),
      accessibilityConnected: b('accessibilityConnected'),
      accessibilityLastConnectedAt: date('accessibilityLastConnectedAt'),
      accessibilityLastDisconnectedAt:
          date('accessibilityLastDisconnectedAt'),
      accessibilityLastInterruptAt: date('accessibilityLastInterruptAt'),
      accessibilityLastReason:
          map['accessibilityLastReason'] as String? ?? '',
      appVisible: b('appVisible'),
      screenInteractive: b('screenInteractive'),
      deviceLocked: b('deviceLocked'),
      lastServiceStart: date('lastServiceStart'),
      lastServiceStop: date('lastServiceStop'),
      lastServiceReason: map['lastServiceReason'] as String? ?? '',
    );
  }
}

class NearbyEvent {
  const NearbyEvent(this.type, this.data);
  final String type;
  final Map<Object?, Object?> data;

  factory NearbyEvent.fromDynamic(dynamic value) {
    final map = Map<Object?, Object?>.from(value as Map);
    return NearbyEvent(map['type'] as String? ?? 'unknown', map);
  }
}

class AndroidBridge {
  AndroidBridge._();
  static final AndroidBridge instance = AndroidBridge._();

  static const MethodChannel _channel = MethodChannel('ai_companion/system');
  static const EventChannel _nearbyChannel = EventChannel('ai_companion/nearby_events');

  String get packageNameHint => 'com.aicompanion.localfirst';

  Stream<NearbyEvent>? _nearbyEvents;
  Stream<NearbyEvent> get nearbyEvents => _nearbyEvents ??= _nearbyChannel
      .receiveBroadcastStream()
      .map(NearbyEvent.fromDynamic)
      .asBroadcastStream();

  Future<CapabilityStatus> capabilityStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('capabilityStatus');
    return CapabilityStatus.fromMap(raw ?? const {});
  }

  Future<Map<String, Object?>> preflightStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('preflightStatus');
    return Map<String, Object?>.from(raw ?? const {});
  }

  Future<List<Map<String, Object?>>> runtimeDiagnostics({int limit = 120}) async {
    final raw = await _channel.invokeListMethod<Object?>('runtimeDiagnostics', {'limit': limit});
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();
  }

  Future<void> clearRuntimeDiagnostics() =>
      _channel.invokeMethod<void>('clearRuntimeDiagnostics');

  Future<void> openOverlaySettings() =>
      _channel.invokeMethod<void>('openOverlaySettings');

  Future<void> openUsageSettings() =>
      _channel.invokeMethod<void>('openUsageSettings');

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  Future<void> openNotificationListenerSettings() =>
      _channel.invokeMethod<void>('openNotificationListenerSettings');

  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;

  Future<bool> requestNearbyPermissions() async =>
      await _channel.invokeMethod<bool>('requestNearbyPermissions') ?? false;

  Future<void> startOverlay() => _channel.invokeMethod<void>('startOverlay');

  Future<void> stopOverlay() => _channel.invokeMethod<void>('stopOverlay');

  Future<void> suspendOverlayForStandby() =>
      _channel.invokeMethod<void>('suspendOverlayForStandby');

  Future<void> reconcileOverlayAfterTakeover() =>
      _channel.invokeMethod<void>('reconcileOverlayAfterTakeover');

  Future<bool> wakeBackgroundBrain({String reason = 'full_app_wake'}) async =>
      await _channel.invokeMethod<bool>(
        'wakeBackgroundBrain',
        {'reason': reason},
      ) ??
      false;

  Future<void> setOverlayUnread(int count) =>
      _channel.invokeMethod<void>('setOverlayUnread', {'count': count});

  Future<void> incrementOverlayUnread() =>
      _channel.invokeMethod<void>('incrementOverlayUnread');

  Future<void> clearOverlayUnread() =>
      _channel.invokeMethod<void>('clearOverlayUnread');

  Future<void> postCompanionNotification({
    required String title,
    required String body,
    required String messageId,
    String intentKind = '',
    String deliveryStyle = 'normal',
  }) {
    return _channel.invokeMethod<void>('postCompanionNotification', {
      'title': title,
      'body': body,
      'messageId': messageId,
      'intentKind': intentKind,
      'deliveryStyle': deliveryStyle,
    });
  }

  Future<String> deviceLabel() async =>
      await _channel.invokeMethod<String>('deviceLabel') ?? 'Android device';

  Future<DevicePerceptionState> getPerceptionState() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('getPerceptionState');
    return DevicePerceptionState.fromMap(raw ?? const {});
  }

  Future<List<UsageEventInfo>> getRecentUsage({int minutes = 60}) async {
    final raw = await _channel.invokeListMethod<Object?>('getRecentUsage', {
      'minutes': minutes,
    });
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((e) => UsageEventInfo.fromMap(Map<Object?, Object?>.from(e)))
        .where((e) => e.packageName.isNotEmpty)
        .toList();
  }

  Future<void> startNearbyReceive() =>
      _channel.invokeMethod<void>('startNearbyReceive');

  Future<void> startNearbyDiscovery() =>
      _channel.invokeMethod<void>('startNearbyDiscovery');

  Future<void> stopNearby() => _channel.invokeMethod<void>('stopNearby');

  Future<void> connectNearby(String endpointId) =>
      _channel.invokeMethod<void>('connectNearby', {'endpointId': endpointId});

  Future<void> acceptNearbyConnection(String endpointId) =>
      _channel.invokeMethod<void>('acceptNearbyConnection', {'endpointId': endpointId});

  Future<void> rejectNearbyConnection(String endpointId) =>
      _channel.invokeMethod<void>('rejectNearbyConnection', {'endpointId': endpointId});

  Future<void> confirmNearbyTakeover({
    required String endpointId,
    required String snapshotId,
    required String lineageId,
    required String sourceDeviceId,
    required int sourceGeneration,
    required String stateSha256,
    required String targetDeviceId,
    required int targetActivationGeneration,
  }) =>
      _channel.invokeMethod<void>('confirmNearbyTakeover', {
        'endpointId': endpointId,
        'snapshotId': snapshotId,
        'lineageId': lineageId,
        'sourceDeviceId': sourceDeviceId,
        'sourceGeneration': sourceGeneration,
        'stateSha256': stateSha256,
        'targetDeviceId': targetDeviceId,
        'targetActivationGeneration': targetActivationGeneration,
      });

  Future<void> sendNearbyFile({
    required String endpointId,
    required String filePath,
    required String snapshotId,
    required String lineageId,
    required String sourceDeviceId,
    required int sourceGeneration,
    required String stateSha256,
  }) {
    return _channel.invokeMethod<void>('sendNearbyFile', {
      'endpointId': endpointId,
      'filePath': filePath,
      'snapshotId': snapshotId,
      'lineageId': lineageId,
      'sourceDeviceId': sourceDeviceId,
      'sourceGeneration': sourceGeneration,
      'stateSha256': stateSha256,
    });
  }

  Future<bool> saveManualSnapshot({
    required String sourcePath,
    required String passphrase,
    required String suggestedName,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('saveManualSnapshot', {
      'sourcePath': sourcePath,
      'passphrase': passphrase,
      'suggestedName': suggestedName,
    });
    return raw?['saved'] == true;
  }

  Future<String?> openManualSnapshot({required String passphrase}) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('openManualSnapshot', {
      'passphrase': passphrase,
    });
    return raw?['filePath'] as String?;
  }

  Future<bool> saveDiagnosticReport({
    required String sourcePath,
    required String suggestedName,
  }) async =>
      await _channel.invokeMethod<bool>('saveDiagnosticReport', {
        'sourcePath': sourcePath,
        'suggestedName': suggestedName,
      }) ??
      false;
}
