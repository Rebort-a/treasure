import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 文件插件适配；首页与聊天共享图片选择能力，不依赖彼此的界面。
class MediaFilePicker {
  static Future<Uint8List?> pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    return file == null ? null : await file.readAsBytes();
  }

  static Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    dialogTitle: dialogTitle,
  );
}
