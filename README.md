# camerastream

With this application you can stream your phone camera anywhere you want. It currently uses MJPEG (basically every frame is a JPEG image), so image quality relative to used bandwidth is not great. Still, it's good enough for a quick webcam for your desktop pc: you can for example use [IP Camera Adapter](https://ip-webcam.appspot.com/) on Windows, or [ffmpeg and v4l2loopback](https://superuser.com/questions/751568/use-a-ip-camera-as-a-virtual-camera) on Linux. It can also stream to multiple clients.

## Usage

Download the pre-built app from the releases section, or build it yourself if you don't trust the apk file. The app is small enough so you can probably read all the source code for yourself. See the **Build** section for build instructions.

Once installed, open it and press the button in the bottom-right corner. If you're connected to Wi-Fi, an address should appear on the screen: this is the URL of the MJPEG stream that you can use to view the camera from devices connected to your network. To verify everything it's working, try to open it in a browser on your PC (which should be connected on the same network).

### Linux notes

This is the command I use to stream to a v4l2loopback device (`/dev/video0`, see link above for instructions on how to create it):

```bash
ffmpeg -i http://<address>:8080/ -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 /dev/video0 # <--- change /dev/video0 to your v4l2loopback device
```

## Limitations

The app is very barebones at the moment. It by default selects the primary back camera and it uses a fixed resolution (720x480). You cannot change the port nor the IP which the http server listens on without recompiling the app. These issues are going to be fixed in the near future. 

## TODO

* Implement a way to switch cameras and change streaming resolution
* Make address and port configurable
* Add standard camera features (such as flash, or disabling autofocus)
* Add simpler instructions to app
* Make a website for download
* F-Droid? Other app stores maybe?
* Maybe switch to H264 and make a custom adapter for Windows (ffmpeg should be able to handle it fine on Linux) (distant future)

## Build

You will need:

* Flutter
* Android SDK

Please follow [these](https://docs.flutter.dev/get-started/install) instructions from the Flutter website to download the SDK. Once you downloaded the SDK, a simple `flutter build apk --release` should work.

### Technical details

This app uses the `camera` plugin for Flutter which in turn uses CameraX by default. When the stream starts, the app opens an image stream (with `controller.startImageStream`) which feeds the images to an FFI plugin written in C, which in turn converts the YCbCr image to RGB and then compresses to JPEG with `libjpeg-turbo`.  The only issue is that the yuv420 image - as reported by ImageFormatGroup - is encoded in a weird format on some phones I've tested (see [#26348](https://github.com/flutter/flutter/issues/26348) and [#27686](https://github.com/flutter/flutter/issues/27686#issuecomment-2211774141)) so I had to convert it manually instead of using `libyuv` or the turbojpeg YUV compression functions. I plan on eventually fixing this.
