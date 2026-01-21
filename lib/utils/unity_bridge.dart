import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

class UnityBridge {
  UnityWidgetController? _unity;

  static final UnityBridge _instance = UnityBridge._internal();
  factory UnityBridge() => _instance;
  UnityBridge._internal();

  // UI callback
  void Function(String instruction, double distance, bool arrived)?
      onNavigationUpdate;

  // =============================
  // UNITY CREATED
  // =============================
  void onUnityCreated(UnityWidgetController controller) {
    _unity = controller;
    print('[UnityBridge] Unity created');
  }

  // =============================
  // FLUTTER → UNITY
  // =============================
  void calibrate(String nodeId) {
    _send({
      'action': 'calibrate',
      'nodeId': nodeId,
    });
  }

  void startNavigation(String start, String dest) {
    _send({
      'action': 'start_navigation',
      'start': start,
      'destination': dest,
    });
  }

  void requestNavigationState() {
    _send({
      'action': 'get_navigation_state',
    });
  }

  // =============================
  // UNITY → FLUTTER
  // =============================
void onUnityMessage(dynamic message) {
  if (message == null) return;

  final raw = message.toString().trim();
  if (raw.isEmpty) return;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(raw);
  } catch (_) {
    return;
  }

  final instruction = data['instruction'] as String? ?? '';
  final distance = (data['distance'] as num?)?.toDouble() ?? -1;
  final arrived = data['arrived'] as bool? ?? false;

  debugPrint(
    '🟢 UnityBridge UPDATE → "$instruction" | $distance | arrived=$arrived',
  );

  // 🔴 ALWAYS notify UI
  onNavigationUpdate?.call(
    instruction,
    distance,
    arrived,
  );
}


  // =============================
  // INTERNAL SEND
  // =============================
  void _send(Map<String, dynamic> data) {
    if (_unity == null) return;

    _unity!.postMessage(
      'UnityMessageManager',
      'OnMessage',
      jsonEncode(data),
    );
  }
}
