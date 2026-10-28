import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/data.dart';
import 'package:flux/reminders.dart';
import 'persistence_test.dart' show RecordingDatabase;

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls=<MethodCall>[];
  setUp((){
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Reminders.channel,(call)async{
      calls.add(call);
      if(call.method=='status'){ return {'permitted':true,'precise':true,'pending':1}; }
      return null;
    });
  });
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Reminders.channel,null));
  test('deadline wall time is passed intact; completed and deleted items disappear',()async{
    SharedPreferences.setMockInitialValues({});
    final s=Planner(database:RecordingDatabase())..prefs=await SharedPreferences.getInstance();
    final id=await s.save('tasks',{'title':'Lab report','date':'2026-10-29T00:00:00','time':840,'reminder':true});
    final r=Reminders();await r.init();await r.sync(s);
    final first=calls.lastWhere((c)=>c.method=='replace').arguments as Map;
    expect((first['plans'] as List).single['minute'],840);
    expect((first['plans'] as List).single['date'],'2026-10-29');
    await s.save('tasks',{...s.list('tasks').single,'completed':true});await r.sync(s);
    expect((calls.lastWhere((c)=>c.method=='replace').arguments as Map)['plans'],isEmpty);
    await s.remove('tasks',id);await r.sync(s);
    expect((calls.lastWhere((c)=>c.method=='replace').arguments as Map)['plans'],isEmpty);
    await s.setReminders(false);await r.sync(s);
    expect((calls.lastWhere((c)=>c.method=='replace').arguments as Map)['enabled'],false);
  });
}
