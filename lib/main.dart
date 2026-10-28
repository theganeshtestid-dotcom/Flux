import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'data.dart';
import 'reminders.dart';
import 'theme.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const Bootstrap()); }
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override State<Bootstrap> createState() => _BootstrapState();
}
class _BootstrapState extends State<Bootstrap> {
  Planner? store;
  final reminders = Reminders();
  String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => error = null);
    final s = Planner();
    try {
      await s.init();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        s.log('Framework error: ${details.exceptionAsString()}');
      };
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        s.log('Unexpected error: $error');
        return true;
      };
      try { await reminders.init(); await reminders.sync(s); } catch (e) { await s.log('Reminder initialization: $e'); }
      if (mounted) { setState(() => store = s); }
    } catch (e) { if (mounted) { setState(() => error = 'Could not open your planner. Your files have not been reset. Free device storage and try again.'); } }
  }
  @override Widget build(BuildContext context) {
    if (store == null) { return MaterialApp(theme: fluxTheme(Brightness.light), darkTheme: fluxTheme(Brightness.dark), home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: error == null ? Column(mainAxisSize: MainAxisSize.min, children: [ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/flux-logo.jpg',width:144,height:144,semanticLabel:'FLUX')), const SizedBox(height:24), const CircularProgressIndicator()]) : Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), const SizedBox(height: 20), FilledButton(onPressed: load, child: const Text('Try again'))]))))); }
    return ListenableBuilder(listenable: store!, builder: (_, _) => MaterialApp(debugShowCheckedModeBanner: false, title: 'FLUX', theme: fluxTheme(Brightness.light), darkTheme: fluxTheme(Brightness.dark), themeMode: switch(store!.appearance) {'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system}, home: PlannerHome(store: store!, reminders: reminders)));
  }
}

class PlannerHome extends StatefulWidget {
  final Planner store;
  final Reminders reminders;
  const PlannerHome({super.key, required this.store, required this.reminders});
  @override State<PlannerHome> createState() => _PlannerHomeState();
}
class _PlannerHomeState extends State<PlannerHome> with WidgetsBindingObserver {
  Planner get s => widget.store;
  int tab = 0;
  int academic = 0;
  DateTime selectedDay = day(DateTime.now());
  Timer? dayRefresh;
  DateTime viewedToday = day(DateTime.now());
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    dayRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      final today = day(DateTime.now());
      if (today != viewedToday && mounted) {
        setState(() { viewedToday = today; selectedDay = today; });
        perform(() async { await sync(); });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (s.recovery != null) { info('Your planner has been reset', s.recovery!); s.recovery = null; }
    });
  }
  @override void dispose() { dayRefresh?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) { selectedDay = day(DateTime.now()); perform(() async { await widget.reminders.sync(s); }); } }
  void message(String text) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); } }
  Future<void> perform(Future<void> Function() action) async {
    try { await action(); if (mounted) { setState(() {}); } } catch (e) { await s.log('$e'); message('Could not complete that action. Your saved records are safe. Please try again.'); }
  }
  Future<void> sync() async { try { await widget.reminders.sync(s); } catch (e) { await s.log('Reminder scheduling: $e'); message('Record saved, but its reminder could not be scheduled.'); } }
  Future<void> info(String title, String text) => showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  Future<bool> confirm(String title, String text) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue'))])) ?? false;
  Widget heading(String title, [String? sub]) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w700)), if (sub != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sub))]));
  Widget section(String text) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)));
  Widget box(Widget child) => Card(child: Padding(padding: const EdgeInsets.all(18), child: child));
  Widget empty(String text, String action, VoidCallback tap) => box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text), const SizedBox(height: 14), FilledButton.tonal(onPressed: tap, child: Text(action))]));
  Widget metric(String label, String value, String detail) => Expanded(child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(detail, style: const TextStyle(fontSize: 12))])));
  String percentage(Iterable<Record> rows) { final a = attendanceStats(rows); return a.percent == null ? 'No records yet' : '${a.percent!.toStringAsFixed(1)}%'; }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/flux-logo.jpg', height: 34, width: 38, fit: BoxFit.contain, semanticLabel: 'FLUX infinity logo')), const SizedBox(width: 10), const Text('FLUX', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800))])),
    body: SafeArea(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [switch(tab) {0 => home(), 1 => academics(), 2 => study(), _ => profile()}])))),
    floatingActionButton: tab == 3 ? null : FloatingActionButton(onPressed: quickAdd, tooltip: 'Quick Add', child: const Icon(Icons.add)),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Academics'), NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Study'), NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile')]),
  );
  Widget home() {
    final now = DateTime.now(); final week = monday(now);
    final classes = s.todayClasses(now); final a = attendanceStats(s.list('attendance'));
    final tasks = s.list('tasks').where((r) => r['completed'] != true).toList()..sort((a,b) => (a['date'] as String).compareTo(b['date']));
    final exams = s.list('exams').where((r) => !DateTime.parse(r['date']).isBefore(day(now))).toList()..sort((a,b) => (a['date'] as String).compareTo(b['date']));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Your day, in flow.', dateLabel(now)),
      if (s.list('subjects').isEmpty) empty('Classes, tasks, and study time. All together. Always offline. Start with one subject, then add weekly class times.', 'Add your first subject', () => edit('subjects')),
      section('Today’s classes'),
      if (classes.isEmpty) empty('No classes scheduled for today.', 'Open timetable', () => setState(() {tab=1; academic=1;})),
      ...classes.map((c) => classCard(c, day(now))),
      section('Snapshot'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [metric('Overall attendance', percentage(s.list('attendance')), '${a.present} present / ${a.recorded} recorded'), const SizedBox(width: 8), metric('Study this week', durationLabel(studyMinutes(s.list('sessions').where((r) => inWeek(r['date'],week)))), 'Recorded sessions only')]),
      section('Coming up'),
      if (tasks.isEmpty && exams.isEmpty) const Text('No open assignments or upcoming exams.'),
      ...tasks.take(2).map((r) => itemCard('tasks',r)), ...exams.take(1).map((r) => itemCard('exams',r)),
      TextButton(onPressed: badges, child: Text('Your badges · ${s.badges.length}/5 →')),
    ]);
  }
  Widget classCard(Record c, DateTime date) {
    final mark = s.markFor(c['id'], date);
    final subj = s.list('subjects').where((r) => r['id'] == c['subjectId']).firstOrNull;
    final saved = mark ?? c;
    final future = day(date).isAfter(day(DateTime.now()));
    final teacher = mark?['teacher'] ?? subj?['teacher'] ?? '';
    return box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(mark?['subjectName'] ?? s.subjectName(c['subjectId']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 6),
      Text('${clock(saved['start'])} – ${clock(saved['end'] ?? c['end'])} · ${saved['room'] ?? ''}'),
      if (teacher.toString().isNotEmpty) Text('Teacher: $teacher'),
      const SizedBox(height: 10),
      Text(future ? 'Scheduled · attendance becomes available on this date' : mark == null ? 'Not marked · excluded from attendance totals' : 'Marked ${mark['status']} · tap a choice to correct'),
      Wrap(spacing: 8, children: ['Present','Absent'].map((status) => ChoiceChip(label: Text(status), selected: mark?['status'] == status, onSelected: future ? null : (_) => perform(() async {await s.mark(c,date,status);}))).toList()),
    ]));
  }
  Widget academics() {
    const labels = ['Subjects','Timetable','Attendance','Assignments','Exams'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Academics','Give your week a little structure.'), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(labels.length, (i) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(labels[i]), selected: academic == i, onSelected: (_) => setState(() => academic=i)))))), const SizedBox(height: 14),
      if (academic == 0) ...[FilledButton.tonal(onPressed: () => edit('subjects'), child: const Text('Add subject')), if(s.list('subjects').isEmpty) const Padding(padding: EdgeInsets.all(16),child: Text('No subjects yet. Add your first subject to build a timetable.')), ...s.list('subjects').map((r) => Card(child: ListTile(title: Text(r['name']), subtitle: Text('${r['teacher'] ?? ''} · ${r['room'] ?? ''}'), trailing: const Icon(Icons.chevron_right), onTap: () => subjectDetail(r))))],
      if (academic == 1) ...[ListTile(contentPadding: EdgeInsets.zero,title: Text(dateLabel(selectedDay)), subtitle: const Text('Choose a date to view or mark its classes'), trailing: IconButton(icon: const Icon(Icons.calendar_month),onPressed: () async { final d=await showDatePicker(context: context,initialDate: selectedDay,firstDate: DateTime(2000),lastDate: DateTime(2100)); if(d!=null && mounted){ setState(()=>selectedDay=d); } })), FilledButton.tonal(onPressed: () => editClass(), child: const Text('Add weekly class')), if(s.todayClasses(selectedDay).isEmpty) const Padding(padding: EdgeInsets.all(16),child: Text('No weekly classes for this day.')), ...s.todayClasses(selectedDay).map((c) => Column(children: [classCard(c,selectedDay), Align(alignment: Alignment.centerRight,child: TextButton(onPressed: ()=>editClass(c),child: const Text('Edit weekly class')))]))],
      if (academic == 2) ...[box(Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(percentage(s.list('attendance')),style: const TextStyle(fontSize:32,fontWeight:FontWeight.bold)), const Text('Present ÷ recorded classes. Unmarked classes never count.')])), if(s.list('attendance').isEmpty) empty('No attendance records yet. Choose a class occurrence from the timetable.', 'Open timetable', ()=>setState(()=>academic=1)), ...(s.list('attendance').reversed.map((r) => Card(child: ListTile(title: Text(s.subjectName(r['subjectId'],r['subjectName'])),subtitle: Text('${dateLabel(DateTime.parse(r['date']))} · ${r['status']}'), trailing: const Icon(Icons.edit_outlined),onTap:()=>correctAttendance(r)))))],
      if (academic >= 3) ...[FilledButton.tonal(onPressed:()=>edit(academic==3?'tasks':'exams'),child:Text(academic==3?'Add assignment':'Add exam')), if(s.list(academic==3?'tasks':'exams').isEmpty) Padding(padding: const EdgeInsets.all(16),child: Text(academic==3?'No assignments yet. Add a task and its deadline.':'No exams yet. Add your next exam.')), ...sorted(academic==3?'tasks':'exams').map((r)=>itemCard(academic==3?'tasks':'exams',r))],
    ]);
  }
  List<Record> sorted(String key) => [...s.list(key)]..sort((a,b)=>(a['date'] as String).compareTo(b['date']));
  Future<void> subjectDetail(Record r) async {
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(c)=>SafeArea(child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(r['name'],style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),Text('${r['teacher'] ?? ''} · ${r['room'] ?? ''}'),const SizedBox(height:12),Text('Subject attendance: ${percentage(s.list('attendance').where((a)=>a['subjectId']==r['id']))}'),const SizedBox(height:16),FilledButton.tonal(onPressed:(){Navigator.pop(c);editClass(null,r['id']);},child:const Text('Add weekly class')),TextButton(onPressed:(){Navigator.pop(c);edit('subjects',r);},child:const Text('Edit subject')),TextButton(onPressed:(){Navigator.pop(c);remove('subjects',r);},child:const Text('Delete subject'))])))));
  }
  Widget itemCard(String key, Record r) {
    final status = key=='tasks'?assignmentStatus(r,DateTime.now()):key=='sessions'?durationLabel(r['minutes']):'Exam';
    return Card(child: ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8), title: Text(r[key=='sessions'?'topic':'title']?.toString().isNotEmpty==true?r[key=='sessions'?'topic':'title']:'Study session'),subtitle: Text('${s.subjectName(r['subjectId'],r['subjectName'])}\n${dateLabel(DateTime.parse(r['date']))}${r['time']==null?'':' · ${clock(r['time'])}'} · $status'),isThreeLine:true,trailing:key=='tasks'?Checkbox(value:r['completed']==true,onChanged:(v)=>perform(()async{await s.save(key,{...r,'completed':v,'completedAt':v==true?DateTime.now().toIso8601String():null});await sync();})):const Icon(Icons.chevron_right),onTap:()=>edit(key,r)));
  }
  Future<void> correctAttendance(Record r) async {
    final status = await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:Text('Correct ${dateLabel(DateTime.parse(r['date']))}'),children:['Present','Absent'].map((v)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,v),child:Padding(padding:const EdgeInsets.all(12),child:Text(v)))).toList()));
    if(status!=null) { await perform(()async{await s.save('attendance',{...r,'status':status});}); }
  }
  Widget study() {
    final week=monday(DateTime.now());final sessions=s.list('sessions');final recent=sessions.where((r)=>inWeek(r['date'],week));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading('Make time to learn.','Small sessions. Real progress.'),box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Study this week'),Text(durationLabel(studyMinutes(recent)),style:const TextStyle(fontSize:36,fontWeight:FontWeight.bold)),Text('${recent.length} recorded sessions · ${dateLabel(week)} – ${dateLabel(calendarDays(week,6))}')])),FilledButton(onPressed:()=>edit('sessions'),child:const Text('Log a study session')),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Weekly Recap'),subtitle:const Text('See what you made time for'),trailing:const Icon(Icons.arrow_forward),onTap:()=>recap()),section('Study history'),if(sessions.isEmpty) const Text('No sessions yet. Log time you have already studied.'),...sorted('sessions').reversed.map((r)=>itemCard('sessions',r))]);
  }
  Widget profile() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading('Your space.','No account. Everything stays on this phone.'),section('Appearance'),box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Follow your device or choose a theme.'),const SizedBox(height:12),Wrap(spacing:8,children:['system','light','dark'].map((v)=>ChoiceChip(label:Text('${v[0].toUpperCase()}${v.substring(1)}'),selected:s.appearance==v,onSelected:(_)=>perform(()=>s.setAppearance(v)))).toList())])),section('Reminders'),box(Column(children:[SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Local reminders'),value:s.reminders,onChanged:(v)=>perform(()async{await s.setReminders(v);await sync();})),Text(widget.reminders.permitted?'Notification permission granted. Delivery is best-effort and may be delayed by Android.':'Permission is off. Your planner still works; reminders cannot be delivered.'),if(!widget.reminders.permitted)TextButton(onPressed:enableReminders,child:const Text('Enable notification permission')),const SizedBox(height:8),Text('${widget.reminders.pending} eligible scheduled reminders. Deadlines follow your device timezone.'),if(widget.reminders.permitted&&!widget.reminders.precise)...[const Text('Precise alarm access is off. Android may delay reminders.'),TextButton(onPressed:()=>perform(widget.reminders.requestPrecision),child:const Text('Allow precise reminders'))]])),Card(child:ListTile(title:Text('Your badges · ${s.badges.length}/5'),trailing:const Icon(Icons.chevron_right),onTap:badges)),Card(child:ListTile(title:const Text('Local error log'),subtitle:Text('${s.logs.length} entries · never uploaded'),trailing:const Icon(Icons.chevron_right),onTap:logs)),section('About FLUX'),const Text('Version 1.0.0\nOffline student planner\n\nAll academic records and logs stay on this device. Uninstalling the app or clearing its storage removes your records. Sharing a progress card is always your choice.')]);
  Future<void> enableReminders() async {
    if(!await confirm('Reminders, on your terms','FLUX can remind you 30 minutes before assignments and exams. For items without a time, the deadline is 09:00. Android may delay delivery. Allow notifications in the next prompt; if previously denied, use Android Settings → Apps → FLUX → Notifications.')){ return; }
    await perform(()async{if(!widget.reminders.available){message('Notifications are unavailable on this device.');return;}await widget.reminders.request();await sync();});
  }
  void badges() => Navigator.push(context,MaterialPageRoute<void>(builder:(c)=>Scaffold(appBar:AppBar(title:Text('Your badges · ${s.badges.length}/5')),body:ListView(padding:const EdgeInsets.all(20),children:List.generate(5,(i)=>Card(child:ListTile(leading:Icon(s.badges.contains(i)?Icons.verified:Icons.lock_outline,color:s.badges.contains(i)?orange:null),title:Text(badgeNames[i]),subtitle:Text('${badgeCriteria[i]}\n${s.badges.contains(i)?'Earned · kept permanently':'Not earned yet'}'),isThreeLine:true)))))));
  void logs() => Navigator.push(context,MaterialPageRoute<void>(builder:(c)=>StatefulBuilder(builder:(c,refresh)=>Scaffold(appBar:AppBar(title:const Text('Local error log')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('Only stored on this device. Never uploaded.'),TextButton(onPressed:()async{if(await confirm('Clear error log?','This removes the local log entries. Academic records are unaffected.')){await perform(s.clearLogs);if(c.mounted){ refresh((){}); }}},child:const Text('Clear log')),if(s.logs.isEmpty)const Text('No errors logged.'),...s.logs.reversed.map((l)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:SelectableText(l))))])))));
  Future<void> quickAdd() async {
    final key=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Padding(padding:EdgeInsets.all(16),child:Text('Quick Add',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),for(final item in [('subjects','Subject',Icons.menu_book),('tasks','Assignment',Icons.task_alt),('sessions','Study Session',Icons.timer_outlined),('exams','Exam',Icons.event_outlined)])ListTile(leading:Icon(item.$3),title:Text(item.$2),onTap:()=>Navigator.pop(c,item.$1)),const SizedBox(height:20)]))));
    if(key!=null && mounted){ edit(key); }
  }
  Future<void> remove(String key, Record r) async {
    if(!await confirm('Delete this ${key=='subjects'?'subject and its weekly classes':'record'}?',key=='subjects'?'Historical attendance, assignments, exams, and sessions will be kept with their saved subject labels. This cannot be undone.':'This cannot be undone. Historical attendance is retained when a weekly class is deleted.')){ return; }
    await perform(()async{await s.remove(key,r['id']);await sync();});
  }
  Future<void> edit(String key,[Record? existing]) async {
    final result=await Navigator.push<Record>(context,MaterialPageRoute(builder:(_)=>RecordForm(store:s,kind:key,existing:existing,permission:widget.reminders.permitted)));
    if(result==null){ return; }
    if(result['_delete']==true){await remove(key,existing!);return;}
    await perform(()async{if(result['_persisted']!=true){ await s.save(key,result); }await sync();if(result['reminder']==true&&!widget.reminders.permitted){ message('Saved. Enable notification permission in Profile to receive reminders.'); }});
  }
  Future<void> editClass([Record? existing,int? subject]) async {
    if(s.list('subjects').isEmpty){message('Add a subject before creating a class.');return;}
    final result=await Navigator.push<Record>(context,MaterialPageRoute(builder:(_)=>ClassForm(store:s,existing:existing,subjectId:subject)));
    if(result==null){ return; }
    if(result['_delete']==true){await remove('classes',existing!);return;}
    await perform(()async{if(result['_persisted']!=true){ await s.save('classes',result); }});
  }
  void recap() => Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>RecapScreen(store:s)));
}

