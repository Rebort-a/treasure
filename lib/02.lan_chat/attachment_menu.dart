import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';

/// 附件选择菜单
/// 通过传入不同的回调来控制显示哪些选项。
/// 移除 image_picker / file_picker 插件后，对应传 null 即可自动隐藏。
class AttachmentMenu extends StatelessWidget {
  final VoidCallback? onImagePick;
  final VoidCallback? onFilePick;

  const AttachmentMenu({super.key, this.onImagePick, this.onFilePick});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onImagePick != null)
                _item(
                  icon: Icons.photo_library_rounded,
                  label: S.album,
                  color: const Color(0xFF4CAF50),
                  onTap: onImagePick!,
                ),
              if (onFilePick != null)
                _item(
                  icon: Icons.insert_drive_file_rounded,
                  label: S.file,
                  color: const Color(0xFFFF9800),
                  onTap: onFilePick!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onImagePick,
    VoidCallback? onFilePick,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentMenu(
        onImagePick: onImagePick != null
            ? () {
                Navigator.of(context).pop();
                onImagePick();
              }
            : null,
        onFilePick: onFilePick != null
            ? () {
                Navigator.of(context).pop();
                onFilePick();
              }
            : null,
      ),
    );
  }
}
