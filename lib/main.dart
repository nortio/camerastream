import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camerastream/utils.dart';
import 'package:flutter/material.dart';
import 'package:quickjpeg/quickjpeg.dart' as qj;
import 'package:wakelock_plus/wakelock_plus.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  qj.init();
  runApp(const MyApp());
}

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.dark()),
      home: const MyHomePage(title: 'CameraStream'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController cameraController;
  bool cameraDenied = false;
  bool started = false;
  //final encoder = imglib.JpegEncoder(quality: 80);
  var streamController = StreamController<Uint8List>.broadcast();
  late ServerSocket serverSocket;
  Set<Socket> connectedClients = {};
  InternetAddress? address;

  @override
  void initState() {
    super.initState();
    cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.medium,
      //imageFormatGroup: ImageFormatGroup.nv21,
    );
    log("Selected resolution preset: ${cameraController.resolutionPreset}");
    log("Selected camera: ${cameraController.cameraId}");

    getLocalAddress().then((x) {
      setState(() {
        address = x;
      });
    });

    cameraController
        .initialize()
        .then((_) {
          if (!mounted) {
            return;
          }

          setState(() {});
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
            setState(() {
              connectedClients.remove(socket);
            });
          },
          onDone: () {
            log("Socket ${socket.address} closed");
            sub.cancel();
            setState(() {
              connectedClients.remove(socket);
            });
          },
          cancelOnError: true,
        );

        setState(() {
          connectedClients.add(socket);
        });
      },
      onError: (e) {
        log("ServerSocket error: $e");
      },
    );
  }

  Future<void> disconnectAllClients() async {
    for (final client in connectedClients) {
      client.close();
    }

    setState(() {
      connectedClients.clear();
    });
  }

  void send404(Socket socket) {
    socket.write(
      "HTTP/1.1 404 Not Found\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n<h1>404</h1>",
    );
    socket.close();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            !cameraDenied
                ? !started
                      ? CameraPreview(cameraController)
                      : Text(
                          "Streaming! (Preview is disabled)\n${address != null ? "Address: http://${address?.address}:8080" : "Unknown address (check internet connection)"}\nConnected clients: ${connectedClients.length}",
                        )
                : const Text("Camera use was denied"),
          ],
        ),
      ),
      floatingActionButton: !started
          ? FloatingActionButton(
              tooltip: 'Start stream',
              onPressed: () {
                if (!mounted) {
                  return;
                }

                if (!cameraController.value.isInitialized) {
                  return;
                }

                if (streamController.isClosed) {
                  streamController = StreamController<Uint8List>.broadcast();
                }

                setState(() {
                  started = true;
                });

                WakelockPlus.enable();

                final stopwatch = Stopwatch();
                stopwatch.start();
                cameraController.startImageStream((i) {
                  //if (stopwatch.elapsedMicroseconds < 33300) {
                  //  //log("Skipped at ${stopwatch.elapsedMilliseconds}");
                  //  return;
                  //}
                  //stopwatch.reset();
                  //stopwatch.start();
                  //log("${i.format.group}: ${i.width} - ${i.height}");

                  if (i.format.group != ImageFormatGroup.yuv420 &&
                      i.format.group != ImageFormatGroup.bgra8888) {
                    log("Unsupported image format!");
                    cameraController.stopImageStream();
                    setState(() {
                      started = false;
                    });
                    return;
                  }
                  /*
                  final path =
                      "${Directory.systemTemp.absolute.path}/temp.jpeg";
                  final file = File(path);
                  file.writeAsBytesSync(qj.compressImage(i));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Saved to ${path}")));
                  cameraController.stopImageStream();

                  log("Saved jpeg to ${path}");
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
                  File(
                    "${Directory.systemTemp.absolute.path}/info",
                  ).writeAsStringSync(
                    "${i.width}x${i.height}\n${i.planes[0].bytesPerRow}\n${i.planes[1].bytesPerRow}\n${i.planes[2].bytesPerRow}",
                  );

                  setState(() {
                    started = false;
                  });
                  return;
*/
                  if (!streamController.hasListener) {
                    return;
                  }

                  final image = ImageUtils.convertCameraImage(i);
                  //final bytes = encoder.encode(image, singleFrame: true);

                  //streamController!.add(qj.compressImage(i));
                  streamController.add(qj.compressRGBImage(image));
                });
              },
              child: const Icon(Icons.fiber_manual_record),
            )
          : FloatingActionButton(
              tooltip: "Stop stream",
              onPressed: () async {
                if (!mounted) {
                  return;
                }

                WakelockPlus.disable();

                if (!cameraController.value.isInitialized) {
                  return;
                }

                setState(() {
                  started = false;
                });

                cameraController.stopImageStream();
                streamController.close();
                await disconnectAllClients();
              },
              child: Icon(Icons.stop),
            ),
    );
  }
}
