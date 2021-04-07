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

void main() => runApp(MyApp());

List<int> recordedData = [];

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterAudioCapture _plugin = new FlutterAudioCapture();
  String myIp = '';
  int captured = 0;
  int writtenToClient = 0;
  int clientReceived = 0;
  int clientPlayed = 0;
  List<Uint8List> clientData = [];
  var ipEdit = new TextEditingController(text: "192.168.0.102");
  Socket client;
  String message = '';

  @override
  void initState() {
    super.initState();
    /*await*/ platform.invokeMethod('initAudioTrack');
  }

  void _startClient() {
    Socket.connect(ipEdit.text, 4567).then((socket) {
      print('Connected to: '
          '${socket.remoteAddress.address}:${socket.remotePort}');

      //Establish the onData, and onDone callbacks
      socket.listen((Uint8List data) {
        clientReceived++;
        setState(() {});
        print("client recv from socket: len=${data.length} $data");
        clientData.add(data);
        if (clientData.length > 20) {
          // final player = AudioPlayer();
          // //player.setAndroidAudioAttributes(AndroidAudioAttributes())
          // //player.setAudioSource(SrcBlock(clientData));
          // player.play();
          clientData = [];
          clientPlayed++;
          setState(() {});
        }
        // print("client recv from socket: " +
        //     new String.fromCharCodes(data).trim());
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
      myIp = value.address;
      setState(() {});
    });
    ServerSocket.bind(InternetAddress.anyIPv4, 4567, shared: true)
        .then((ServerSocket server) {
      server.listen(handleClient);
    });
  }

  void handleClient(Socket client) {
    print('Connection from '
        '${client.remoteAddress.address}:${client.remotePort}');

    this.client = client;
    _startTestCapture();
    // client.write("Hello from simple server!\n");
    // client.close();
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
    recordedData = [];
    //await _plugin.start(listener, onError, sampleRate: 16000, bufferSize: 30000);
    await _plugin.start((dynamic obj) {
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
    await _plugin.stop();
    if (recordedData.length > 0) {
      print("record  data len=${recordedData.length}");
      await platform.invokeMethod('writeAudioBytes', <String, dynamic>{
        'bytes': from16bitsLittleEndian(recordedData),
      });
    }
  }

  void listener(dynamic obj) {
    captured++;
    setState(() {});

    List<dynamic> list = obj;
    //data.add(list);
    // double sum=0;
    // for(var v in list) sum += v;
    List<int> mul = [];
    for (var v in list) mul.add((v * 256 * 256 as double).floor());
    recordedData.addAll(mul);
    // mul.sort();
    // mul = mul.reversed.toList();
    //print('buf $mul');
    // print('buf ${list.length} $sum');

    if (client != null) {
      //client.write(from16bitsLittleEndian(mul));
      client.add(from16bitsLittleEndian(mul));
      writtenToClient++;
      setState(() {});
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
          title: const Text('Flutter Audio Capture Plugin'),
        ),
        body: Column(children: [
          Text(
              "myIp=$myIp  captured=$captured writtenToClient=$writtenToClient clientReceived=$clientReceived clientPlayed=$clientPlayed"),
          TextFormField(
            controller: ipEdit,
            keyboardType: TextInputType.phone,
          ),
          Text("Message: $message"),
          Expanded(
              child: Row(
            children: [
              Expanded(
                  child: Center(
                      child: FloatingActionButton(
                          onPressed: _startServer, child: Text("StrtSrv")))),
              Expanded(
                  child: Center(
                      child: FloatingActionButton(
                          onPressed: _startClient, child: Text("Conn")))),
              Expanded(
                  child: Center(
                      child: ElevatedButton(
                          onPressed: _startTestCapture,
                          child: Text("Audio test (3 sec)")))),
              // Expanded(
              //     child: Center(
              //         child: FloatingActionButton(
              //             onPressed: _stopCapture, child: Text("Stop")))),
            ],
          ))
        ]),
      ),
    );
  }
}
