import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'box.dart';
import 'quickjpeg_bindings_generated.dart';

const String _libName = 'quickjpeg';

class QuickJpeg {
  static final y = Box();
  static final u = Box();
  static final v = Box();

  /// The dynamic library in which the symbols for [QuickjpegBindings] can be found.
  static final DynamicLibrary _dylib = () {
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
  static final QuickjpegBindings _bindings = QuickjpegBindings(_dylib);

  static void init() {
    if (_bindings.init() == 0) {
      return;
    } else {
      throw "Init error";
    }
  }

  static void dispose() {
    y.dispose();
    u.dispose();
    v.dispose();
  }

  static Uint8List compressImageManual(CameraImage image) {
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

  /*
  static Uint8List compressRGBImage(imglib.Image image) {
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
*/
}
