import 'dart:developer';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

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
