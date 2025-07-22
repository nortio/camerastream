import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quickjpeg/quickjpeg.dart';

import 'bench.dart';

Future<InternetAddress?> getLocalAddress() async {
  final list = await NetworkInterface.list();

  for (var interface in list) {
    if (interface.name != "wlan0" && interface.name != "eth0") {
      continue;
    }

    for (var address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4) {
        return address;
      }
    }
  }
  return null;
}

class AppModel extends ChangeNotifier {
  late final CameraController cameraController;
  final List<CameraDescription> _cameras;
  Completer<void> controllerInitialized = Completer();
  InternetAddress? address;
  bool cameraDenied = false;
  bool _started = false;

  bool get started => _started;
  set started(bool start) {
    _started = start;
    notifyListeners();
  }

  var streamController = StreamController<Uint8List>.broadcast();
  late ServerSocket serverSocket;
  Set<Socket> connectedClients = {};

  AppModel(this._cameras) {
    cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.medium,
      //imageFormatGroup: ImageFormatGroup.nv21,
    );
    log("Selected resolution preset: ${cameraController.resolutionPreset}");
    log("Selected camera: ${cameraController.cameraId}");

    getLocalAddress().then((x) {
      address = x;
      notifyListeners();
    });

    cameraController
        .initialize()
        .then((_) {
          controllerInitialized.complete();
          notifyListeners();
        })
        .catchError((e) {
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                // Handle access errors here.
                cameraDenied = true;
                break;
              default:
                // Handle other errors here.
                log(e.toString());
                break;
            }
          }
        });
    initServer();
  }

  Future<void> disconnectAllClients() async {
    for (final client in connectedClients) {
      client.close();
    }

    connectedClients.clear();
    notifyListeners();
  }

  void send404(Socket socket) {
    socket.write(
      "HTTP/1.1 404 Not Found\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n<h1>404</h1>",
    );
    socket.close();
  }

  Future<void> initServer() async {
    serverSocket = await ServerSocket.bind("0.0.0.0", 8080);
    serverSocket.listen(
      (socket) {
        log("New connection: ${socket.address.address}:${socket.port}");

        if (streamController.isClosed) {
          send404(socket);
        }

        socket.write(
          "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n",
        );

        final sub = streamController.stream.listen((e) {
          socket.write(
            "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${e.length}\r\n\r\n",
          );
          socket.add(e);
          socket.write("\r\n");
        });

        socket.listen(
          (d) {},
          onError: (e, st) {
            log("Error on socket listen: $e\n$st");
            sub.cancel();
            connectedClients.remove(socket);
            notifyListeners();
          },
          onDone: () {
            log("Socket ${socket.address} closed");
            sub.cancel();
            connectedClients.remove(socket);
            notifyListeners();
          },
          cancelOnError: true,
        );

        connectedClients.add(socket);
        notifyListeners();
      },
      onError: (e) {
        log("ServerSocket error: $e");
      },
    );
  }

  Future<void> stop() async {
    if (!cameraController.value.isInitialized) {
      return;
    }

    started = false;

    cameraController.stopImageStream();
    streamController.close();
    await disconnectAllClients();
  }

  bool start() {
    if (!cameraController.value.isInitialized) {
      return false;
    }

    if (streamController.isClosed) {
      streamController = StreamController<Uint8List>.broadcast();
    }

    started = true;

    log("Logging timings to ${Directory.systemTemp.absolute.path}");
    cameraController.startImageStream((i) {
      switch (i.format.group) {
        case ImageFormatGroup.yuv420:
          {
            if (!streamController.hasListener) {
              return;
            }

            //final image = ImageUtils.convertCameraImage(i);
            //final bytes = encoder.encode(image, singleFrame: true);
            //final jpeg = qj.compressRGBImage(image);
            streamController.add(QuickJpeg.compressImageManual(i));
            break;
          }
        case ImageFormatGroup.unknown:
        case ImageFormatGroup.bgra8888:
        case ImageFormatGroup.jpeg:
        case ImageFormatGroup.nv21:
          {
            log("Unsupported image format!");
            cameraController.stopImageStream();
            started = false;
            return;
          }
      }
    });

    return true;
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void dump(CameraImage i) {
    //final path = "${Directory.systemTemp.absolute.path}/temp.jpeg";
    //final file = File(path);
    //file.writeAsBytesSync(qj.QuickJpeg.compressImage(i));

    //log("Saved jpeg to $path");
    log("PLANES: ${i.planes.length}");

    File(
      "${Directory.systemTemp.absolute.path}/y.raw",
    ).writeAsBytesSync(i.planes[0].bytes);
    File(
      "${Directory.systemTemp.absolute.path}/u.raw",
    ).writeAsBytesSync(i.planes[1].bytes);
    File(
      "${Directory.systemTemp.absolute.path}/v.raw",
    ).writeAsBytesSync(i.planes[2].bytes);
    File("${Directory.systemTemp.absolute.path}/info").writeAsStringSync(
      "${i.width}x${i.height}\n${i.planes[0].bytesPerRow}\n${i.planes[1].bytesPerRow}\n${i.planes[2].bytesPerRow}",
    );

    return;
  }
}

class BenchAppModel extends AppModel {
  int _tries;
  int _initialTries = 0;
  Bench nativeBench = Bench("native");
  Bench dartBench = Bench("dart");

  final voidStreamController = StreamController<Uint8List>();

  BenchAppModel(super.cameras, this._tries) {
    if (_tries < 1) {
      throw "Tries must be > 1";
    }
    _initialTries = _tries;
    voidStreamController.stream.listen((e) {
      counter += e.length;
    });
  }

  int get tries => _tries;
  set tries(int t) {
    _tries = t;
    notifyListeners();
  }

  int counter = 0;

  @override
  bool start() {
    if (!cameraController.value.isInitialized) {
      log("Camera controller is not initialized yet");
      return false;
    }

    counter = 0;
    _tries = _initialTries;
    started = true;

    log("Logging timings to ${Directory.systemTemp.absolute.path}");
    cameraController.startImageStream((i) {
      switch (i.format.group) {
        case ImageFormatGroup.yuv420:
          {
            //final j = dartBench.run(() {
            //  //final image = ImageUtils.convertCameraImage(i);
            //  //final bytes = encoder.encode(image, singleFrame: true);
            //  //return qj.compressRGBImage(image);
            //});

            //voidStreamController.add(j);

            final jpeg = nativeBench.run(() {
              //qj.convertOnlyTest(i);
              return QuickJpeg.compressImageManual(i);
            });

            voidStreamController.add(jpeg);

            break;
          }
        case ImageFormatGroup.unknown:
        case ImageFormatGroup.bgra8888:
        case ImageFormatGroup.jpeg:
        case ImageFormatGroup.nv21:
          {
            log("Unsupported image format!");
            cameraController.stopImageStream();
            started = false;
            return;
          }
      }
      //log("Completed try $tries");
      tries--;
      if (tries == 0) {
        close();
      }
    });

    return true;
  }

  void close() async {
    started = false;
    cameraController.stopImageStream();

    final downloads = await getDownloadsDirectory();

    log("Saving to $downloads");
    log("Counter: $counter");

    dartBench.saveToFile(downloads!);
    nativeBench.saveToFile(downloads);

    dartBench.clear();
    nativeBench.clear();
  }
}
