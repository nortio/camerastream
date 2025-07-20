import 'package:camera/camera.dart';
import 'package:camerastream/model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BenchPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const BenchPage({super.key, required this.cameras});

  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  late BenchAppModel model;

  @override
  void initState() {
    super.initState();

    model = BenchAppModel(widget.cameras, 500);
    model.controllerInitialized.future.then((_) {
      model.start();
    });

    WakelockPlus.enable();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ChangeNotifierProvider<BenchAppModel>.value(
            value: model,
            child: BenchWidget(),
          ),
        ),
      ),
    );
  }
}

class BenchWidget extends StatefulWidget {
  const BenchWidget({super.key});

  @override
  State<BenchWidget> createState() => _BenchWidgetState();
}

class _BenchWidgetState extends State<BenchWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<BenchAppModel>(
      builder: (BuildContext context, BenchAppModel value, Widget? child) {
        return value.started
            ? Text("${value.tries}")
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Stopped"),
                  TextButton(
                    onPressed: () {
                      value.start();
                    },
                    child: Text("start"),
                  ),
                ],
              );
      },
    );
  }
}
