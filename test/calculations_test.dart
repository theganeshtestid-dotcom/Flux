import 'package:flutter_test/flutter_test.dart';
import 'package:flux/data.dart';

void main() {
  test('attendance counts only recorded marks and handles no records', () {
    expect(attendanceStats([]).percent, isNull);
    final a = attendanceStats([
      ...List.generate(8, (i) => <String,dynamic>{'status':'Present'}),
      ...List.generate(2, (i) => <String,dynamic>{'status':'Absent'}),
      {'status':null},
    ]);
    expect(a.present,8); expect(a.recorded,10); expect(a.percent,80);
    expect(attendanceStats(List.generate(5,(_)=><String,dynamic>{'status':'Present'})).percent,100);
  });
  test('assignment completion overrides overdue and due time does not change date status', () {
    final today=DateTime(2026,10,28);
    expect(assignmentStatus({'date':'2026-10-27','completed':false},today),'Overdue');
    expect(assignmentStatus({'date':'2026-10-28T08:00:00'},today),'Due Today');
    expect(assignmentStatus({'date':'2026-10-29'},today),'Upcoming');
    expect(assignmentStatus({'date':'2026-10-27','completed':true},today),'Completed');
  });
  test('study totals exclude zero and negative durations', () {
    expect(studyMinutes([{'minutes':45},{'minutes':60},{'minutes':0},{'minutes':-10}]),105);
  });
  test('weeks start Monday and exclude the next Monday', () {
    final week=monday(DateTime(2026,10,28,23));
    expect(week,DateTime(2026,10,26));
    expect(inWeek('2026-10-26T00:00:00',week),isTrue);
    expect(inWeek('2026-11-01T23:59:59',week),isTrue);
    expect(inWeek('2026-11-02T00:00:00',week),isFalse);
  });
  test('exactly five badge thresholds, distinct occurrences and attendance minimum', () {
    expect(badgeNames.length,5);
    expect(earnedBadges([],[],[],[]),isEmpty);
    final records=List.generate(10,(i)=><String,dynamic>{'classId':i,'date':'2026-10-28','status':i<8?'Present':'Absent'});
    expect(earnedBadges([{'id':1}],records,[{'minutes':1}],List.generate(3,(_)=><String,dynamic>{'completed':true})),{0,1,2,3,4});
    expect(earnedBadges([],records.take(9).toList(),[],[]).contains(4),isFalse);
    expect(earnedBadges([],List.generate(5,(_)=>records.first),[],[]).contains(1),isFalse);
    expect(earnedBadges([],List.generate(10,(i)=><String,dynamic>{'classId':i,'date':'2026-10-28','status':i<7?'Present':'Absent'}),[],[]).contains(4),isFalse);
  });
}
