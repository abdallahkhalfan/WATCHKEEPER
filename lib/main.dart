import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Watchkeeper());
}

class Store extends ChangeNotifier {
  Store._();
  static final Store I = Store._();
  SharedPreferences? p;
  int tab = 0;
  String theme = 'Auto';
  int accent = 0xFF6257E8;
  List<Map<String,dynamic>> tasks = [];
  List<Map<String,dynamic>> events = [];
  List<Map<String,dynamic>> memories = [];
  List<Map<String,dynamic>> activity = [];
  List<Map<String,String>> chat = [
    {'who':'buddy','text':'Hi — I’m WATCHKEEPER Buddy. Try “add task buy milk”, “add event wedding”, or ask “what is today?”'}
  ];

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    theme = p!.getString('theme3') ?? 'Auto';
    accent = p!.getInt('accent3') ?? 0xFF6257E8;
    tasks = _read('tasks3');
    events = _read('events3');
    memories = _read('memories3');
    activity = _read('activity3');
    notifyListeners();
  }
  List<Map<String,dynamic>> _read(String k) {
    try { return List<Map<String,dynamic>>.from(jsonDecode(p!.getString(k) ?? '[]')); } catch (_) { return []; }
  }
  Future<void> save() async {
    await p?.setString('tasks3', jsonEncode(tasks));
    await p?.setString('events3', jsonEncode(events));
    await p?.setString('memories3', jsonEncode(memories));
    await p?.setString('activity3', jsonEncode(activity));
    await p?.setString('theme3', theme);
    await p?.setInt('accent3', accent);
    notifyListeners();
  }
  void go(int i){ tab=i; notifyListeners(); }
  void log(String s){ activity.insert(0, {'text':s,'time':DateTime.now().toIso8601String()}); save(); }
}

class Watchkeeper extends StatefulWidget {
  const Watchkeeper({super.key});
  @override State<Watchkeeper> createState()=>_WatchkeeperState();
}
class _WatchkeeperState extends State<Watchkeeper> {
  bool ready=false;
  @override void initState(){super.initState(); Store.I.load().then((_){if(mounted)setState(()=>ready=true);});}
  @override Widget build(BuildContext context){
    if(!ready) return const MaterialApp(home:Scaffold(body:Center(child:CircularProgressIndicator())));
    return AnimatedBuilder(animation:Store.I,builder:(context,_){
      final s=Store.I, c=Color(s.accent);
      final mode=s.theme=='Dark'||s.theme=='Midnight'?ThemeMode.dark:s.theme=='Light'?ThemeMode.light:ThemeMode.system;
      return MaterialApp(debugShowCheckedModeBanner:false,themeMode:mode,
        theme:ThemeData(useMaterial3:true,colorSchemeSeed:c,brightness:Brightness.light,scaffoldBackgroundColor:const Color(0xfff6f7fb)),
        darkTheme:ThemeData(useMaterial3:true,colorSchemeSeed:c,brightness:Brightness.dark,scaffoldBackgroundColor:const Color(0xff10131a)),
        home:Shell(key:ValueKey('${s.theme}-${s.accent}')));
    });
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override Widget build(BuildContext context){
    final s=Store.I;
    final pages=[const Home(),const Planner(),const Buddy(),const Memories(),const Settings()];
    return Scaffold(
      body:SafeArea(child:pages[s.tab]),
      bottomNavigationBar:NavigationBar(selectedIndex:s.tab,onDestinationSelected:s.go,destinations:const[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Home'),
        NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Planner'),
        NavigationDestination(icon:Icon(Icons.auto_awesome_outlined),selectedIcon:Icon(Icons.auto_awesome),label:'Buddy'),
        NavigationDestination(icon:Icon(Icons.photo_library_outlined),selectedIcon:Icon(Icons.photo_library),label:'Memories'),
        NavigationDestination(icon:Icon(Icons.tune),label:'Style'),
      ]),
      floatingActionButton:s.tab<2?FloatingActionButton.extended(onPressed:()=>showCreate(context),icon:const Icon(Icons.add),label:Text(s.tab==1?'Add':'Quick add')):null,
    );
  }
}

Widget title(String a,String b)=>Padding(padding:const EdgeInsets.fromLTRB(20,18,20,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(a,style:const TextStyle(fontSize:32,fontWeight:FontWeight.w900,letterSpacing:-1)),
  const SizedBox(height:4),Text(b,style:const TextStyle(fontSize:15,color:Colors.grey))
]));

