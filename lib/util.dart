import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

Uint8List tone(double freq, int millis) {
  int ticks = (8000 * millis / 1000.0).round();
  Uint8List b = Uint8List(ticks * 2);
  var bd = b.buffer.asByteData();
  for (int i = 0; i < ticks; i++) {
    bd.setInt16(
        i * 2,
        (50 + sin(i / 8000.0 * freq * 2 * pi) * 50).floor() * 256,
        Endian.little);
  }
  return b;
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

void startAudioServerForTestRecording(int port, Uint8List recording) async {
  ServerSocket server =
      await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);

  print("wait for client connection to audio server on $port");
  Socket client = await server.single;

  // StreamSubscription<Socket> subscription;
  // subscription = server.listen((Socket client) async {
  print("client connection to audio server on $port");
  // await subscription.cancel();
  serveClient(client, recording).then((value) => server.close());
}

Future<void> serveClient(Socket client, Uint8List recording) async {
  client.write(
      "HTTP/1.1 200 OK\r\nContent-type: audio/wav\r\nContent-Length: 1000000044\r\n\r\n"); // practically unlimited
  client.add(wavFileHeader(1000 * 1000 * 1000)); // practically unlimited

  client.add(tone(1000, 100));
  client.add(tone(500, 100));
  client.add(recording);
  await Future.delayed(Duration(seconds: 100));
  client.add(tone(500, 100));
  client.add(tone(1000, 100));
  await Future.delayed(Duration(seconds: 1500));
  await client.flush();
  await client.close();
}