class RecordForm extends StatefulWidget {
  final Planner store;
  final String kind;
  final Record? existing;
  final bool permission;
  const RecordForm({super.key,required this.store,required this.kind,this.existing,required this.permission});
  @override State<RecordForm> createState()=>_RecordFormState();
}
class _RecordFormState extends State<RecordForm> {
  final form=GlobalKey<FormState>();
  late TextEditingController title,teacher,room,notes,minutes;
  late DateTime date;
  int? time,subject;
  late bool reminder;
  bool changed=false;
  bool saving=false;
  String? saveError;
  Record get r=>widget.existing??{};
  bool get isSubject=>widget.kind=='subjects';
  bool get isStudy=>widget.kind=='sessions';
  @override void initState(){super.initState();title=TextEditingController(text:r[isSubject?'name':isStudy?'topic':'title']??'');teacher=TextEditingController(text:r['teacher']??'');room=TextEditingController(text:r['room']??'');notes=TextEditingController(text:r['notes']??'');minutes=TextEditingController(text:r['minutes']?.toString()??'');date=r['date']==null?day(DateTime.now()):DateTime.parse(r['date']);time=r['time'];subject=widget.store.list('subjects').any((s)=>s['id']==r['subjectId'])?r['subjectId']:null;reminder=r['reminder']==true;}
  @override void dispose(){for(final c in [title,teacher,room,notes,minutes]){c.dispose();}super.dispose();}
  Future<void> leave([Record? result])async {
    if(result==null&&saving){ return; }
    if(result==null&&changed){final discard=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Discard changes?'),content:const Text('Your unsaved changes will be lost.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Keep editing')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Discard'))]));if(discard!=true){ return; }}
    if(mounted){setState(()=>changed=false);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted){ Navigator.pop(context,result); }});}
  }
  Widget field(TextEditingController c,String label,{bool required=false,int lines=1,TextInputType? type,String? Function(String?)? validate})=>Padding(padding:const EdgeInsets.only(bottom:16),child:TextFormField(controller:c,decoration:InputDecoration(labelText:label),maxLines:lines,keyboardType:type,validator:validate??(required?(v)=>v==null||v.trim().isEmpty?'Enter ${label.toLowerCase()}.':null:null)));
  Future<void> chooseDate()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2000),lastDate:isStudy?day(DateTime.now()):DateTime(2100));if(d!=null){ setState((){date=d;changed=true;}); }}
  Future<void> save() async {
    if(saving || !form.currentState!.validate()){ return; }
    setState((){saving=true;saveError=null;});
    final record = {...r,if(isSubject)'name':title.text.trim(),if(isSubject)'teacher':teacher.text.trim(),'room':room.text.trim(),if(!isSubject)'subjectId':subject,if(!isSubject)'subjectName':widget.store.subjectName(subject,r['subjectName']),if(!isSubject)'date':day(date).toIso8601String(),if(!isSubject&&!isStudy)'title':title.text.trim(),if(isStudy)'topic':title.text.trim(),if(isStudy)'minutes':int.parse(minutes.text.trim()),'notes':notes.text.trim(),if(!isSubject&&!isStudy)'time':time,if(!isSubject&&!isStudy)'reminder':reminder};
    try {
      final id = await widget.store.save(widget.kind, record);
      await leave({...record, 'id':id, '_persisted':true});
    } catch(e) {
      if(mounted){ setState(()=>saveError='Could not save. Your entries are still here. Free storage and try again.'); }
    } finally { if(mounted){ setState(()=>saving=false); } }
  }

  @override Widget build(BuildContext context){final name=isSubject?'subject':isStudy?'study session':widget.kind=='tasks'?'assignment':'exam';return PopScope(canPop:!changed&&!saving,onPopInvokedWithResult:(didPop,result){if(!didPop){ leave(); }},child:Scaffold(appBar:AppBar(leading:IconButton(icon:const Icon(Icons.close),onPressed:()=>leave()),title:Text('${widget.existing==null?'Add':'Edit'} $name')),body:Form(key:form,onChanged:(){if(!changed){ setState(()=>changed=true); }},child:ListView(padding:const EdgeInsets.all(20),children:[field(title,isSubject?'Subject name':isStudy?'Topic (optional)':'Title',required:!isStudy),if(isSubject)...[field(teacher,'Teacher (optional)'),field(room,'Classroom (optional)')],if(!isSubject)...[DropdownButtonFormField<int>(initialValue:subject,isExpanded:true,decoration:const InputDecoration(labelText:'Subject (optional)'),items:[const DropdownMenuItem<int>(value:null,child:Text('No subject')),...widget.store.list('subjects').map((r)=>DropdownMenuItem<int>(value:r['id'],child:Text(r['name'])))],onChanged:(v)=>setState((){subject=v;changed=true;})),const SizedBox(height:16),ListTile(contentPadding:EdgeInsets.zero,title:Text('${isStudy?'Session':widget.kind=='tasks'?'Due':'Exam'} date: ${dateLabel(date)}'),trailing:const Icon(Icons.calendar_month),onTap:chooseDate),if(isStudy)field(minutes,'Duration in minutes',type:TextInputType.number,validate:(v){final n=int.tryParse(v?.trim()??'');return n==null||n<=0?'Enter a whole number of minutes greater than zero.':null;}),if(!isStudy)...[ListTile(contentPadding:EdgeInsets.zero,title:Text('Time: ${time==null?'Not set (09:00 for reminders)':clock(time!)}'),trailing:const Icon(Icons.schedule),onTap:()async{final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:(time??540)~/60,minute:(time??540)%60));if(t!=null){ setState((){time=t.hour*60+t.minute;changed=true;}); }}),if(time!=null)TextButton(onPressed:()=>setState((){time=null;changed=true;}),child:const Text('Remove optional time'))],if(widget.kind=='exams')field(room,'Location (optional)'),field(notes,widget.kind=='tasks'?'Description (optional)':'Notes (optional)',lines:3),if(!isStudy)...[SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Remind me 30 minutes before'),subtitle:Text(widget.permission&&widget.store.reminders?'Best-effort local reminder.':'Reminders unavailable until enabled in Profile. You can still save.'),value:reminder,onChanged:(v)=>setState((){reminder=v;changed=true;}))]],const SizedBox(height:20),if(saveError!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(saveError!)),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save $name')),if(widget.existing!=null)TextButton(onPressed:()=>leave({'_delete':true}),child:Text('Delete $name'))]))));}
}