class Home extends StatelessWidget{
  const Home({super.key});
  @override Widget build(BuildContext context){
    final s=Store.I; final pending=s.tasks.where((e)=>e['done']!=true).length;
    return ListView(padding:const EdgeInsets.only(bottom:110),children:[
      title('WATCHKEEPER','Your day. Your things. Your moments.'),
      Padding(padding:const EdgeInsets.all(20),child:Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
        gradient:LinearGradient(colors:[Theme.of(context).colorScheme.primary,Theme.of(context).colorScheme.tertiary]),
        borderRadius:BorderRadius.circular(30)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.shield_moon_rounded,color:Colors.white,size:38),const SizedBox(height:18),
          const Text('Departure Guard',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
          Text('$pending unfinished task${pending==1?'':'s'} before you leave',style:const TextStyle(color:Colors.white70,fontSize:16)),
          const SizedBox(height:18),FilledButton.tonalIcon(onPressed:()=>s.log('Departure Guard checked'),icon:const Icon(Icons.radar),label:const Text('Check my readiness'))
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[
        Expanded(child:_quick(context,Icons.task_alt,'Task','Create anything',()=>showCreate(context,kind:'Task'))),
        const SizedBox(width:12),
        Expanded(child:_quick(context,Icons.event_available,'Event','Plan a moment',()=>showCreate(context,kind:'Event'))),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(20,24,20,10),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Text('Today',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
        TextButton(onPressed:()=>s.go(1),child:const Text('Open planner'))
      ])),
      if(s.tasks.isEmpty&&s.events.isEmpty) const Empty(icon:Icons.add_circle_outline,title:'Nothing is pre-filled',sub:'Add your own tasks and events. WATCHKEEPER starts with your life, not fake activity.'),
      ...s.tasks.take(3).map((e)=>TaskTile(e:e)),
      ...s.events.take(2).map((e)=>EventTile(e:e)),
      Padding(padding:const EdgeInsets.fromLTRB(20,20,20,0),child:Card(child:ListTile(
        leading:const Icon(Icons.auto_awesome),title:const Text('Ask WATCHKEEPER Buddy',style:TextStyle(fontWeight:FontWeight.bold)),
        subtitle:const Text('Create reminders using simple chat commands.'),trailing:const Icon(Icons.chevron_right),onTap:()=>s.go(2)))),
    ]);
  }
  Widget _quick(BuildContext c,IconData i,String a,String b,VoidCallback f)=>InkWell(onTap:f,borderRadius:BorderRadius.circular(24),child:Ink(
    padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Theme.of(c).colorScheme.surface,borderRadius:BorderRadius.circular(24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i,size:30,color:Theme.of(c).colorScheme.primary),const SizedBox(height:25),Text(a,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:Colors.grey))])));
}

class Planner extends StatefulWidget{const Planner({super.key});@override State<Planner> createState()=>_PlannerState();}
class _PlannerState extends State<Planner>{
  int seg=0;
  @override Widget build(BuildContext context){final s=Store.I;
    return Column(children:[title('Planner','Unlimited tasks and real events'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:SegmentedButton<int>(segments:const[
        ButtonSegment(value:0,label:Text('Tasks'),icon:Icon(Icons.check_circle_outline)),
        ButtonSegment(value:1,label:Text('Events'),icon:Icon(Icons.event_outlined)),
      ],selected:{seg},onSelectionChanged:(v)=>setState(()=>seg=v.first))),
      const SizedBox(height:10),
      Expanded(child:seg==0
        ?(s.tasks.isEmpty?const Empty(icon:Icons.task_alt,title:'No tasks yet',sub:'Tap Add and create your first task.'):ListView(children:s.tasks.map((e)=>TaskTile(e:e)).toList()))
        :(s.events.isEmpty?const Empty(icon:Icons.event,title:'No events yet',sub:'Add weddings, work shifts, travel, birthdays or any custom event.'):ListView(children:s.events.map((e)=>EventTile(e:e)).toList())))
    ]);
  }
}

