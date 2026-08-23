import 'package:image_picker/image_picker.dart';

abstract interface class FootprintPhotoPicker {
  Future<String?> pickPrivateKeepsake();
}

class ImagePickerFootprintPhotoPicker implements FootprintPhotoPicker {
  ImagePickerFootprintPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickPrivateKeepsake() async => (await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 4096,
        maxHeight: 4096,
      ))
          ?.path;
}
