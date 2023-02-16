import 'dart:io';
import 'dart:convert';
import 'package:nostr_dart/nostr_dart.dart';

Future<HttpServer> fakeRelay(
    {required Function(dynamic json) onData,
    List<dynamic> events = const [],
    bool listen = true}) async {
  final relay = await HttpServer.bind('localhost', 0);
  if (listen) {
    relay.transform(WebSocketTransformer()).listen((webSocket) {
      webSocket.listen((encodedMessage) {
        final message = jsonDecode(encodedMessage);
        onData(message);
        final type = message[0];
        if (type == "EVENT") {
          final event = Event.fromJson(message[1]);
          final response = ["OK", event.id, true, ""];
          webSocket.add(jsonEncode(response));
        } else if (type == "REQ") {
          final subId = message[1];
          for (dynamic event in events) {
            List<dynamic> response = [event[0], subId, event[2]];
            webSocket.add(jsonEncode(response));
          }
          final endNotice = ["EOSE", subId];
          webSocket.add(jsonEncode(endNotice));
        }
      });
    });
  } else {
    relay.transform(WebSocketTransformer());
  }
  return relay;
}
