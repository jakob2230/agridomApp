import 'package:camera/camera.dart';
import 'package:intl/intl.dart';

class TimeInHandler {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(cameras![0], ResolutionPreset.medium);
      await _cameraController!.initialize();
    }
  }

  Future<Map<String, String>> captureTimeIn() async {
    String timeIn = DateFormat('hh:mm:ss a').format(DateTime.now());
    String imagePath = "";

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile file = await _cameraController!.takePicture();
        imagePath = file.path; // Save the image path
      } catch (e) {
        print("Error taking picture: $e");
      }
    }

    return {"time": timeIn, "image": imagePath};
  }
  
  void dispose() {
    _cameraController?.dispose();
  }
}
