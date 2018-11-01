import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as io;
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:stream_channel/stream_channel.dart";
import "package:web_socket_channel/io.dart";
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:app/server.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shelf_static/shelf_static.dart';
import 'package:app/shared.dart';

main(List<String> args) async {
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen(logToConsole);


  var parser = new ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('data-dir', abbr: 'd')
    ..addOption('web-dir', abbr: 'w', defaultsTo: 'web')
    ..addOption('input-dir', abbr: 'i', defaultsTo: "input")
    ..addOption('complete-dir', abbr: 'c', defaultsTo: "complete")
    ..addOption('output-dir', abbr: 'o', defaultsTo: "output")
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

  String dataDir = result["data-dir"];
  if((dataDir??"").isEmpty) {
    stdout.writeln('data-dir is required');
    exitCode = 64;
    return;
  }

  String inputDir = result["input-dir"];
  if((inputDir??"").isEmpty) {
    stdout.writeln('input-dir is required');
    exitCode = 64;
    return;
  }
  if(path.isRelative(inputDir)) {
    inputDir = path.join(dataDir, inputDir);
  }

  String completeDir = result["complete-dir"];
  if((completeDir??"").isEmpty) {
    stdout.writeln('complete-dir is required');
    exitCode = 64;
    return;
  }
  if(path.isRelative(completeDir)) {
    completeDir = path.join(dataDir, completeDir);
  }


  String outputDir = result["output-dir"];
  if((outputDir??"").isEmpty) {
    stdout.writeln('output-dir is required');
    exitCode = 64;
    return;
  }
  if(path.isRelative(outputDir)) {
    outputDir = path.join(dataDir, outputDir);
  }


  String webDir = result["web-dir"];
  if((webDir??"").isEmpty) {
    stdout.writeln('web-dir is required');
    exitCode = 64;
    return;
  }

  String url = 'ws://localhost:$port';
  String ffprobe = result["ffprobe"];
  String handbrake = result["handbrake-cli"];

  QueueService service = new QueueService(inputDir, outputDir, completeDir, ffprobe, handbrake);
  await service.init();


  var socketHandler = webSocketHandler((webSocket) async {
    var server = new json_rpc.Server(webSocket.cast<String>());


    server.registerMethod("get_queue", () {
      try {
        return service.entries;
      } catch(e,st) {
        throw new json_rpc.RpcException(1, e.message);
      }
    });

    server.registerMethod("clear_complete", () {
      service.clearComplete();
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

  var staticHandler = createStaticHandler(webDir, defaultDocument: "index.html");
  
  
  var handler = (Request request) {
    if(request.headers.containsKey("sec-websocket-version")) {
      return socketHandler(request);
    } else {
      return staticHandler(request);
    }
  };

  var shelfServer = await io.serve(handler, InternetAddress.anyIPv6, port);
  print('Serving at http://${shelfServer.address.host}:${shelfServer.port}');


}





