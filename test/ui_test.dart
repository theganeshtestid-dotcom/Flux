import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/data.dart';
import 'package:flux/main.dart';
import 'package:flux/reminders.dart';
import 'package:flux/theme.dart';

void main(){
  testWidgets('four navigation tabs, four Quick Add options, and empty-state guidance',(tester)async{
    SharedPreferences.setMockInitialValues({});
    final store=Planner()..prefs=await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(theme:fluxTheme(Brightness.light),home:PlannerHome(store:store,reminders:Reminders())));
    expect(find.byType(NavigationDestination),findsNWidgets(4));
    expect(find.text('Add your first subject'),findsOneWidget);
    await tester.tap(find.byTooltip('Quick Add'));await tester.pumpAndSettle();
    for(final label in ['Subject','Assignment','Study Session','Exam']){expect(find.text(label),findsOneWidget);}
    expect(find.text('Attendance'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('manual study entry rejects zero duration',(tester)async{
    await tester.pumpWidget(MaterialApp(theme:fluxTheme(Brightness.dark),home:RecordForm(store:Planner(),kind:'sessions',permission:false)));
    await tester.enterText(find.byType(TextFormField).at(1),'0');
    await tester.ensureVisible(find.text('Save study session'));
    await tester.tap(find.text('Save study session'));await tester.pumpAndSettle();
    expect(find.text('Enter a whole number of minutes greater than zero.'),findsOneWidget);
  });
  test('approved theme colors remain exact in both modes',(){
    final light=fluxTheme(Brightness.light);final dark=fluxTheme(Brightness.dark);
    expect(light.scaffoldBackgroundColor,const Color(0xFFF4F3EE));
    expect(dark.scaffoldBackgroundColor,const Color(0xFF0F1014));
    expect(light.colorScheme.surface,Colors.white);
    expect(dark.colorScheme.surface,const Color(0xFF191C23));
    expect(light.colorScheme.primary,orange);expect(dark.colorScheme.primary,orange);
  });
}
