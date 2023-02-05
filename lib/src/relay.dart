import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'dart:developer';
import 'package:web_socket_channel/io.dart';
import 'package:queue/queue.dart' as job_queue;

enum WriteAccess { readOnly, writeOnly, readWrite }

class Relay {
  final String _url;
  final WriteAccess access;
  late WebSocketHandler _ws;
  final _jobRunner = job_queue.Queue();
  final Queue<Completer<void>> _pendingResponses = Queue();
  Function? _listener;

  Relay(String url, {Function? onDone, this.access = WriteAccess.readOnly})
      : _url = url {
    _ws = WebSocketHandler(_url, onDone: onDone);
    _ws.addListener(_onData);
  }

  String get url => _url;

  bool get isDisconnected => _ws.isDisconnected;

  void listen(Function? callback) {
    _listener = callback;
  }

  Future<bool> connect() async {
    bool result = await _ws.connect();
    return result;
  }

  Future<void> disconnect() async {
    await _ws.reset();
  }

  void send(String message) {
    _jobRunner.add(() => _send(message));
  }

  Future<void> _send(String message) async {
    final completer = Completer();
    completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException("No response from $_url");
      },
    ).catchError((err) {
      log(err.toString());
      _pendingResponses.removeFirst().complete();
      disconnect();
    });
    _pendingResponses.add(completer);
    log("Sending to $_url");
    _ws.send(message);
    await completer.future;
  }

  void _onData(String message) {
    final List<dynamic> json = jsonDecode(message);
    if (json[0] == 'OK' || json[0] == 'EOSE') {
      if (_pendingResponses.isNotEmpty) {
        _pendingResponses.removeFirst().complete();
      }
    }
    if (json[0] == 'NOTICE') {
      log("$_url: ${json.toString()}");
    }
    if (_listener != null) {
      json.add(_url);
      _listener!(json);
    }
  }
}

class WebSocketHandler {
  final String _url;
  IOWebSocketChannel? _channel;
  bool _disconnected = true;
  final List<Function> _listeners = [];
  final Function? _onDone;

  WebSocketHandler(this._url, {Function? onDone}) : _onDone = onDone;

  bool get isDisconnected => _disconnected;

  Future<bool> connect() async {
    reset();
    try {
      await WebSocket.connect(_url)
          .timeout(const Duration(seconds: 10))
          .then((ws) {
        _channel = IOWebSocketChannel(ws);
        _disconnected = false;
        _channel!.stream.listen(_onReceiveMessage, onError: (error) {
          log("Websocket stream error: $_url");
        }, onDone: () {
          _disconnected = true;
          if (_onDone != null) {
            _onDone!(_url);
          }
        });
      });
      return true;
    } catch (err) {
      log(err.toString());
      return false;
    }
  }

  Future<void> reset() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _disconnected = true;
    }
  }

  void send(String message) async {
    // if (_disconnected) {
    //   await connect();
    // }
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
