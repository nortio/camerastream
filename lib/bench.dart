import 'dart:io';

import 'package:path/path.dart' as p;

class Bench<T> {
  final stopwatch = Stopwatch();
  final List<int> _data = [];
  List<int> get data => _data;
  String name;

  Bench(this.name);

  T run(T Function() fn) {
    stopwatch.start();
    final res = fn();
    stopwatch.stop();
    _data.add(stopwatch.elapsedMicroseconds);
    stopwatch.reset();
    return res;
  }

  void clear() {
    _data.clear();
    stopwatch.reset();
  }

  void saveToFile(Directory dir) {
    final file = File(p.join(dir.path, "timings_$name"));
    file.writeAsStringSync(_data.join("\n"), mode: FileMode.write, flush: true);
  }
}
