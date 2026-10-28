import 'package:flutter/services.dart';
import 'data.dart';

/// Android owns persisted alarms so timezone/clock changes and reboot do not
/// require a running Flutter engine. Deadlines remain device-local wall times.
class Reminders {
  static const channel = MethodChannel('flux/reminders');
  bool available = false;
  bool permitted = false;
  bool precise = false;
  int pending = 0;
  String? lastError;
  Future<void> _queue = Future.value();
  Future<void> init() async {
    await channel.invokeMethod<void>('initialize');
    available = true;
    await refresh();
  }
  Future<void> refresh() async {
    final state = await channel.invokeMapMethod<String, dynamic>('status') ?? {};
    lastError = state['lastError'] as String?;
    permitted = state['permitted'] == true;
    precise = state['precise'] == true;
    pending = state['pending'] as int? ?? 0;
  }
  Future<bool> request() async {
    await channel.invokeMethod<bool>('requestPermission');
    await refresh();
    return permitted;
  }
  Future<void> requestPrecision() => channel.invokeMethod<void>('requestPrecision');
  Future<void> sync(Planner store) {
    final result = _queue.then((_) => _sync(store));
    _queue = result.catchError((Object _) {});
    return result;
  }
  Future<void> _sync(Planner store) async {
    if (!available) { return; }
    final plans = <Map<String, dynamic>>[];
    for (final key in ['tasks', 'exams']) {
      for (final r in store.list(key)) {
        if (r['reminder'] != true || r['completed'] == true) { continue; }
        plans.add({'id': r['id'], 'title': r['title'], 'kind': key == 'tasks' ? 'Assignment' : 'Exam', 'date': (r['date'] as String).substring(0, 10), 'minute': r['time'] ?? 540});
      }
    }
    await channel.invokeMethod<void>('replace', {'enabled': store.reminders, 'plans': plans});
    await refresh();
    if (lastError != null) {
      await store.log('Android reminder: $lastError');
      await channel.invokeMethod<void>('ackError');
      lastError = null;
    }
  }
}
