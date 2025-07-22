import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as imglib;

import 'quickjpeg_bindings_generated.dart';

void qjInit() {
  if (_bindings.init() == 0) {
    return;
  } else {
    throw "Init error";
  }
}

class Box {
  Pointer<Uint8> data = nullptr;
  int capacity = 0;

  void copy(Uint8List list) {
    if (list.lengthInBytes > capacity) {
      if (data != nullptr) {
        malloc.free(data);
      }

      data = malloc.allocate(list.lengthInBytes);
      capacity = list.lengthInBytes;
      log("Reallocated box with capacity $capacity");
    }

    data.asTypedList(list.lengthInBytes).setRange(0, list.lengthInBytes, list);
  }

  void dispose() {
    if (data == nullptr) {
      return;
    }
    calloc.free(data);
  }
}

final y = Box();
final u = Box();
final v = Box();

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

Uint8List compressImageManual(CameraImage image) {
  final yPlane = image.planes[0];
  final yBuffer = yPlane.bytes;
  final yStride = yPlane.bytesPerRow;
  y.copy(yBuffer);

  final uPlane = image.planes[1];
  final uBuffer = uPlane.bytes;
  final uStride = uPlane.bytesPerRow;
  u.copy(uBuffer);

  final vPlane = image.planes[2];
  final vBuffer = vPlane.bytes;
  final vStride = vPlane.bytesPerRow;
  v.copy(vBuffer);

  final res = _bindings.compress_image_manual(
    y.data,
    yBuffer.lengthInBytes,
    yStride,
    yPlane.bytesPerPixel!,
    u.data,
    uBuffer.lengthInBytes,
    uStride,
    uPlane.bytesPerPixel!,
    v.data,
    vBuffer.lengthInBytes,
    vStride,
    vPlane.bytesPerPixel!,
    image.width,
    image.height,
  );

  //calloc.free(y);
  //calloc.free(u);
  //calloc.free(v);

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
