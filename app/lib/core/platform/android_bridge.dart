import 'dart:async';

import 'package:flutter/services.dart';

class UsageEventInfo {
  const UsageEventInfo({
    required this.packageName,
    required this.timestamp,
    required this.eventType,
    this.appCategory = 'unknown',
    this.appLabel = '',
    this.contextSource = 'usage_events',
  });

  final String packageName;
  final DateTime timestamp;
  final String eventType;
  final String appCategory;
  final String appLabel;
  final String contextSource;

  factory UsageEventInfo.fromMap(Map<Object?, Object?> map) {
    return UsageEventInfo(
      packageName: map['packageName'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
      eventType: map['eventType'] as String? ?? 'unknown',
      appCategory: map['appCategory'] as String? ?? 'unknown',
      appLabel: map['appLabel'] as String? ?? '',
      contextSource: map['contextSource'] as String? ?? 'usage_events',
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
    required this.overlayEntryMode,
    required this.overlayPetSize,
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
    required this.accessibilityComponentMatch,
    required this.accessibilityEnabledEntryCount,
    required this.accessibilityPackageEntryCount,
    required this.accessibilityStatusProbeAt,
    required this.accessibilityServiceGeneration,
    required this.accessibilityConnectCount,
    required this.accessibilityDisconnectCount,
    required this.accessibilityInterruptCount,
    required this.accessibilityDestroyCount,
    required this.accessibilityEventCount,
    required this.accessibilityAllowedEventCount,
    required this.accessibilityLastEventAt,
    required this.accessibilityLastEventType,
    required this.accessibilityLastEventPackageHash,
    required this.accessibilityLastWindowEventAt,
    required this.accessibilityLastRootAt,
    required this.processStartedAt,
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
  final String overlayEntryMode;
  final String overlayPetSize;
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
  final bool accessibilityComponentMatch;
  final int accessibilityEnabledEntryCount;
  final int accessibilityPackageEntryCount;
  final DateTime? accessibilityStatusProbeAt;
  final int accessibilityServiceGeneration;
  final int accessibilityConnectCount;
  final int accessibilityDisconnectCount;
  final int accessibilityInterruptCount;
  final int accessibilityDestroyCount;
  final int accessibilityEventCount;
  final int accessibilityAllowedEventCount;
  final DateTime? accessibilityLastEventAt;
  final String accessibilityLastEventType;
  final String accessibilityLastEventPackageHash;
  final DateTime? accessibilityLastWindowEventAt;
  final DateTime? accessibilityLastRootAt;
  final DateTime? processStartedAt;
  final bool appVisible;
  final bool screenInteractive;
  final bool deviceLocked;
  final DateTime? lastServiceStart;
  final DateTime? lastServiceStop;
  final String lastServiceReason;

  String get accessibilityHealthState {
    final now = DateTime.now();
    if (accessibilityStatusProbeAt != null &&
        now.difference(accessibilityStatusProbeAt!).abs() >
            const Duration(minutes: 2)) {
      return 'STALE_UI';
    }
    if (!accessibilityComponentMatch && accessibilityPackageEntryCount > 0) {
      return 'COMPONENT_MISMATCH';
    }
    if (!accessibility) return 'SYSTEM_DISABLED';
    if (!accessibilityConnected) {
      final connectedBeforeProcess = accessibilityLastConnectedAt != null &&
          processStartedAt != null &&
          accessibilityLastConnectedAt!.isBefore(processStartedAt!);
      final noDisconnectAfterConnect = accessibilityLastConnectedAt != null &&
          (accessibilityLastDisconnectedAt == null ||
              accessibilityLastDisconnectedAt!
                  .isBefore(accessibilityLastConnectedAt!));
      if (connectedBeforeProcess && noDisconnectAfterConnect) {
        return 'PROCESS_RESTARTED';
      }
      return 'ENABLED_NOT_CONNECTED';
    }
    if (accessibilityEventCount <= 0 || accessibilityLastEventAt == null) {
      return 'CONNECTED_NO_EVENTS';
    }
    if (screenInteractive &&
        !deviceLocked &&
        now.difference(accessibilityLastEventAt!) >
            const Duration(minutes: 45)) {
      return 'EVENT_STREAM_STALLED';
    }
    return 'CONNECTED_EVENTS_OK';
  }

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
      overlayEntryMode: map['overlayEntryMode'] as String? ?? 'bubble',
      overlayPetSize: map['overlayPetSize'] as String? ?? 'medium',
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
      accessibilityComponentMatch: b('accessibilityComponentMatch'),
      accessibilityEnabledEntryCount:
          (map['accessibilityEnabledEntryCount'] as num?)?.toInt() ?? 0,
      accessibilityPackageEntryCount:
          (map['accessibilityPackageEntryCount'] as num?)?.toInt() ?? 0,
      accessibilityStatusProbeAt: date('accessibilityStatusProbeAt'),
      accessibilityServiceGeneration:
          (map['accessibilityServiceGeneration'] as num?)?.toInt() ?? 0,
      accessibilityConnectCount:
          (map['accessibilityConnectCount'] as num?)?.toInt() ?? 0,
      accessibilityDisconnectCount:
          (map['accessibilityDisconnectCount'] as num?)?.toInt() ?? 0,
      accessibilityInterruptCount:
          (map['accessibilityInterruptCount'] as num?)?.toInt() ?? 0,
      accessibilityDestroyCount:
          (map['accessibilityDestroyCount'] as num?)?.toInt() ?? 0,
      accessibilityEventCount:
          (map['accessibilityEventCount'] as num?)?.toInt() ?? 0,
      accessibilityAllowedEventCount:
          (map['accessibilityAllowedEventCount'] as num?)?.toInt() ?? 0,
      accessibilityLastEventAt: date('accessibilityLastEventAt'),
      accessibilityLastEventType:
          map['accessibilityLastEventType'] as String? ?? '',
      accessibilityLastEventPackageHash:
          map['accessibilityLastEventPackageHash'] as String? ?? '',
      accessibilityLastWindowEventAt:
          date('accessibilityLastWindowEventAt'),
      accessibilityLastRootAt: date('accessibilityLastRootAt'),
      processStartedAt: date('processStartedAt'),
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

  Future<void> openCompanionNotificationSettings({
    String soundKey = 'chime',
  }) =>
      _channel.invokeMethod<void>(
        'openCompanionNotificationSettings',
        {'soundKey': soundKey},
      );

  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;

  Future<bool> requestNearbyPermissions() async =>
      await _channel.invokeMethod<bool>('requestNearbyPermissions') ?? false;

  Future<void> openDesktopPetPreview() =>
      _channel.invokeMethod<void>('openDesktopPetPreview');

  Future<void> startOverlay() => _channel.invokeMethod<void>('startOverlay');

  Future<void> stopOverlay() => _channel.invokeMethod<void>('stopOverlay');

  Future<void> setOverlayEntryMode(String mode) =>
      _channel.invokeMethod<void>('setOverlayEntryMode', {'mode': mode});

  Future<void> setPetOverlaySize(String size) =>
      _channel.invokeMethod<void>('setPetOverlaySize', {'size': size});

  Future<void> suspendOverlayForStandby() =>
      _channel.invokeMethod<void>('suspendOverlayForStandby');

  Future<void> reconcileOverlayAfterTakeover() =>
      _channel.invokeMethod<void>('reconcileOverlayAfterTakeover');

  Future<bool> beginSystemPickerOverlayGuard({required String reason}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'beginSystemPickerOverlayGuard',
            {'reason': reason},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> endSystemPickerOverlayGuard({required String reason}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'endSystemPickerOverlayGuard',
            {'reason': reason},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

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

  Future<void> acknowledgeCompanionNotifications({
    String reason = 'full_chat_visible',
  }) =>
      _channel.invokeMethod<void>(
        'acknowledgeCompanionNotifications',
        {'reason': reason},
      );

  Future<void> setPetConversationState({
    required bool generationActive,
    required String generationPhase,
    required String ttsPhase,
  }) =>
      _channel.invokeMethod<void>('setPetConversationState', {
        'generationActive': generationActive,
        'generationPhase': generationPhase,
        'ttsPhase': ttsPhase,
      });

  Future<void> postCompanionNotification({
    required String title,
    required String body,
    required String messageId,
    String intentKind = '',
    String deliveryStyle = 'normal',
    String soundKey = 'chime',
  }) {
    return _channel.invokeMethod<void>('postCompanionNotification', {
      'title': title,
      'body': body,
      'messageId': messageId,
      'intentKind': intentKind,
      'deliveryStyle': deliveryStyle,
      'soundKey': soundKey,
    });
  }

  Future<Map<String, Object?>> testCompanionNotification({
    String soundKey = 'chime',
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'testCompanionNotification',
      {'soundKey': soundKey},
    );
    return _stringKeyMap(raw);
  }

  Future<Map<String, Object?>> scheduleDelayedProactiveTest({
    Duration delay = const Duration(minutes: 5),
    String soundKey = 'chime',
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'scheduleDelayedProactiveTest',
      {
        'delayMs': delay.inMilliseconds,
        'soundKey': soundKey,
      },
    );
    return _stringKeyMap(raw);
  }

  Future<Map<String, Object?>> delayedProactiveTestStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'delayedProactiveTestStatus',
    );
    return _stringKeyMap(raw);
  }

  Future<Map<String, Object?>> cancelDelayedProactiveTest({
    required int expectedDueAt,
    required String reason,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'cancelDelayedProactiveTest',
      {
        'expectedDueAt': expectedDueAt,
        'reason': reason,
      },
    );
    return _stringKeyMap(raw);
  }

  Map<String, Object?> _stringKeyMap(Map<Object?, Object?>? raw) => {
        for (final entry in (raw ?? const <Object?, Object?>{}).entries)
          if (entry.key != null) entry.key.toString(): entry.value,
      };

  Future<String> deviceLabel() async =>
      await _channel.invokeMethod<String>('deviceLabel') ?? 'Android device';

  Future<String> runtimeProcessEpoch() async =>
      await _channel.invokeMethod<String>('runtimeProcessEpoch') ?? '';

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

  Future<bool> savePromptPack({
    required String content,
    required String suggestedName,
  }) async =>
      await _channel.invokeMethod<bool>('savePromptPack', {
        'content': content,
        'suggestedName': suggestedName,
      }) ??
      false;

  Future<String?> openPromptPack() =>
      _channel.invokeMethod<String>('openPromptPack');
}
