import 'dart:io';

class Bench<T> {
  final stopwatch = Stopwatch();
  final File file;

  Bench(String name)
    : file = File("${Directory.systemTemp.absolute.path}/timings_$name") {
    file.writeAsString("", flush: true, mode: FileMode.write);
  }

  T run(T Function() fn) {
    stopwatch.start();
    final res = fn();
    stopwatch.stop();
    file.writeAsStringSync(
      "${stopwatch.elapsedMicroseconds}\n",
      mode: FileMode.append,
      flush: true,
    );
    stopwatch.reset();
    return res;
  }
}
