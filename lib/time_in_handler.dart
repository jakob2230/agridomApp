// time_in_handler.dart
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';

class TimeInHandler {
  CameraController? cameraController;
  List<CameraDescription>? cameras;

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      cameraController = CameraController(cameras![0], ResolutionPreset.medium);
      await cameraController!.initialize();
    }
  }

  // Return captured image file path as a String
  Future<String> captureTimeIn() async {
    String imagePath = "";
    if (cameraController != null && cameraController!.value.isInitialized) {
      try {
        final XFile file = await cameraController!.takePicture();
        imagePath = file.path;
      } catch (e) {
        print("Error taking picture: $e");
      }
    }
    return imagePath;
  }
  
  void disposeCamera() {
    cameraController?.dispose();
  }
}
