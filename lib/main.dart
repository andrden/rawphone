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

// Create simple PCM WAV:
// ffmpeg -i NicoA1.webm -t 1 -ar 8000 -ac 1 a.wav

String wavData =
    """UklGRsY+AABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAATElTVBoAAABJTkZPSVNGVA4AAABM
YXZmNTguNDUuMTAwAGRhdGGAPgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABAAEA/f/+//r/+P/9/wIADQAHAAoACgD6/wMA
9//3/wIA7v/q/wEA+/8HABsACgAiAAoAFAABABoA3P8AAID/3P9y/80AaBTvF7gW7BC4BOD7ePXa
+h3+7/ir9K/xE/VG+/L4A/a3+xgFSAcwDPQMJQO390D1PfQ39bT2r/5NCP4NwA66EKAQ/gtgBgkA
Q/mG7DvjXuVL6BzpSe7z9WP/VAozEUAbliDbHt8gjRytFtkHZfMC8yb2JfPx8S32C/uZ/n7/WADN
+aX6TwBnAFkBdu/YC50EzvGM/M3zi+Vj9p0KoQMKFwkVkBZjK8IaRxQsDZvyifeh9/Dkau/F+Nr+
rBDhCXcBMQseAtb7yv2T+2jwJuxj8srv4+l+6+fu9PTj9R8FMgED+fAMHw3pEZUcww9sCeL+JwMX
DhoCGwFfE30JrQbbD1sUahJuDVYL3vOO61Pe78zyy+HbCN+H7qj5Dvzn8m//9xHACIcS/x5KILoU
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
1dtu2Q==""";

//List<List<dynamic>> data = [];
List<int> recordedData = [];

class Src extends StreamAudioSource {
  Src(tag) : super(tag);

  @override
  Future<StreamAudioResponse> request([int start, int end]) async {
    var data = base64.decoder
        .convert(wavData.replaceAll('\n', '').replaceAll(' ', ''));

    // For PCM, 16 bit audio data is stored little endian (intel format)
// Create simple PCM WAV:
// ffmpeg -i NicoA1.webm -t 1 -ar 8000 -ac 1 a.wav

    for (int i = 0; i < 8000; i++) {
      data[data.length - 8000 * 2 + i * 2] = 0;
      //data[data.length - 8000 * 2 + i * 2 + 1] = (50 + sin(i) * 50).floor();
      data[data.length - 8000 * 2 + i * 2 + 1] =
          (50 + recordedData[i] / 256).round();
    }

    return StreamAudioResponse(
        sourceLength: data.length,
        contentLength: data.length,
        offset: 0,
        stream: Stream.value(data),
        contentType: "audio/wav");
  }
}

class SrcBlock extends StreamAudioSource {
  List<Uint8List> dataFromSocket;

  SrcBlock(this.dataFromSocket) : super("tag");

  @override
  Future<StreamAudioResponse> request([int start, int end]) async {
    Uint8List data = base64.decoder
        .convert(wavData.replaceAll('\n', '').replaceAll(' ', ''));

    // For PCM, 16 bit audio data is stored little endian (intel format)
// Create simple PCM WAV:
// ffmpeg -i NicoA1.webm -t 1 -ar 8000 -ac 1 a.wav

    int block = 0;
    int blockI = 0;
    for (int i = 0; i < 8000 * 2; i++) {
      var d = dataFromSocket[block];
      data[data.length - 8000 * 2 + i] = d[blockI];
      if (blockI == d.length - 1) {
        // last byte read
        block++;
        blockI = 0;
      } else {
        blockI++;
      }
    }

    print(
        "client play ${data.sublist(data.length - 8000 * 2, data.length - 8000 * 2 + 100)}");

    return StreamAudioResponse(
        sourceLength: data.length,
        contentLength: data.length,
        offset: 0,
        stream: Stream.value(data),
        contentType: "audio/wav");
  }
}

// void pcmData(){
//   Uint8List header = Uint8List(1000);
//   int totalDataLen=500;
//   int channels=1;
//
//   header[0] = 'R'.codeUnitAt(0);  // RIFF/WAVE header
//   header[1] = 'I'.codeUnitAt(0);
//   header[2] = 'F'.codeUnitAt(0);
//   header[3] = 'F'.codeUnitAt(0);
//   header[4] = (totalDataLen & 0xff);
//   header[5] = ((totalDataLen >> 8) & 0xff);
//   header[6] = ((totalDataLen >> 16) & 0xff);
//   header[7] = ((totalDataLen >> 24) & 0xff);
//   header[8] = 'W'.codeUnitAt(0);
//   header[9] = 'A'.codeUnitAt(0);
//   header[10] = 'V'.codeUnitAt(0);
//   header[11] = 'E'.codeUnitAt(0);
//   header[12] = 'f'.codeUnitAt(0);  // 'fmt ' chunk
//   header[13] = 'm'.codeUnitAt(0);
//   header[14] = 't'.codeUnitAt(0);
//   header[15] = ' '.codeUnitAt(0);
//   header[16] = 16;  // 4 bytes: size of 'fmt ' chunk
//   header[17] = 0;
//   header[18] = 0;
//   header[19] = 0;
//   header[20] = 1;  // format = 1
//   header[21] = 0;
//   header[22] = channels;
//   header[23] = 0;
//   header[24] = (byte) (longSampleRate & 0xff);
//   header[25] = (byte) ((longSampleRate >> 8) & 0xff);
//   header[26] = (byte) ((longSampleRate >> 16) & 0xff);
//   header[27] = (byte) ((longSampleRate >> 24) & 0xff);
//   header[28] = (byte) (byteRate & 0xff);
//   header[29] = (byte) ((byteRate >> 8) & 0xff);
//   header[30] = (byte) ((byteRate >> 16) & 0xff);
//   header[31] = (byte) ((byteRate >> 24) & 0xff);
//   header[32] = (byte) (2 * 16 / 8);  // block align
//   header[33] = 0;
//   header[34] = RECORDER_BPP;  // bits per sample
//   header[35] = 0;
//   header[36] = 'd';
//   header[37] = 'a';
//   header[38] = 't';
//   header[39] = 'a';
//   header[40] = (byte) (totalAudioLen & 0xff);
//   header[41] = (byte) ((totalAudioLen >> 8) & 0xff);
//   header[42] = (byte) ((totalAudioLen >> 16) & 0xff);
//   header[43] = (byte) ((totalAudioLen >> 24) & 0xff);
//
//   out.write(header, 0, 44);
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
          player.setAudioSource(SrcBlock(clientData));
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

    final player = AudioPlayer();
    //player.setAndroidAudioAttributes(AndroidAudioAttributes())
    player.setAudioSource(Src("tag"));
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