class TaskTile extends StatelessWidget{
  final Map<String,dynamic> e; const TaskTile({super.key,required this.e});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:6),child:Card(child:CheckboxListTile(
    value:e['done']==true,onChanged:(v){e['done']=v;Store.I.log('${e['title']} ${v==true?'completed':'reopened'}');},
    title:Text(e['title']??'',style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text([e['category'],e['when'],e['priority']].where((x)=>x!=null&&x.toString().isNotEmpty).join(' • ')),
    secondary:CircleAvatar(child:Icon(iconFor(e['category']))))));
}
class EventTile extends StatelessWidget{
  final Map<String,dynamic> e; const EventTile({super.key,required this.e});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:6),child:Card(child:ListTile(
    leading:CircleAvatar(child:Icon(iconFor(e['category']))),title:Text(e['title']??'',style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text('${e['date']??''}${(e['time']??'').isEmpty?'':' • ${e['time']}'}\n${e['note']??''}'),isThreeLine:(e['note']??'').isNotEmpty,
    trailing:PopupMenuButton(itemBuilder:(_)=>const[PopupMenuItem(value:'delete',child:Text('Delete'))],onSelected:(v){Store.I.events.remove(e);Store.I.log('${e['title']} deleted');})
  )));
}

IconData iconFor(dynamic c){switch(c){case'Work':return Icons.work_rounded;case'Travel':return Icons.flight_takeoff;case'Prayer':return Icons.self_improvement;case'Shopping':return Icons.shopping_bag;case'Family':return Icons.family_restroom;case'Health':return Icons.favorite;default:return Icons.star_rounded;}}

class Buddy extends StatefulWidget{const Buddy({super.key});@override State<Buddy> createState()=>_BuddyState();}
class _BuddyState extends State<Buddy>{
  final ctl=TextEditingController();
  void send(){
    final t=ctl.text.trim(); if(t.isEmpty)return;
    Store.I.chat.add({'who':'me','text':t}); ctl.clear();
    final low=t.toLowerCase(); String reply;
    if(low.startsWith('add task ')){
      final x=t.substring(9).trim(); Store.I.tasks.insert(0,{'title':x,'category':'Personal','when':'Anytime','priority':'Normal','done':false});
      Store.I.log('$x created from Buddy'); reply='Done. I added “$x” to your tasks.';
    }else if(low.startsWith('add event ')){
      final x=t.substring(10).trim(); Store.I.events.insert(0,{'title':x,'category':'Event','date':'Not set','time':'','note':'Created with Buddy'});
      Store.I.log('$x event created from Buddy'); reply='Added “$x”. Open Planner to set its date and details.';
    }else if(low.contains('what')&&(low.contains('today')||low.contains('task'))){
      final n=Store.I.tasks.where((e)=>e['done']!=true).length; reply='You currently have $n unfinished task${n==1?'':'s'} and ${Store.I.events.length} event${Store.I.events.length==1?'':'s'}.';
    }else{
      reply='I can create things locally. Try “add task carry passport”, “add event baby shower”, or “what are my tasks?”.';
    }
    Store.I.chat.add({'who':'buddy','text':reply}); Store.I.save(); setState((){});
  }
  @override Widget build(BuildContext context)=>Column(children:[
    title('Buddy','A private, offline WATCHKEEPER command chat'),
    Expanded(child:ListView(padding:const EdgeInsets.all(16),children:Store.I.chat.map((m){final me=m['who']=='me';return Align(alignment:me?Alignment.centerRight:Alignment.centerLeft,child:Container(
      constraints:const BoxConstraints(maxWidth:310),margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:me?Theme.of(context).colorScheme.primary:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(20)),
      child:Text(m['text']!,style:TextStyle(color:me?Theme.of(context).colorScheme.onPrimary:null))));}).toList())),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:ctl,onSubmitted:(_)=>send(),decoration:const InputDecoration(hintText:'Tell WATCHKEEPER something…',border:OutlineInputBorder()))),const SizedBox(width:8),IconButton.filled(onPressed:send,icon:const Icon(Icons.send_rounded))])))
  ]);
}

