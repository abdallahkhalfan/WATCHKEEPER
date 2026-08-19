import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class DB {
 static String get uid=>FirebaseAuth.instance.currentUser!.uid;
  static DocumentReference<Map<String,dynamic>> get me=>FirebaseFirestore.instance.collection('users').doc(uid);
   static CollectionReference<Map<String,dynamic>> get planner=>me.collection('planner');
    static CollectionReference<Map<String,dynamic>> get memories=>me.collection('memories');
     static CollectionReference<Map<String,dynamic>> get keeper=>me.collection('keeper_messages');
      static CollectionReference<Map<String,dynamic>> get conversations=>FirebaseFirestore.instance.collection('conversations');
       static Future<void> ensureProfile() async { final u=FirebaseAuth.instance.currentUser!; await me.set({'uid':u.uid,'name':u.displayName??'WATCHKEEPER user','email':u.email??'','photoUrl':u.photoURL??'','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true)); }
       }
       class Alerts {
        static final i=Alerts._(); Alerts._(); final p=FlutterLocalNotificationsPlugin();
         Future<void> init() async {tz.initializeTimeZones();try{final z=await FlutterTimezone.getLocalTimezone();tz.setLocalLocation(tz.getLocation(z.identifier));}catch(_){} const s=InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher'));await p.initialize(settings:s);await p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();}
          Future<void> test()=>p.show(id:999,title:'WATCHKEEPER ✦',body:'I’m awake. Your reminders are under watch.',notificationDetails:const NotificationDetails(android:AndroidNotificationDetails('watchkeeper','WATCHKEEPER',importance:Importance.max,priority:Priority.high)));
           Future<void> schedule(int id,String title,DateTime when,int before) async {final t=when.subtract(Duration(minutes:before));if(t.isBefore(DateTime.now()))return;await p.zonedSchedule(id:id,title:'WATCHKEEPER',body:title,scheduledDate:tz.TZDateTime.from(t,tz.local),notificationDetails:const NotificationDetails(android:AndroidNotificationDetails('watchkeeper','WATCHKEEPER reminders',importance:Importance.max,priority:Priority.high)),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle);}
           }
           class MediaStore {
            static Future<String> upload(File file,String kind) async {final id=const Uuid().v4();final ext=file.path.split('.').last;final ref=FirebaseStorage.instance.ref('users/${DB.uid}/memories/$id.$ext');await ref.putFile(file);return ref.getDownloadURL();}
            }
            class ShareService { static Future<void> text(String text)=>SharePlus.instance.share(ShareParams(text:text)); static Future<void> file(String path,String caption)=>SharePlus.instance.share(ShareParams(text:caption,files:[XFile(path)])); }
            