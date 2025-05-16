import 'package:flutter/material.dart';
import '../models/document_model.dart';

class DocumentItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onConvert;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const DocumentItem({
    super.key,
    required this.document,
    required this.onConvert,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon theo loại file
                Icon(
                  document.isPdf
                      ? Icons.picture_as_pdf
                      : Icons.insert_drive_file,
                  color: document.isPdf ? Colors.red : Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                // Tên file và trạng thái
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.fileName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildStatusText(),
                    ],
                  ),
                ),
                // Nút xóa
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  color: Colors.red.shade300,
                  tooltip: 'Xóa tài liệu',
                ),
              ],
            ),

            if (document.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText.rich(
                  TextSpan(
                    text: 'Lỗi: ${document.error}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Các nút hành động
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!document.isPdf &&
                    !document.isConverted &&
                    !document.isConverting)
                  ElevatedButton.icon(
                    onPressed: onConvert,
                    icon: const Icon(Icons.transform),
                    label: const Text('Chuyển đổi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (document.isConverting)
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    label: const Text('Đang chuyển đổi...'),
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: Colors.blue.shade300,
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                if (document.isPdf || document.isConverted)
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('Xem'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    final Color textColor;
    final String statusText;

    if (document.isPdf) {
      textColor = Colors.green.shade700;
      statusText = 'Tệp PDF';
    } else if (document.isConverted) {
      textColor = Colors.green.shade700;
      statusText = 'Đã chuyển đổi sang PDF';
    } else if (document.isConverting) {
      textColor = Colors.orange.shade700;
      statusText = 'Đang chuyển đổi...';
    } else {
      textColor = Colors.grey.shade700;
      statusText = 'Tệp DOCX';
    }

    return Text(
      statusText,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
