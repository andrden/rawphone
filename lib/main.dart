import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

// flutter build apk --split-per-abi

void main() => runApp(MyApp());

List<int> recordedData = [];
Socket audioPlayerSocket;

Uint8List wavFileHeader(int soundDataLen) {
  // http://soundfile.sapp.org/doc/WaveFormat/
  var ret = Uint8List(4 * 11);
  var bd = ret.buffer.asByteData();
  bd.setUint32(0, 0x52494646, Endian.big); // RIFF
  bd.setUint32(4, 36 + soundDataLen, Endian.little);
  bd.setUint32(8, 0x57415645, Endian.big); // WAVE
  bd.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
  bd.setUint32(16, 16, Endian.little); // 16 bytes len of 'fmt ' subchunk
  bd.setUint32(20, 0x01000100, Endian.big); // PCM = 1 MONO=1 channel
  bd.setUint32(24, 8000, Endian.little); // sample rate
  bd.setUint32(28, 2 * 8000, Endian.little); // byte rate
  bd.setUint32(
      32,
      0x02001000,
      Endian
          .big); // 2=BlockAlign       == NumChannels * BitsPerSample/8;  16 = BitsPerSample
  bd.setUint32(36, 0x64617461, Endian.big); // 'data'
  bd.setUint32(40, soundDataLen, Endian.little);

  return ret;
}

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

  void startAudioServer() async {
    ServerSocket server =
        await ServerSocket.bind(InternetAddress.anyIPv4, 4568, shared: true);

    server.listen((Socket client) async {
      client.write(
          "HTTP/1.1 200 OK\r\nContent-type: audio/wav\r\nContent-Length: 1000000044\r\n\r\n"); // practically unlimited
      client.add(wavFileHeader(1000 * 1000 * 1000)); // practically unlimited
      audioPlayerSocket = client;

      if (recordedData.length > 0) {
        client.add(from16bitsLittleEndian(recordedData));
      }
      int i = 0;
      while (true) {
        await Future.delayed(Duration(microseconds: 1500));

        var list2 = Uint8List(8000 * 2);
        var byteData2 = list2.buffer.asByteData();
        for (int j = 0; j < 8000; j++) {
          int globalIdx = i * 8000 + j;
          byteData2.setInt16(
              j * 2,
              (50 + sin(globalIdx * (1 + globalIdx / 50000)) * 50).floor() *
                  256,
              Endian.little);
        }

        client.add(list2);
        // if(recordedData.length>i){
        //   List<int> rec = recordedData[i];
        //   client.add(from16bitsLittleEndian(rec));
        // }
        i++;
      }
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
    _startCapture();
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

  Future<void> _startCapture() async {
    // print(wavData.substring(0, 300).replaceAll('\n', '').replaceAll(' ', ''));
    // print(base64.decoder
    //     .convert(wavData.replaceAll('\n', '').replaceAll(' ', ''))
    //     .length);

    if (await Permission.microphone.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
      print('mike granted');
    }
    recordedData = [];
    //await _plugin.start(listener, onError, sampleRate: 16000, bufferSize: 30000);
    await _plugin.start(listener, onError, sampleRate: 8000, bufferSize: 30000);
  }

  Future<void> _stopCapture() async {
    // var len = 0;
    // for (var d in data) {
    //   len += d.length;
    // }
    // print("data.len ${data.length} $len");
    await _plugin.stop();
    await startAudioServer();

    final player = AudioPlayer();
    player.setUrl("http://localhost:4568");
    //player.setAndroidAudioAttributes(AndroidAudioAttributes())
    //player.setAudioSource(Src("tag"));
    player.play();
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

  Uint8List from16bitsLittleEndian(List<int> mul) {
    Uint8List r = Uint8List(mul.length * 2);
    ByteData bd = r.buffer.asByteData();
    for (int i = 0; i < mul.length; i++) {
      bd.setInt16(i * 2, mul[i], Endian.little);
    }
    print("from16bitsLittleEndian ${mul.sublist(0, 10)} ${r.sublist(0, 20)}");
    return r;
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
                      child: FloatingActionButton(
                          onPressed: _startCapture, child: Text("Start")))),
              Expanded(
                  child: Center(
                      child: FloatingActionButton(
                          onPressed: _stopCapture, child: Text("Stop")))),
            ],
          ))
        ]),
      ),
    );
  }
}
