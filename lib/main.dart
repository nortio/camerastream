import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camerastream/model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickjpeg/quickjpeg.dart' as qj;
import 'package:wakelock_plus/wakelock_plus.dart';

//import 'benchapp.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  qj.qjInit();
  runApp(const MyApp());
  //runApp(BenchPage(cameras: _cameras));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CameraStream',
      theme: ThemeData(colorScheme: ColorScheme.dark()),
      home: ChangeNotifierProvider(
        create: (_) => AppModel(_cameras),
        child: MyHomePage(title: 'CameraStream'),
      ),
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
  //final encoder = imglib.JpegEncoder(quality: 80);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (BuildContext context, AppModel model, Widget? child) {
        if (!model.cameraController.value.isInitialized) {
          return Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Center(
            child: !model.cameraDenied
                ? !model.started
                      ? FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: CameraPreview(model.cameraController),
                          ),
                        )
                      : Text(
                          "Streaming! (Preview is disabled)\n${model.address != null ? "Address: http://${model.address?.address}:8080" : "Unknown address (check internet connection)"}\nConnected clients: ${model.connectedClients.length}",
                        )
                : const Text("Camera use was denied"),
          ),
          floatingActionButton: !model.started
              ? FloatingActionButton(
                  tooltip: 'Start stream',
                  onPressed: () {
                    if (!mounted) {
                      return;
                    }

                    WakelockPlus.enable();

                    model.start();
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

                    await model.stop();
                  },
                  child: Icon(Icons.stop),
                ),
        );
      },
    );
  }
}