class ClassForm extends StatefulWidget {
  final Planner store;
  final Record? existing;
  final int? subjectId;
  const ClassForm({super.key,required this.store,this.existing,this.subjectId});
  @override State<ClassForm> createState()=>_ClassFormState();
}
class _ClassFormState extends State<ClassForm> {
  late int subject,weekday,start,end;
  late DateTime startsOn;
  late TextEditingController room;
  String? error;
  bool dirty=false,allowPop=false,saving=false;
  @override void initState(){super.initState();final r=widget.existing??{};startsOn=r['startsOn']==null?day(DateTime.now()):DateTime.parse(r['startsOn']);subject=r['subjectId']??widget.subjectId??widget.store.list('subjects').first['id'];weekday=r['weekday']??DateTime.now().weekday;start=r['start']??540;end=r['end']??600;room=TextEditingController(text:r['room']??widget.store.list('subjects').firstWhere((r)=>r['id']==subject)['room']??'');}
  @override void dispose(){room.dispose();super.dispose();}
  Future<void> finish(Record? result)async{
    if(result==null&&saving){ return; }
    if(result==null&&dirty){final discard=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Discard class changes?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Keep editing')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Discard'))]));if(discard!=true){ return; }}
    if(mounted){setState(()=>allowPop=true);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted){ Navigator.pop(context,result); }});}
  }
  Future<void> save()async{
    if(saving){ return; }
    if(end<=start){setState(()=>error='End time must be later than start time.');return;}
    setState(()=>saving=true);
    final overlap=widget.store.list('classes').any((r)=>r['id']!=widget.existing?['id']&&r['weekday']==weekday&&start<(r['end'] as int)&&end>(r['start'] as int));
    if(overlap){final proceed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Classes overlap'),content:const Text('Another class is scheduled during this time. Edit the times or explicitly keep both classes.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Edit times')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Keep both'))]));if(proceed!=true){if(mounted){ setState(()=>saving=false); }return;}}
    final record = {...?widget.existing,'subjectId':subject,'weekday':weekday,'start':start,'end':end,'room':room.text.trim(),'startsOn':day(startsOn).toIso8601String()};
    try {
      final id = await widget.store.save('classes',record);
      await finish({...record,'id':id,'_persisted':true});
    }catch(e){if(mounted){ setState(()=>error='Could not save. Your entries are still here. Please try again.'); }}
    finally{if(mounted){ setState(()=>saving=false); }}
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:allowPop||(!dirty&&!saving),onPopInvokedWithResult:(didPop,result){if(!didPop){ finish(null); }},child:Scaffold(appBar:AppBar(title:const Text('Weekly class'),leading:IconButton(icon:const Icon(Icons.close),onPressed:()=>finish(null))),body:ListView(padding:const EdgeInsets.all(20),children:[DropdownButtonFormField<int>(initialValue:subject,decoration:const InputDecoration(labelText:'Subject'),items:widget.store.list('subjects').map((r)=>DropdownMenuItem<int>(value:r['id'],child:Text(r['name']))).toList(),onChanged:(v)=>setState((){subject=v!;dirty=true;})),const SizedBox(height:20),DropdownButtonFormField<int>(initialValue:weekday,decoration:const InputDecoration(labelText:'Repeats every'),items:List.generate(7,(i)=>DropdownMenuItem(value:i+1,child:Text(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][i]))),onChanged:(v)=>setState((){weekday=v!;dirty=true;})),ListTile(title:Text('First date: ${dateLabel(startsOn)}'),subtitle:const Text('Repeats weekly from this date. No automatic absences.'),trailing:const Icon(Icons.calendar_month),onTap:()async{final date=await showDatePicker(context:context,initialDate:startsOn,firstDate:DateTime(2000),lastDate:DateTime(2100));if(date!=null&&mounted){ setState((){startsOn=date;dirty=true;}); }}),const SizedBox(height:12),for(final isStart in [true,false])ListTile(title:Text('${isStart?'Start':'End'}: ${clock(isStart?start:end)}'),trailing:const Icon(Icons.schedule),onTap:()async{final value=isStart?start:end;final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:value~/60,minute:value%60));if(t!=null){ setState((){if(isStart){start=t.hour*60+t.minute;}else{end=t.hour*60+t.minute;}dirty=true;error=null;}); }}),TextField(controller:room,onChanged:(_)=>setState(()=>dirty=true),decoration:const InputDecoration(labelText:'Room (optional)')),if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),const SizedBox(height:24),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save weekly class')),if(widget.existing!=null)TextButton(onPressed:()=>finish({'_delete':true}),child:const Text('Delete weekly class'))])));
}

