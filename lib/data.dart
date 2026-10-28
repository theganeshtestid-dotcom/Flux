import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

typedef Record = Map<String, dynamic>;
DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime calendarDays(DateTime d, int count) => DateTime(d.year, d.month, d.day + count);
DateTime monday(DateTime d) => calendarDays(d, 1 - d.weekday);
bool inWeek(String stamp, DateTime week) {
  final d = DateTime.parse(stamp);
  return !d.isBefore(week) && d.isBefore(calendarDays(week, 7));
}
String dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';
String durationLabel(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';
String clock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String assignmentStatus(Record r, DateTime now) {
  if (r['completed'] == true) return 'Completed';
  final due = day(DateTime.parse(r['date']));
  final today = day(now);
  return due.isBefore(today) ? 'Overdue' : due == today ? 'Due Today' : 'Upcoming';
}
({int present, int recorded, double? percent}) attendanceStats(Iterable<Record> records) {
  final marked = records.where((r) => r['status'] == 'Present' || r['status'] == 'Absent').toList();
  final present = marked.where((r) => r['status'] == 'Present').length;
  return (present: present, recorded: marked.length, percent: marked.isEmpty ? null : present * 100 / marked.length);
}
int studyMinutes(Iterable<Record> records) => records.fold(0, (sum, r) => sum + ((r['minutes'] as int? ?? 0) > 0 ? r['minutes'] as int : 0));
const badgeNames = ['First Subject', 'Attendance Starter', 'Study Starter', 'Task Completer', 'Consistent Student'];
const badgeCriteria = ['Create your first subject.', 'Mark 5 distinct class occurrences.', 'Record a study session longer than zero minutes.', 'Complete 3 assignments.', 'Reach 75% attendance with at least 10 recorded classes.'];
Set<int> earnedBadges(List<Record> subjects, List<Record> attendance, List<Record> sessions, List<Record> tasks) {
  final a = attendanceStats(attendance);
  return {if (subjects.isNotEmpty) 0, if (attendance.map((r) => '${r['classId']}/${r['date']}').toSet().length >= 5) 1, if (studyMinutes(sessions) > 0) 2, if (tasks.where((r) => r['completed'] == true).length >= 3) 3, if (a.recorded >= 10 && (a.percent ?? 0) >= 75) 4};
}

class Planner extends ChangeNotifier {
  Planner({Database? database}) : _db = database;
  Database? _db;
  late SharedPreferences prefs;
  Map<String, dynamic> _data = empty();
  String? recovery;
  Future<void> _writes = Future.value();
  static Map<String, dynamic> empty() => {'subjects': <Record>[], 'classes': <Record>[], 'attendance': <Record>[], 'tasks': <Record>[], 'exams': <Record>[], 'sessions': <Record>[], 'badges': <int>[], 'nextId': 1};
  List<Record> list(String key) => (_data[key] as List).cast<Record>();
  List<int> get badges => (_data['badges'] as List).cast<int>();
  String get appearance => prefs.getString('appearance') ?? 'system';
  bool get reminders => prefs.getBool('reminders') ?? true;
  List<String> get logs => prefs.getStringList('logs') ?? [];
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    final file = p.join(await getDatabasesPath(), 'flux.db');
    try {
      await _open(file);
    } catch (e) {
      final text = e.toString().toLowerCase();
      if (!(text.contains('corrupt') || text.contains('not a database') || e is FormatException)) rethrow;
      await log('Database recovery: $e');
      await _db?.close();
      _db = null;
      final suffix = '.damaged-${DateTime.now().millisecondsSinceEpoch}';
      for (final ext in ['', '-wal', '-shm']) {
        final old = File('$file$ext');
        if (await old.exists()) await old.rename('$file$suffix$ext');
      }
      _data = empty();
      await _open(file);
      recovery = 'The local database was damaged. Your previous records could not be recovered. A fresh planner is ready; the damaged files have been preserved on this device.';
    }
  }
  Future<void> _open(String path) async {
    _db = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE planner (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)');
    });
    final check = await _db!.rawQuery('PRAGMA quick_check');
    if (check.first.values.first != 'ok') throw const FormatException('Corrupt database integrity');
    final rows = await _db!.query('planner', where: 'id = 1');
    if (rows.isNotEmpty) {
      final decoded = jsonDecode(rows.first['payload'] as String);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid planner document');
      _data = decoded;
      for (final key in ['subjects', 'classes', 'attendance', 'tasks', 'exams', 'sessions']) {
        if (_data[key] is! List || (_data[key] as List).any((r) => r is! Map)) throw const FormatException('Invalid planner records');
      }
      _validate();
    }
  }
  void _validate() {
    if ((_data['badges'] is List && (_data['badges'] as List).toSet().length != (_data['badges'] as List).length) || _data['nextId'] is! int || (_data['nextId'] as int) < 1 || _data['badges'] is! List || (_data['badges'] as List).any((v) => v is! int || v < 0 || v >= 5)) {
      throw const FormatException('Invalid planner metadata');
    }
    for (final key in ['subjects','classes','attendance','tasks','exams','sessions']) {
      for (final r in list(key)) {
        if (r['id'] is! int || r['id'] < 1) throw const FormatException('Invalid record ID');
        for (final field in ['teacher','room','notes','topic','subjectName']) {
          if (r[field] != null && r[field] is! String) throw const FormatException('Invalid text field');
        }
        if (r['subjectId'] != null && r['subjectId'] is! int) throw const FormatException('Invalid subject reference');
        if (r['completedAt'] != null && (r['completedAt'] is! String || DateTime.tryParse(r['completedAt']) == null)) throw const FormatException('Invalid completion date');
        if (key == 'subjects' && (r['name'] is! String || (r['name'] as String).trim().isEmpty)) throw const FormatException('Invalid subject');
        if (key == 'classes' && (r['weekday'] is! int || r['weekday'] < 1 || r['weekday'] > 7 || r['start'] is! int || r['end'] is! int || r['start'] < 0 || r['end'] > 1439 || r['end'] <= r['start'])) throw const FormatException('Invalid class time');
        if (key != 'subjects' && key != 'classes' && (r['date'] is! String || DateTime.tryParse(r['date']) == null)) throw const FormatException('Invalid record date');
        if (key == 'classes' && r['startsOn'] != null && (r['startsOn'] is! String || DateTime.tryParse(r['startsOn']) == null)) throw const FormatException('Invalid class start date');
        if ((key == 'tasks' || key == 'exams') && r['time'] != null && (r['time'] is! int || r['time'] < 0 || r['time'] >= 1440)) throw const FormatException('Invalid deadline time');
        if (key == 'sessions' && (r['minutes'] is! int || r['minutes'] <= 0)) throw const FormatException('Invalid study duration');
        if (key == 'attendance' && (r['classId'] is! int || !['Present','Absent'].contains(r['status']))) throw const FormatException('Invalid attendance mark');
        if ((key == 'tasks' || key == 'exams') && (r['title'] is! String || (r['title'] as String).trim().isEmpty)) throw const FormatException('Invalid title');
        if ((r['id'] as int) >= (_data['nextId'] as int)) throw const FormatException('Invalid record sequence');
      }
    }
  }
  Future<void> log(String error) async {
    try {
      final entries = [...logs, '${DateTime.now().toIso8601String()} · $error'];
      await prefs.setStringList('logs', entries.skip(entries.length > 100 ? entries.length - 100 : 0).toList());
    } catch (_) { /* Logging must never break the planner. */ }
  }
  Future<void> setAppearance(String value) async { await prefs.setString('appearance', value); notifyListeners(); }
  Future<void> setReminders(bool value) async { await prefs.setBool('reminders', value); notifyListeners(); }
  Future<void> clearLogs() async { await prefs.remove('logs'); notifyListeners(); }
  Future<void> _commit(void Function() change) {
    final operation = _writes.then((_) => _apply(change));
    _writes = operation.catchError((Object _) {});
    return operation;
  }
  Future<void> _apply(void Function() change) async {
    final before = jsonEncode(_data);
    try {
      change();
      _validate();
      final earned = {...badges, ...earnedBadges(list('subjects'), list('attendance'), list('sessions'), list('tasks'))};
      _data['badges'] = earned.toList()..sort();
      await _db!.insert('planner', {'id': 1, 'payload': jsonEncode(_data)}, conflictAlgorithm: ConflictAlgorithm.replace);
      notifyListeners();
    } catch (e) {
      _data = (jsonDecode(before) as Map).cast<String, dynamic>();
      await log('Save failed: $e');
      rethrow;
    }
  }
  int _upsert(String key, Record record) {
    final id = record['id'] as int? ?? _data['nextId']++ as int;
    final rows = list(key);
    final index = rows.indexWhere((r) => r['id'] == id);
    final saved = {...record, 'id': id}..remove('_persisted');
    if (index < 0) { rows.add(saved); } else { rows[index] = saved; }
    return id;
  }
  Future<int> save(String key, Record record) async {
    late int id;
    await _commit(() { id = _upsert(key, record); });
    return id;
  }
  Future<void> remove(String key, int id) => _commit(() {
    list(key).removeWhere((r) => r['id'] == id);
    if (key == 'subjects') list('classes').removeWhere((r) => r['subjectId'] == id);
  });
  String subjectName(dynamic id, [String? fallback]) => list('subjects').where((r) => r['id'] == id).firstOrNull?['name'] as String? ?? fallback ?? 'No subject';
  List<Record> todayClasses(DateTime date) => list('classes').where((r) => r['weekday'] == date.weekday && (r['startsOn'] == null || !day(date).isBefore(DateTime.parse(r['startsOn'])))).toList()..sort((a,b) => (a['start'] as int).compareTo(b['start'] as int));
  Record? markFor(int classId, DateTime date) => list('attendance').where((r) => r['classId'] == classId && r['date'] == day(date).toIso8601String()).firstOrNull;
  Future<void> mark(Record cl, DateTime date, String status) => _commit(() {
    if (!['Present','Absent'].contains(status) || day(date).isAfter(day(DateTime.now()))) throw ArgumentError('Attendance can only be marked for today or a past date.');
    if (!todayClasses(date).any((r) => r['id'] == cl['id'])) throw ArgumentError('This class is not scheduled for the selected date.');
    final existing = markFor(cl['id'], date);
    final subject = list('subjects').where((r) => r['id'] == cl['subjectId']).firstOrNull;
    _upsert('attendance', {
      'classId': cl['id'], 'subjectId': cl['subjectId'],
      'subjectName': subjectName(cl['subjectId']), 'teacher': subject?['teacher'] ?? '',
      'room': cl['room'] ?? '', 'start': cl['start'], 'end': cl['end'],
      ...?existing, 'date': day(date).toIso8601String(), 'status': status,
    });
  });
}