class Memories extends StatelessWidget{
  const Memories({super.key});
  Future<void> capture(BuildContext context,ImageSource src,bool video) async{
    final p=ImagePicker(); final XFile? f=video?await p.pickVideo(source:src,maxDuration:const Duration(minutes:2)):await p.pickImage(source:src,imageQuality:82);
    if(f==null)return;
    Store.I.memories.insert(0,{'path':f.path,'video':video,'caption':video?'Video memory':'Photo memory','time':DateTime.now().toIso8601String()});
    Store.I.log('${video?'Video':'Photo'} memory captured');
  }
  @override Widget build(BuildContext context){final s=Store.I;return Column(children:[
    title('Memories','Capture what you do not want to forget'),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[
      Expanded(child:FilledButton.icon(onPressed:()=>capture(context,ImageSource.camera,false),icon:const Icon(Icons.photo_camera),label:const Text('Photo'))),
      const SizedBox(width:8),Expanded(child:FilledButton.tonalIcon(onPressed:()=>capture(context,ImageSource.camera,true),icon:const Icon(Icons.videocam),label:const Text('Video'))),
      const SizedBox(width:8),IconButton.filledTonal(onPressed:()=>capture(context,ImageSource.gallery,false),icon:const Icon(Icons.photo_library))
    ])),const SizedBox(height:12),
    Expanded(child:s.memories.isEmpty?const Empty(icon:Icons.photo_camera_back_outlined,title:'Your memory wall is empty',sub:'Take a photo, record a short video, or choose a picture from your phone.'):GridView.builder(
      padding:const EdgeInsets.all(16),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:10,mainAxisSpacing:10),itemCount:s.memories.length,itemBuilder:(c,i){
        final m=s.memories[i], video=m['video']==true, path=m['path'] as String;
        return ClipRRect(borderRadius:BorderRadius.circular(22),child:Stack(fit:StackFit.expand,children:[
          if(!video&&File(path).existsSync()) Image.file(File(path),fit:BoxFit.cover) else Container(color:Theme.of(c).colorScheme.surfaceContainerHighest,child:Icon(video?Icons.play_circle:Icons.broken_image,size:50)),
          Align(alignment:Alignment.bottomCenter,child:Container(width:double.infinity,padding:const EdgeInsets.all(10),color:Colors.black54,child:Text(m['caption']??'Memory',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))))
        ]));
      }))
  ]);}
}