class RecapScreen extends StatefulWidget {
  final Planner store;
  const RecapScreen({super.key,required this.store});
  @override State<RecapScreen> createState()=>_RecapScreenState();
}
class _RecapScreenState extends State<RecapScreen> {
  DateTime week=monday(DateTime.now());
  final card=GlobalKey();
  bool busy=false;
  String? error;
  Future<void> share()async{
    setState((){busy=true;error=null;});
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary=card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image=await boundary.toImage(pixelRatio:2);
      final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
      image.dispose();
      if(bytes==null){ throw StateError('Image unavailable'); }
      final box=card.currentContext!.findRenderObject()! as RenderBox;
      await SharePlus.instance.share(ShareParams(files:[XFile.fromData(bytes.buffer.asUint8List(),mimeType:'image/png',name:'flux-progress.png')],fileNameOverrides:['flux-progress.png'],sharePositionOrigin:box.localToGlobal(Offset.zero)&box.size));
    }catch(e){await widget.store.log('Progress card: $e');if(mounted){ setState(()=>error='Could not generate or share the card. Your records are safe. Please try again.'); }}finally{if(mounted){ setState(()=>busy=false); }}
  }
  @override Widget build(BuildContext context){final s=widget.store;final attendance=s.list('attendance').where((r)=>inWeek(r['date'],week));final a=attendanceStats(attendance);final sessions=s.list('sessions').where((r)=>inWeek(r['date'],week));final done=s.list('tasks').where((r)=>r['completed']==true&&r['completedAt']!=null&&inWeek(r['completedAt'],week));final exams=s.list('exams').where((r)=>inWeek(r['date'],week));final period='${dateLabel(week)} – ${dateLabel(calendarDays(week,6))}';return Scaffold(appBar:AppBar(title:const Text('Weekly Recap')),body:ListView(padding:const EdgeInsets.all(20),children:[Row(children:[IconButton(tooltip:'Previous week',onPressed:()=>setState(()=>week=calendarDays(week,-7)),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(period,textAlign:TextAlign.center)),IconButton(tooltip:'Next week',onPressed:week.isBefore(monday(DateTime.now()))?()=>setState(()=>week=calendarDays(week,7)):null,icon:const Icon(Icons.chevron_right))]),const SizedBox(height:16),RepaintBoundary(key:card,child:ColoredBox(color:Theme.of(context).scaffoldBackgroundColor,child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Image.asset('assets/flux-logo.jpg',width:42,height:42),const SizedBox(width:12),const Text('FLUX',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:3))]),const SizedBox(height:24),const Text('A week of\nshowing up.',style:TextStyle(fontFamily:'serif',fontSize:32,fontWeight:FontWeight.bold)),const SizedBox(height:12),Text(period),Text(week==monday(DateTime.now())?'Week so far':'Completed week'),const Divider(height:36),Text(durationLabel(studyMinutes(sessions)),style:const TextStyle(fontSize:32,fontWeight:FontWeight.bold)),Text(sessions.isEmpty?'No study sessions recorded this week.':'Study time · ${sessions.length} sessions'),const SizedBox(height:24),Text(a.percent==null?'No attendance records': '${a.percent!.toStringAsFixed(1)}% attendance',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text('${a.present} present / ${a.recorded} recorded this week'),const SizedBox(height:24),Text('${s.badges.length}/5 lifetime badges earned',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:24),Container(height:5,decoration:BoxDecoration(color:orange,borderRadius:BorderRadius.circular(8)))]))))),const SizedBox(height:20),Text(done.isEmpty?'No assignments completed this week.':'${done.length} assignments completed this week.'),const SizedBox(height:12),Text(exams.isEmpty?'No exams scheduled this week.':'${exams.length} exams scheduled this week.'),...exams.map((r)=>ListTile(title:Text(r['title']),subtitle:Text(dateLabel(DateTime.parse(r['date']))))),const SizedBox(height:20),const Text('Card preview · No notes or personal details included. Generated on this device. Sharing opens Android’s share sheet.'),const SizedBox(height:16),if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),FilledButton.icon(onPressed:busy?null:share,icon:const Icon(Icons.share_outlined),label:Text(busy?'Preparing image…':'Share progress card'))]));}
}
