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
    final error = useState<String?>(null);

    // Debug info
    useEffect(() {
      print('PdfViewer - Khởi tạo với:');
      print('- filePath: $filePath');
      print(
          '- pdfBytes: ${pdfBytes != null ? '${pdfBytes!.length} bytes' : 'null'}');
      print('- pdfUrl: $pdfUrl');

      if (pdfBytes != null && pdfBytes!.length > 4) {
        final signature = String.fromCharCodes(pdfBytes!.sublist(0, 4));
        print('- PDF signature: $signature');
        if (signature != '%PDF') {
          print('CẢNH BÁO: Dữ liệu không bắt đầu bằng %PDF');
          print(
              '- Bytes đầu: ${pdfBytes!.sublist(0, 20).map((e) => e.toRadixString(16)).join(' ')}');
        }
      }

      return null;
    }, const []);

    // Hàm để kiểm tra và tải PDF từ URL nếu cần
    Future<Uint8List?> loadPdfFromUrl() async {
      if (pdfUrl == null) return null;

      try {
        print('Tải PDF từ URL: $pdfUrl');
        final response = await http.get(Uri.parse(pdfUrl!));

        if (response.statusCode == 200) {
          final contentType = response.headers['content-type'];
          print('Content-Type: $contentType');

          if (contentType?.contains('application/pdf') == true ||
              contentType?.contains('application/octet-stream') == true) {
            // Kiểm tra signature PDF
            if (response.bodyBytes.length > 4) {
              final signature =
                  String.fromCharCodes(response.bodyBytes.sublist(0, 4));
              print('PDF signature từ URL: $signature');
              if (signature != '%PDF') {
                error.value = 'Dữ liệu tải về không phải là PDF';
                return null;
              }
            }
            return response.bodyBytes;
          } else {
            error.value = 'Server trả về sai kiểu dữ liệu: $contentType';
            return null;
          }
        } else {
          error.value =
              'Lỗi tải PDF: ${response.statusCode} - ${response.body}';
          return null;
        }
      } catch (e) {
        error.value = 'Lỗi khi tải PDF: $e';
        return null;
      }
    }

    // Hàm để tải PDF
    Future<void> downloadPdf() async {
      try {
        isLoading.value = true;

        if (kIsWeb) {
          if (pdfBytes != null) {
            _downloadBytesOnWeb(pdfBytes!, _extractFileName(filePath));
          } else if (pdfUrl != null) {
            final pdfData = await loadPdfFromUrl();
            if (pdfData != null) {
              _downloadBytesOnWeb(pdfData, _extractFileName(pdfUrl!));
            } else {
              throw Exception('Không thể tải PDF từ URL');
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

      if (error.value != null) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_extractFileName(filePath)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  error.value = null;
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Lỗi khi hiển thị PDF',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SelectableText(
                      error.value!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pdfUrl != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Mở trong trình duyệt'),
                      onPressed: () {
                        html.window.open(pdfUrl!, '_blank');
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            _extractFileName(filePath),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            // Bỏ nút tải pdf
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: pdfBytes != null
                    ? SimpleWebPdfViewer(pdfBytes: pdfBytes)
                    : pdfUrl != null
                        ? SimpleWebPdfViewer(pdfUrl: pdfUrl)
                        : FutureBuilder<Uint8List?>(
                            future: loadPdfFromUrl(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                error.value = 'Lỗi tải PDF: ${snapshot.error}';
                                return Center(
                                  child: Text('Lỗi: ${snapshot.error}'),
                                );
                              } else if (snapshot.hasData &&
                                  snapshot.data != null) {
                                return SimpleWebPdfViewer(
                                    pdfBytes: snapshot.data);
                              } else {
                                return const Center(
                                  child:
                                      Text('Không có dữ liệu PDF để hiển thị'),
                                );
                              }
                            },
                          ),
              ),
              if (isLoading.value) const LinearProgressIndicator(),
            ],
          ),
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
            // Bỏ nút tải PDF
          ],
        ),
        body: SafeArea(
          child: Column(
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
                          print('PDFView error: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        onViewCreated: (_) {
                          // Đặt trạng thái isReady thành false trong trường hợp cần tải lại
                          if (!isReady.value) {
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              if (!isReady.value) {
                                isReady.value = true;
                              }
                            });
                          }
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              if (isLoading.value) const LinearProgressIndicator(),
            ],
          ),
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
