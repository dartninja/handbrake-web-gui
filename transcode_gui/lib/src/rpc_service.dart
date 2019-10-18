import 'dart:async';
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:stream_channel/stream_channel.dart";
import "package:web_socket_channel/html.dart";
import 'data/job_queue_entry.dart';
import 'dart:html';
import 'package:logging/logging.dart';

class RpcService {
  final Logger log = new Logger('RpcService');

  Future<dynamic> clientWrapper(Function work) async {
    String protocol = "ws";
    if (window.location.protocol == "https:") {
      protocol = "wss";
    }
    String url = "$protocol://${window.location.host}";

    log.finer("Websocket URL: $url");
    // When running in dev, since I use PHPStorm, the client runs via a different
    // server than the dartalog server component. This is usually on a 5-digit port,
    // which theoretically wouldn't be used ina  real deployment.
    // TODO: Figure out a cleaner way of handling this
    if (window.location.port.length >= 5) url = "ws://localhost:8080";

    final HtmlWebSocketChannel _socket = new HtmlWebSocketChannel.connect(url);
    final client = new json_rpc.Client(_socket.cast<String>());
    client.listen();
    try {
      return await work(client);
    } finally {
      client.close();
    }
  }

  JobQueueService() {}

  Future<List<JobQueueEntry>> getJobQueue() async {
    log.finest("JobQueueService.getJobQueue");

    List result =
        await clientWrapper((client) => client.sendRequest("get_queue"));

    log.info("Response: $result");

    List<JobQueueEntry> output = <JobQueueEntry>[];
    for (Map entry in result) {
      output.add(new JobQueueEntry.fromJson(entry));
    }

    return output;
  }

  Future<void> clearComplete() async {
    await clientWrapper((client) => client.sendRequest("clear_complete"));
  }

  Future<Map> getEnums() async {
    log.finest("getJobQueue");

    Map result =
        await clientWrapper((client) => client.sendRequest("get_enums"));

    log.info("Response: $result");

    return result;
  }
}
