import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:simple_permissions/simple_permissions.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: false);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'File Downloader'),
    );
  }
}

bool isDownloading = false;
var d_progress = 0.0;

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  ReceivePort _port = ReceivePort();

  TextEditingController urlController = TextEditingController();

  String taskId;
  List<DownloadTask> tasks;


  @override
  void initState() {
    super.initState();

    bool registered = addMapping();

    if(!registered){
      removeMapping();
      print(addMapping());
    }
    print('Register: $registered');

    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];

      print('Progress: $progress}');
      print('status: ${status.toString()}}');

      setState((){
        if(progress < 100){
          isDownloading = true;
          d_progress = progress.ceilToDouble();
        }
        else{
          isDownloading = false;

          Timer(Duration(milliseconds: 1500), (){
          open();
          });
        }
      });

    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  bool addMapping() {
    bool registered = IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    return registered;
  }

  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port');
    print('Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
    send.send([id, status, progress]);
  }


  @override
  void dispose() {
    removeMapping();
    super.dispose();
  }

  void removeMapping() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

//  Future<bool> checkPermission() async {
//    PermissionStatus permissionResult = await SimplePermissions.requestPermission(Permission. WriteExternalStorage);
//    if (permissionResult == PermissionStatus.authorized){
//      return Future.value(true);
//    }
//    return Future.value(false);
//  }

  void open(){
    FlutterDownloader.open(taskId: taskId);
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        title: Text(widget.title),
      ),
      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300,
              child: TextFormField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'Download URL',
                  helperText: 'https://buildmedia.readthedocs.org/media/pdf/django/3.0.x/django.pdf',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  )
                ),
              ),
            ),
            RaisedButton(
              onPressed: () async{
                await startDownload(context, false);
              },
              child: Text('Download from Url'),
            ),
            RaisedButton(
              onPressed: (){
                startDownload(context, true);
              },
              child: Text('Download django doc'),
            )
          ],
        ),
      ),
    );
  }

  Future startDownload(BuildContext context, isDjangoDoc) async {

//    PermissionStatus permissionResult = await SimplePermissions.requestPermission(Permission. WriteExternalStorage);
//    if (permissionResult == PermissionStatus.authorized){
      var dir = await getExternalStorageDirectory();

      print('_MyHomePageState.build: ${dir.path}');
      taskId = await FlutterDownloader.enqueue(
        url: isDjangoDoc ? 'https://buildmedia.readthedocs.org/media/pdf/django/3.0.x/django.pdf' :urlController.value.text.trim(),
        savedDir: dir.path,
        showNotification: true,
        openFileFromNotification: true,
      );
      isDownloading = true;
      _displayDialog(context);
      tasks = await FlutterDownloader.loadTasks();
//    }

  }


  _displayDialog(BuildContext context) async {
    return showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Download',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              content: Text('Downloading.....')
//              Text(isDownloading ? 'Downloading $d_progress %': 'Opening file...'),
            );
          });
  }
}
