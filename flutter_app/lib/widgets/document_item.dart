import 'package:flutter/material.dart';
import '../models/document_model.dart';

class DocumentItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onConvert;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback? onSign;

  const DocumentItem({
    Key? key,
    required this.document,
    required this.onConvert,
    required this.onView,
    required this.onDelete,
    this.onSign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  document.isPdf ? Icons.picture_as_pdf : Icons.file_present,
                  color: document.isPdf ? Colors.red : const Color(0xFF2196F3),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    document.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                _buildActionButtons(context),
              ],
            ),
            if (document.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lỗi: ${document.error}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!document.isPdf && !document.isConverted)
          IconButton(
            icon: const Icon(
              Icons.sync,
              color: Color(0xFF2196F3), // Light Blue 500
            ),
            tooltip: 'Chuyển đổi sang PDF',
            onPressed: document.isConverting ? null : onConvert,
          ),
        if (document.isPdf || document.isConverted)
          IconButton(
            icon: Icon(
              Icons.visibility,
              color: document.isSigned ? Colors.green : const Color(0xFF2196F3),
            ),
            tooltip: document.isSigned ? 'Xem tài liệu đã ký' : 'Xem tài liệu',
            onPressed: onView,
          ),
        // Thêm nút ký tài liệu nếu tài liệu là PDF hoặc đã chuyển đổi và có onSign callback
        if ((document.isPdf || document.isConverted) && onSign != null)
          IconButton(
            icon: Icon(
              document.isSigned ? Icons.done_all : Icons.draw,
              color: document.isSigned
                  ? Colors.green
                  : const Color(0xFF2196F3), // Light Blue 500
            ),
            tooltip: document.isSigned ? 'Đã ký' : 'Ký tài liệu',
            onPressed: document.isSigned ? null : onSign,
          ),
        IconButton(
          icon: Icon(
            Icons.delete,
            color: Colors.grey.shade600,
          ),
          tooltip: 'Xóa tài liệu',
          onPressed: onDelete,
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (document.isConverting) {
      return Colors.orange;
    } else if (document.error != null) {
      return Colors.red;
    } else if (document.isSigned) {
      return Colors.green.shade600;
    } else if (document.isConverted) {
      return const Color(0xFF2196F3); // Light Blue 500
    } else if (document.isPdf) {
      return const Color(0xFF9C27B0); // Purple 500
    } else {
      return Colors.grey;
    }
  }

  String _getStatusText() {
    if (document.isConverting) {
      return 'Đang chuyển đổi...';
    } else if (document.error != null) {
      return 'Lỗi';
    } else if (document.isSigned) {
      return 'Đã ký thành công';
    } else if (document.isConverted) {
      return 'Đã chuyển đổi';
    } else if (document.isPdf) {
      return 'PDF';
    } else {
      return 'DOCX';
    }
  }
}
