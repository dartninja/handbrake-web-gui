import 'dart:io';
import 'dart:isolate';
import 'dart:convert';


import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as io;
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:stream_channel/stream_channel.dart";
import "package:web_socket_channel/io.dart";
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:transcode_server/server.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;


main(List<String> args) async {
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });


  var parser = new ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('input-dir', abbr: 'i')
    ..addOption('complete-dir', abbr: 'c')
    ..addOption('output-dir', abbr: 'o')
    ..addOption('ffprobe', defaultsTo: 'ffprobe')
    ..addOption('handbrake-cli', defaultsTo: 'handbrake-cli');

  var result = parser.parse(args);

  var port = int.tryParse(result['port']);

  if (port == null) {
    stdout.writeln(
        'Could not parse port value "${result['port']}" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }


  String inputDir = result["input-dir"];
  if((inputDir??"").isEmpty) {
    stdout.writeln('input-dir is required');
    exitCode = 64;
    return;
  }

  String completeDir = result["complete-dir"];
  if((completeDir??"").isEmpty) {
    stdout.writeln('complete-dir is required');
    exitCode = 64;
    return;
  }

  String outputDir = result["output-dir"];
  if((outputDir??"").isEmpty) {
    stdout.writeln('output-dir is required');
    exitCode = 64;
    return;
  }

  String url = 'ws://localhost:$port';
  String ffprobe = result["ffprobe"];
  String handbrake = result["handbrake-cli"];

  QueueService service = new QueueService(inputDir, outputDir, completeDir, ffprobe, handbrake);
  print("Initing queue service");
  await service.init();


  var handler = webSocketHandler((webSocket) async {
    var server = new json_rpc.Server(webSocket.cast<String>());


    server.registerMethod("get_queue", () {
      try {
        return service.entries;
      } catch(e,st) {
        throw new json_rpc.RpcException(1, e.message);
      }
    });

    server.registerMethod("get_enums", () {
      try {
        return {"encoders": getEncoders()};
      } catch(e,st) {
        throw new json_rpc.RpcException(1, e.message);
      }
    });

    server.registerMethod("set_encoding_settings", (params) {
      try {
        String data = params.getString("data");
        Map json = jsonDecode(data);
        EncodingSettings encodingSettings = new EncodingSettings.fromJson(json);
      } catch(e,st) {
        throw new json_rpc.RpcException(1, e.message);
      }
    });

    server.listen();

  });

  var shelfServer = await io.serve(handler, 'localhost', port);
  print('Serving at http://${shelfServer.address.host}:${shelfServer.port}');


}




