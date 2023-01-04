import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'event.dart';
import 'subscription.dart';

class Relay {
  final String _url;
  late WebSocketHandler _ws;

  Relay(String url) : _url = url {
    _ws = WebSocketHandler(_url);
  }

  // Relay._({required WebSocketHandler websocket}) : _ws = websocket;

  // factory Relay.init(String url) {
  //   final ws = WebSocketHandler(url);
  //   return Relay._(websocket: ws);
  // }

  void listen(Function callback) {
    _ws.addListener(callback);
  }

  Future<void> connect() async {
    return await _ws.connect();
  }

  void disconnect() {
    _ws.reset();
  }

  void subscribe(Subscription subscription) {
    final message = json.encode(["REQ", subscription.id, subscription.filters]);
    _ws.send(message);
  }

  void unsubscribe(String subscriptionId) {
    final message = json.encode(["CLOSE", subscriptionId]);
    _ws.send(message);
  }

  void post(Event event) {
    final message = json.encode(["EVENT", event.toJson()]);
    _ws.send(message);
  }
}

class WebSocketHandler {
  final String _url;
  IOWebSocketChannel? _channel;
  bool _disconnected = true;
  final List<Function> _listeners = [];

  WebSocketHandler(this._url);

  connect() async {
    reset();
    await WebSocket.connect(_url)
        .timeout(const Duration(seconds: 10))
        .then((ws) {
      _channel = IOWebSocketChannel(ws);
      _disconnected = false;
      _channel!.stream.listen(_onReceiveMessage, onError: (error) {},
          onDone: () {
        _disconnected = true;
      });
    });
  }

  reset() {
    if (_channel != null) {
      _channel!.sink.close();
      _disconnected = true;
    }
  }

  send(String message) {
    if (_disconnected) {
      connect();
    }
    if (_channel != null && !_disconnected) {
      _channel!.sink.add(message);
    }
  }

  addListener(Function callback) {
    _listeners.add(callback);
  }

  removeListener(Function callback) {
    _listeners.remove(callback);
  }

  _onReceiveMessage(message) {
    _disconnected = false;
    for (Function callback in _listeners) {
      callback(message);
    }
  }
}
