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
    final HtmlWebSocketChannel _socket = new HtmlWebSocketChannel.connect('ws://localhost:8080');
    final  client = new json_rpc.Client(_socket.cast<String>());
    client.listen();
    try {
      return await work(client);
    } finally {
      client.close();
    }

  }

  JobQueueService() {
  }



  Future<List<JobQueueEntry>> getJobQueue() async {
    log.finest("JobQueueService.getJobQueue");

    List result = await clientWrapper((client) => client.sendRequest("get_queue"));

    log.info("Response: $result");

    List<JobQueueEntry> output = <JobQueueEntry>[];
    for (Map entry in result) {
      output.add(new JobQueueEntry.fromJson(entry));
    }

    return output;
  }

  Future<Map> getEnums() async {
    log.finest("getJobQueue");

    Map result = await clientWrapper((client) => client.sendRequest("get_enums"));

    log.info("Response: $result");

    return result;
  }
}