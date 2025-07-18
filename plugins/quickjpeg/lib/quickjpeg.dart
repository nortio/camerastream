import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as imglib;

import 'quickjpeg_bindings_generated.dart';

void init() {
  if (_bindings.init() == 0) {
    return;
  } else {
    throw "Init error";
  }
}

Pointer<Uint8> copyToNative(Uint8List data) {
  final res = calloc<Uint8>(data.lengthInBytes);
  res.asTypedList(data.lengthInBytes).setRange(0, data.lengthInBytes, data);
  return res;
}

Uint8List compressImage(CameraImage image) {
  log(
    "Image size: ${image.width}x${image.height}, Format: ${image.format.group} - ${image.format.raw}",
  );
  final yPlane = image.planes[0];
  final yBuffer = yPlane.bytes;
  final yStride = yPlane.bytesPerRow;
  final y = copyToNative(yBuffer);

  final uPlane = image.planes[1];
  final uBuffer = uPlane.bytes;
  final uStride = uPlane.bytesPerRow;
  log("U Stride: $uStride - bytesPerPixel: ${uPlane.bytesPerPixel}");
  final u = copyToNative(uBuffer);

  final vPlane = image.planes[2];
  final vBuffer = vPlane.bytes;
  final vStride = vPlane.bytesPerRow;
  final v = copyToNative(vBuffer);

  final res = _bindings.compress_image(
    y,
    yBuffer.lengthInBytes,
    yStride,
    u,
    uBuffer.lengthInBytes,
    uStride,
    v,
    vBuffer.lengthInBytes,
    vStride,
    image.width,
    image.height,
  );

  calloc.free(y);
  calloc.free(u);
  calloc.free(v);

  if (res.data == nullptr) {
    throw "Compression error";
  }

  return res.data.asTypedList(res.len);
}

Uint8List compressRGBImage(imglib.Image image) {
  final data = image.data;
  if (data == null) {
    throw "Null data";
  }
  final copy = copyToNative(data.getBytes());
  final res = _bindings.compress_rgb(
    copy,
    data.rowStride,
    image.width,
    image.height,
  );

  calloc.free(copy);
  return res.data.asTypedList(res.len);
}

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) => _bindings.sum(a, b);

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'quickjpeg';

/// The dynamic library in which the symbols for [QuickjpegBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final QuickjpegBindings _bindings = QuickjpegBindings(_dylib);

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