class Settings extends StatelessWidget{
  const Settings({super.key});
  static const accents=[0xFF6257E8,0xFF0077B6,0xFF00875A,0xFFE85D04,0xFFD63384,0xFF263238];
  @override Widget build(BuildContext context){final s=Store.I;return ListView(children:[
    title('Style & Settings','Make WATCHKEEPER look like yours'),
    Padding(padding:const EdgeInsets.all(20),child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Theme',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),
      Wrap(spacing:8,children:['Auto','Light','Dark','Midnight'].map((x)=>ChoiceChip(label:Text(x),selected:s.theme==x,onSelected:(_){s.theme=x;s.save();})).toList()),
      const SizedBox(height:22),const Text('Accent colour',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),
      Wrap(spacing:12,children:accents.map((x)=>InkWell(onTap:(){s.accent=x;s.save();},child:Container(width:42,height:42,decoration:BoxDecoration(color:Color(x),shape:BoxShape.circle,border:Border.all(color:s.accent==x?Theme.of(context).colorScheme.onSurface:Colors.transparent,width:3)))).toList())
    ]))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Card(child:Column(children:[
      const ListTile(leading:Icon(Icons.home_work_outlined),title:Text('Home Safe Zone'),subtitle:Text('Departure protection and geofence settings')),
      const Divider(height:1),const ListTile(leading:Icon(Icons.contact_phone_outlined),title:Text('Emergency contact'),subtitle:Text('Escalation contact for Departure Guard')),
      const Divider(height:1),ListTile(leading:const Icon(Icons.history),title:const Text('Real activity'),subtitle:Text('${s.activity.length} actions recorded'))
    ]))),
    Padding(padding:const EdgeInsets.all(20),child:Text('WATCHKEEPER 3.0 • Tasks • Events • Buddy • Memories • Themes',textAlign:TextAlign.center,style:const TextStyle(color:Colors.grey)))
  ]);}
}

class Empty extends StatelessWidget{
  final IconData icon; final String title,sub; const Empty({super.key,required this.icon,required this.title,required this.sub});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(35),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:64,color:Theme.of(context).colorScheme.primary),const SizedBox(height:14),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(sub,textAlign:TextAlign.center,style:const TextStyle(color:Colors.grey,fontSize:15))
  ])));
}

Future<void> showCreate(BuildContext context,{String? kind}) async{
  String type=kind??'Task',category='Personal',priority='Normal'; final name=TextEditingController(),note=TextEditingController();
  DateTime date=DateTime.now(); TimeOfDay time=TimeOfDay.now();
  await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>Padding(
    padding:EdgeInsets.fromLTRB(20,0,20,MediaQuery.of(ctx).viewInsets.bottom+20),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Create $type',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900)),
      const SizedBox(height:14),SegmentedButton<String>(segments:const[ButtonSegment(value:'Task',label:Text('Task')),ButtonSegment(value:'Event',label:Text('Event'))],selected:{type},onSelectionChanged:(v)=>set(()=>type=v.first)),
      const SizedBox(height:14),TextField(controller:name,autofocus:true,decoration:InputDecoration(labelText:type=='Task'?'What do you need to do?':'Event name',border:const OutlineInputBorder())),
      const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),items:['Personal','Work','Travel','Prayer','Shopping','Family','Health','Event'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>set(()=>category=v!)),
      const SizedBox(height:12),if(type=='Task')DropdownButtonFormField<String>(initialValue:priority,decoration:const InputDecoration(labelText:'Priority',border:OutlineInputBorder()),items:['Low','Normal','High','Urgent'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>priority=v!),
      if(type=='Event')...[const SizedBox(height:12),TextField(controller:note,maxLines:2,decoration:const InputDecoration(labelText:'Notes / what to carry',border:OutlineInputBorder()))],
      const SizedBox(height:12),Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)),initialDate:date);if(d!=null)set(()=>date=d);},icon:const Icon(Icons.calendar_today),label:Text('${date.day}/${date.month}/${date.year}'))),
        const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:time);if(t!=null)set(()=>time=t);},icon:const Icon(Icons.schedule),label:Text(time.format(ctx))))
      ]),
      const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){
        final n=name.text.trim();if(n.isEmpty)return;
        if(type=='Task')Store.I.tasks.insert(0,{'title':n,'category':category,'when':'${date.day}/${date.month} • ${time.format(ctx)}','priority':priority,'done':false});
        else Store.I.events.insert(0,{'title':n,'category':category,'date':'${date.day}/${date.month}/${date.year}','time':time.format(ctx),'note':note.text.trim()});
        Store.I.log('$type “$n” created');Navigator.pop(ctx);
      },icon:const Icon(Icons.check),label:Text('Save $type'))),const SizedBox(height:8)
    ]))
  )));
}
