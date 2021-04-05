import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rawphone/util.dart';

// flutter build apk --split-per-abi

void main() => runApp(MyApp());

List<int> recordedData = [];
//Socket audioPlayerSocket;
const AUDIO_SRV_PORT = 4566;

Stream<Uint8List> timedCounter(Duration interval, [int maxCount]) async* {
  yield wavFileHeader(1000 * 1000 * 1000);

  int i = 0;
  while (true) {
    await Future.delayed(interval);

    var list2 = Uint8List(8000 * 2);
    var byteData2 = list2.buffer.asByteData();
    for (int j = 0; j < 8000; j++) {
      byteData2.setInt16(j * 2,
          (50 + sin(j * (1 + i * 0.1)) * 50).floor() * 256, Endian.little);
    }

    yield list2;
    if (i == maxCount) break;
  }
}

class Src extends StreamAudioSource {
  Src(tag) : super(tag);

  @override
  Future<StreamAudioResponse> request([int start, int end]) async {
    // var data = base64.decoder
    //     .convert(wavData.replaceAll('\n', '').replaceAll(' ', ''));

    // For PCM, 16 bit audio data is stored little endian (intel format)
// Create simple PCM WAV:
// ffmpeg -i NicoA1.webm -t 1 -ar 8000 -ac 1 a.wav

    // var byteData = data.buffer.asByteData();
    // for (int i = 0; i < 8000; i++) {
    //   byteData.setInt16(
    //       data.length - 8000 * 2 + i * 2, recordedData[i], Endian.little);
    //   // data[data.length - 8000 * 2 + i * 2] = 0;
    //   // //data[data.length - 8000 * 2 + i * 2 + 1] = (50 + sin(i) * 50).floor();
    //   // data[data.length - 8000 * 2 + i * 2 + 1] =
    //   //     (50 + recordedData[i] / 256).round();
    // }
    //
    // var b = BytesBuilder();
    // var list2 = Uint8List(8000 * 2);
    // var byteData2 = list2.buffer.asByteData();
    // for (int i = 0; i < 8000; i++) {
    //   byteData2.setInt16(
    //       i * 2, (50 + sin(i*1.1) * 50).floor() * 256, Endian.little);
    //   // data.add(0);
    //   // data.add((50 + sin(i) * 50).floor());
    // }
    // //b.add(wavFileHeader(100*8000 * 2));
    // b.add(wavFileHeader(1000*1000*1000));
    // //b.add(data);
    // b.add(list2);

//    Uint8List allBytes = b.toBytes();
    var res = StreamAudioResponse(
        sourceLength: 1000 * 1000 * 1000,
        //allBytes.length,
        contentLength: 1000 * 1000 * 1000,
        //allBytes.length,
        offset: 0,
        //stream: Stream.value(data),
        //stream: Stream.value(allBytes),
        stream: timedCounter(Duration(microseconds: 500)),
        contentType: "audio/wav");
    return res;
  }
}

// class SrcBlock extends StreamAudioSource {
//   List<Uint8List> dataFromSocket;
//
//   SrcBlock(this.dataFromSocket) : super("tag");
//
//   @override
//   Future<StreamAudioResponse> request([int start, int end]) async {
//     // Uint8List data = base64.decoder
//     //     .convert(wavData.replaceAll('\n', '').replaceAll(' ', ''));
//
//     // For PCM, 16 bit audio data is stored little endian (intel format)
// // Create simple PCM WAV:
// // ffmpeg -i NicoA1.webm -t 1 -ar 8000 -ac 1 a.wav
//
//     int block = 0;
//     int blockI = 0;
//     for (int i = 0; i < 8000 * 2; i++) {
//       var d = dataFromSocket[block];
//       data[data.length - 8000 * 2 + i] = d[blockI];
//       if (blockI == d.length - 1) {
//         // last byte read
//         block++;
//         blockI = 0;
//       } else {
//         blockI++;
//       }
//     }
//
//     print(
//         "client play ${data.sublist(
//             data.length - 8000 * 2, data.length - 8000 * 2 + 100)}");
//
//     return StreamAudioResponse(
//         sourceLength: data.length,
//         contentLength: data.length,
//         offset: 0,
//         stream: Stream.value(data),
//         contentType: "audio/wav");
//   }
// }

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

  // @override
  // void initState() {
  //   super.initState();
  // }

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
          final player = AudioPlayer();
          //player.setAndroidAudioAttributes(AndroidAudioAttributes())
          //player.setAudioSource(SrcBlock(clientData));
          player.play();
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
      await startAudioServerForTestRecording(
          AUDIO_SRV_PORT, from16bitsLittleEndian(recordedData));
      final player = AudioPlayer();
      player.setUrl("http://localhost:$AUDIO_SRV_PORT");
      player.play();
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
