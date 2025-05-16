import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/src/foundation/platform.dart' as platform;
import 'simple_web_pdf_viewer.dart';

class PdfViewer extends HookConsumerWidget {
  final String filePath;
  final Uint8List? pdfBytes;
  final String? pdfUrl;

  const PdfViewer({
    super.key,
    required this.filePath,
    this.pdfBytes,
    this.pdfUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPagesState = useState<int>(0);
    final currentPageState = useState<int>(0);
    final isReady = useState<bool>(false);
    final isLoading = useState<bool>(false);

    // Hàm để tải PDF
    Future<void> downloadPdf() async {
      try {
        isLoading.value = true;

        if (kIsWeb) {
          if (pdfBytes != null) {
            _downloadBytesOnWeb(pdfBytes!, _extractFileName(filePath));
          } else if (pdfUrl != null) {
            final uri = Uri.parse(pdfUrl!);
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              _downloadBytesOnWeb(
                  response.bodyBytes, _extractFileName(pdfUrl!));
            } else {
              throw Exception('Failed to download PDF: ${response.statusCode}');
            }
          } else {
            throw Exception('No PDF data available to download');
          }
        } else {
          final file = File(filePath);
          if (await file.exists()) {
            final uri = Uri.file(file.path);
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              throw Exception('Could not open the PDF file');
            }
          } else {
            throw Exception('PDF file not found');
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        isLoading.value = false;
      }
    }

    // Widget cho trang web
    Widget buildWebPdfViewer() {
      if (!kIsWeb) {
        return const Center(
            child: Text('This view is only available on web platforms'));
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            _extractFileName(filePath),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Tải PDF',
              onPressed: isLoading.value ? null : downloadPdf,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: pdfBytes != null
                  ? SimpleWebPdfViewer(pdfBytes: pdfBytes)
                  : pdfUrl != null
                      ? SimpleWebPdfViewer(pdfUrl: pdfUrl)
                      : const Center(
                          child: Text('Không có dữ liệu PDF để hiển thị')),
            ),
            if (isLoading.value) const LinearProgressIndicator(),
          ],
        ),
      );
    }

    // Widget cho mobile
    Widget buildMobilePdfViewer() {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _extractFileName(filePath),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            if (totalPagesState.value > 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    'Trang ${currentPageState.value + 1}/${totalPagesState.value}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Tải PDF',
              onPressed: isLoading.value ? null : downloadPdf,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: isReady.value
                  ? PDFView(
                      filePath: filePath,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      onRender: (pages) {
                        isReady.value = true;
                        totalPagesState.value = pages!;
                      },
                      onPageChanged: (page, total) {
                        currentPageState.value = page!;
                      },
                      onError: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            if (isLoading.value) const LinearProgressIndicator(),
          ],
        ),
      );
    }

    // Trả về widget phù hợp với nền tảng
    return kIsWeb ? buildWebPdfViewer() : buildMobilePdfViewer();
  }

  // Hàm trích xuất tên file từ đường dẫn
  String _extractFileName(String path) {
    // Xử lý đường dẫn URL
    if (path.contains('/')) {
      final parts = path.split('/');
      return parts.last;
    }
    // Xử lý đường dẫn file
    else if (path.contains('\\')) {
      final parts = path.split('\\');
      return parts.last;
    }
    // Trường hợp chỉ là tên file
    return path;
  }

  // Hàm download file trên web
  void _downloadBytesOnWeb(Uint8List bytes, String fileName) {
    // Tạo blob và tải xuống
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Tạo thẻ a và tải xuống
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    // Giải phóng URL
    html.Url.revokeObjectUrl(url);
  }
}
