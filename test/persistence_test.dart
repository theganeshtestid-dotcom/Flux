import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flux/data.dart';

// A write-failure-capable database boundary. Tests the application's queue and
// rollback, not SQLite's implementation or on-device restart persistence.
class RecordingDatabase implements Database {
  String? payload;
  bool failNext = false;
  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    await Future<void>.delayed(Duration.zero);
    if(failNext){failNext=false;throw StateError('Simulated disk full');}
    payload=values['payload'] as String;
    return 1;
  }
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
  late Planner s;
  late RecordingDatabase db;
  setUp(()async{
    SharedPreferences.setMockInitialValues({});
    db=RecordingDatabase();
    s=Planner(database:db)..prefs=await SharedPreferences.getInstance();
  });
  Future<Record> addClass()async{
    final subject=await s.save('subjects',{'name':'Physics','teacher':'Ms Rao'});
    final today=day(DateTime.now());
    final id=await s.save('classes',{'subjectId':subject,'weekday':today.weekday,'start':540,'end':600,'room':'B2','startsOn':today.toIso8601String()});
    return s.list('classes').firstWhere((r)=>r['id']==id);
  }
  test('rapid Present/Absent taps update one occurrence, not two',()async{
    final cl=await addClass();
    await Future.wait([s.mark(cl,DateTime.now(),'Present'),s.mark(cl,DateTime.now(),'Absent')]);
    expect(s.list('attendance'),hasLength(1));
    expect(attendanceStats(s.list('attendance')).recorded,1);
    expect(s.list('attendance').single['status'],'Absent');
    expect((jsonDecode(db.payload!)['attendance'] as List),hasLength(1));
  });
  test('weekly recurrence begins on its start date; no future attendance',()async{
    final cl=await addClass();final today=day(DateTime.now());
    expect(s.todayClasses(calendarDays(today,-7)),isEmpty);
    expect(s.todayClasses(calendarDays(today,7)),hasLength(1));
    await expectLater(s.mark(cl,calendarDays(today,7),'Present'),throwsArgumentError);
    expect(s.list('attendance'),isEmpty);
  });
  test('deleting a subject preserves historical attendance and teacher labels',()async{
    final cl=await addClass();await s.mark(cl,DateTime.now(),'Present');
    await s.remove('subjects',cl['subjectId']);
    expect(s.list('classes'),isEmpty);expect(s.list('attendance'),hasLength(1));
    expect(s.list('attendance').single['subjectName'],'Physics');
    expect(s.list('attendance').single['teacher'],'Ms Rao');
    expect(s.badges,contains(0));
  });
  test('failed write rolls back data and badges, next operation still works',()async{
    db.failNext=true;
    await expectLater(s.save('subjects',{'name':'Will not save'}),throwsStateError);
    expect(s.list('subjects'),isEmpty);expect(s.badges,isEmpty);
    await s.save('subjects',{'name':'Saved'});
    expect(s.list('subjects').single['name'],'Saved');expect(s.badges,{0}.toList());
  });
  test('recorded attendance snapshot survives later timetable subject edits',()async{
    final cl=await addClass();await s.mark(cl,DateTime.now(),'Present');
    final other=await s.save('subjects',{'name':'Math'});
    await s.save('classes',{...cl,'subjectId':other,'start':700,'end':760});
    await s.mark(s.list('classes').single,DateTime.now(),'Absent');
    expect(s.list('attendance'),hasLength(1));
    expect(s.list('attendance').single['subjectName'],'Physics');
    expect(s.list('attendance').single['start'],540);
  });
}
