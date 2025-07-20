import 'dart:io';

class Bench<T> {
  final stopwatch = Stopwatch();
  final File file;
  final List<int> _data = [];
  List<int> get data => _data;

  Bench(String name)
    : file = File("${Directory.systemTemp.absolute.path}/timings_$name") {
    file.writeAsString("", flush: true, mode: FileMode.write);
  }

  T run(T Function() fn) {
    stopwatch.start();
    final res = fn();
    stopwatch.stop();
    _data.add(stopwatch.elapsedMicroseconds);
    stopwatch.reset();
    return res;
  }

  void saveToFile() {
    file.writeAsStringSync(_data.join("\n"), mode: FileMode.write, flush: true);
  }
}
