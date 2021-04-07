import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rawphone/util.dart';

// flutter build apk --split-per-abi

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(MyApp());
}

const PORT = 4567;

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterAudioCapture _audioCapture = new FlutterAudioCapture();
  String myServerIp = '';
  int captured = 0;
  int writtenToClient = 0;
  int clientReceived = 0;
  int clientPlayed = 0;
  var ipEdit = new TextEditingController(text: "192.168.0.102");
  String message = '';
  Socket clientSocket;

  @override
  void initState() {
    super.initState();
    /*await*/
    platform.invokeMethod('initAudioTrack');
  }

  void _startClient() {
    Socket.connect(ipEdit.text, PORT).then((socket) {
      print('Connected to: '
          '${socket.remoteAddress.address}:${socket.remotePort}');

      //Establish the onData, and onDone callbacks
      socket.listen((Uint8List data) {
        clientReceived++;
        setState(() {});
        print("client recv from socket: len=${data.length} $data");
        platform.invokeMethod('writeAudioBytes', <String, dynamic>{
          'bytes': data,
        });
      }, onDone: () {
        print("Done");
        socket.destroy();
      });

      //Send the request
      //socket.write(indexRequest);
    });
  }

  void _startServer() {
    _retrieveIPAddress().then((value) {
      print("_retrieveIPAddress $value");
      myServerIp = value.address;
      setState(() {});
    });
    ServerSocket.bind(InternetAddress.anyIPv4, PORT, shared: true)
        .then((ServerSocket server) {
      server.listen(handleClient);
    });
  }

  void handleClient(Socket client) async {
    message = 'Connection from '
        '${client.remoteAddress.address}:${client.remotePort}';
    clientSocket = client;
    setState(() {});
    print(message);

    if (await Permission.microphone.request().isGranted) {
      print('mike granted');
    }
    //await _plugin.start(listener, onError, sampleRate: 16000, bufferSize: 30000);
    await _audioCapture.start((dynamic obj) {
      captured++;
      setState(() {});
      List<dynamic> list = obj;
      List<int> mul = [];
      for (var v in list) mul.add((v * 256 * 256 as double).floor());
      client.add(from16bitsLittleEndian(mul));
      writtenToClient++;
      setState(() {});
    }, onError, sampleRate: 8000, bufferSize: 30000);
  }

  Future<InternetAddress> _retrieveIPAddress() async {
    //InternetAddress result;

    int code = Random().nextInt(255);
    var dgSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    dgSocket.readEventsEnabled = true;
    dgSocket.broadcastEnabled = true;
    Future<InternetAddress> ret =
        dgSocket.timeout(Duration(milliseconds: 100), onTimeout: (sink) {
      sink.close();
    }).expand<InternetAddress>((event) {
      if (event == RawSocketEvent.read) {
        Datagram dg = dgSocket.receive();
        if (dg != null && dg.data.length == 1 && dg.data[0] == code) {
          dgSocket.close();
          return [dg.address];
        }
      }
      return [];
    }).firstWhere((InternetAddress a) => a != null);

    dgSocket.send([code], InternetAddress("255.255.255.255"), dgSocket.port);
    return ret;
  }

  static const platform = const MethodChannel('samples.flutter.dev/battery');

  Future<void> _startTestCapture() async {
    if (await Permission.microphone.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
      print('mike granted');
    }
    List<int> recordedData = [];
    //await _plugin.start(listener, onError, sampleRate: 16000, bufferSize: 30000);
    await _audioCapture.start((dynamic obj) {
      captured++;
      setState(() {});
      List<dynamic> list = obj;
      List<int> mul = [];
      for (var v in list) mul.add((v * 256 * 256 as double).floor());
      recordedData.addAll(mul);
    }, onError, sampleRate: 8000, bufferSize: 30000);
    for (int i = 0; i < 3; i++) {
      message = "Microphone test: 3 seconds recording...$i";
      setState(() {});
      await Future.delayed(Duration(seconds: 1));
    }
    message = "";
    setState(() {});
    await _audioCapture.stop();
    if (recordedData.length > 0) {
      print("record  data len=${recordedData.length}");
      await platform.invokeMethod('writeAudioBytes', <String, dynamic>{
        'bytes': from16bitsLittleEndian(recordedData),
      });
    }
  }

  void onError(Object e) {
    print(e);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Direct Phone over Internet'),
        ),
        body: Column(children: [
          Expanded(
              child: Center(
                  child: myServerIp == ''
                      ? ElevatedButton(
                          onPressed: _startServer,
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.power_settings_new,
                                  size: 48,
                                  color: Colors.lightGreenAccent,
                                ),
                                Text(
                                  "START",
                                  textScaleFactor: 4,
                                )
                              ]))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Listening over Internet...",
                              textScaleFactor: 2,
                            ),
                            Text(''),
                            Text(
                              "Now connect the other device to:",
                              textScaleFactor: 1.5,
                            ),
                            Text(
                              myServerIp,
                              textScaleFactor: 4,
                            )
                          ],
                        ))),
          if (clientSocket != null)
            Expanded(
                child: Column(
              children: [
                Text(
                  "Call in progress...",
                  textScaleFactor: 2,
                ),
                IconButton(
                    onPressed: () {
                      clientSocket.close();
                      clientSocket = null;
                      setState(() {});
                      _audioCapture.stop();
                    },
                    icon: Icon(
                      Icons.phone_disabled,
                      color: Colors.red,
                      size: 48,
                    ))
              ],
            )),
          Expanded(
              child: Center(
            child: Text(
              "or",
              textScaleFactor: 2,
            ),
          )),
          Expanded(
              child: Center(
                  child: Column(children: [
            ElevatedButton(
                onPressed: myServerIp == '' ? _startClient : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.power,
                    size: 48,
                    color: Colors.lightGreenAccent,
                  ),
                  Text(
                    "CONNECT",
                    textScaleFactor: 4,
                  )
                ])),
            if (myServerIp == '')
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '',
                    textScaleFactor: 2,
                  ),
                  Text(
                    "Number:  ",
                    textScaleFactor: 2,
                  ),
                  SizedBox(
                      width: 350,
                      child: TextFormField(
                        style: TextStyle(fontSize: 48),
                        controller: ipEdit,
                        keyboardType: TextInputType.phone,
                      ))
                ],
              ),
          ]))),
          Expanded(
              child: Row(
            children: [
              Expanded(
                  child: Center(
                      child: ElevatedButton(
                          onPressed:
                              myServerIp == '' ? _startTestCapture : null,
                          child: Text("Audio test (3 sec)")))),
            ],
          )),
          // myIp=$myIp
          Text(
              "captured=$captured writtenToClient=$writtenToClient clientReceived=$clientReceived clientPlayed=$clientPlayed"),
          Text("Message: $message"),
        ]),
      ),
    );
  }
}
