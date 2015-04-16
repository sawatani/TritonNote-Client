library after_done;

import 'dart:isolate';

class AfterDone<T> {
  final String name;
  T _msg;
  bool get isDone => _msg != null;

  final ReceivePort port = new ReceivePort();
  var _stream;
  get _broadcast {
    if (_stream == null) _stream = port.asBroadcastStream();
    return _stream;
  }

  AfterDone(this.name) {}

  void done(T msg) {
    assert(msg != null);
    print("${name} is done: ${msg}");
    _msg = msg;
    port.sendPort.send(msg);
  }

  void listen(void proc(T)) {
    if (!isDone) {
      _broadcast.listen(proc);
    } else proc(_msg);
  }
}
