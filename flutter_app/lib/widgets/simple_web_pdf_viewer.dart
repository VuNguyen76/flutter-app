import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:ui_web' as ui_web;

/// Widget đơn giản để hiển thị PDF trên web
class SimpleWebPdfViewer extends StatefulWidget {
  /// Dữ liệu bytes của PDF
  final Uint8List? pdfBytes;

  /// URL của PDF
  final String? pdfUrl;

  /// Chiều cao của viewer
  final double height;

  /// Chiều rộng của viewer
  final double width;

  /// Constructor
  const SimpleWebPdfViewer({
    super.key,
    this.pdfBytes,
    this.pdfUrl,
    this.height = double.infinity,
    this.width = double.infinity,
  }) : assert(pdfBytes != null || pdfUrl != null,
            'Either pdfBytes or pdfUrl must be provided');

  @override
  State<SimpleWebPdfViewer> createState() => _SimpleWebPdfViewerState();
}

class _SimpleWebPdfViewerState extends State<SimpleWebPdfViewer> {
  late final String _viewId;
  late final String _pdfUrl;
  bool _isInitialized = false;
  String? _error;
  final String _uniqueViewerId =
      DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-view-$_uniqueViewerId';
    _initializeViewer();
  }

  void _initializeViewer() {
    try {
      setState(() {
        _isInitialized = false;
      });

      if (widget.pdfUrl != null) {
        // Ưu tiên sử dụng URL nếu có
        _pdfUrl = widget.pdfUrl!;
        print('Debug: Sử dụng URL PDF được cung cấp: $_pdfUrl');
      } else if (widget.pdfBytes != null) {
        // Sử dụng bytes nếu không có URL
        if (widget.pdfBytes!.isEmpty) {
          setState(() {
            _error = 'PDF bytes trống';
          });
          return;
        }

        // Kiểm tra vài byte đầu tiên để xác nhận đây là PDF
        final header = widget.pdfBytes!.sublist(
            0, widget.pdfBytes!.length > 5 ? 5 : widget.pdfBytes!.length);
        final headerString = String.fromCharCodes(header);
        if (!headerString.startsWith('%PDF')) {
          print(
              'WARNING: Byte đầu tiên không phải là PDF signature: ${header.map((e) => e.toRadixString(16)).join(' ')}');
        }

        // Convert bytes to base64
        final base64 = base64Encode(widget.pdfBytes!);
        _pdfUrl = 'data:application/pdf;base64,$base64';
        print('Debug: Đã tạo data URL cho PDF');
      } else {
        setState(() {
          _error = 'Không có dữ liệu PDF';
        });
        return;
      }

      // Đăng ký factory cho HTML element
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        try {
          print('Debug: Tạo HTML element cho PDF viewer');

          // Tạo div container
          final container = html.DivElement()
            ..id = 'pdf-container-$_uniqueViewerId'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.overflow = 'hidden'
            ..style.border = 'none';

          // Đánh dấu container đã được tạo
          print('Debug: Container đã được tạo với ID: ${container.id}');

          // Tạo iframe cho xem PDF
          final iframe = html.IFrameElement()
            ..src = _pdfUrl
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..setAttribute('type', 'application/pdf')
            ..setAttribute('title', 'PDF Viewer')
            ..setAttribute('allowfullscreen', 'true')
            ..setAttribute('webkitallowfullscreen', 'true')
            ..setAttribute('mozallowfullscreen', 'true');

          // Thêm iframe vào container
          container.children.add(iframe);

          // Thêm fallback cho trình duyệt không hỗ trợ PDF
          final fallbackText = html.ParagraphElement()
            ..text = 'Trình duyệt của bạn không hỗ trợ xem PDF trực tiếp. '
            ..style.display = 'none';

          final fallbackLink = html.AnchorElement()
            ..href = _pdfUrl
            ..target = '_blank'
            ..text = 'Nhấn vào đây để mở PDF'
            ..style.display = 'none';

          container.children.add(fallbackText);
          container.children.add(fallbackLink);

          return container;
        } catch (e) {
          print('Lỗi khi tạo PDF viewer HTML: $e');
          setState(() {
            _error = 'Lỗi tạo viewer: $e';
          });
          return html.DivElement()..text = 'Lỗi: $e';
        }
      });

      // Đánh dấu đã khởi tạo sau một khoảng thời gian nhỏ
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    } catch (e) {
      print('Lỗi khởi tạo PDF viewer: $e');
      setState(() {
        _error = 'Lỗi: $e';
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    // Giải phóng URL nếu được tạo từ bytes và là blob URL
    if (widget.pdfBytes != null && _pdfUrl.startsWith('blob:')) {
      html.Url.revokeObjectUrl(_pdfUrl);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SimpleWebPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Kiểm tra xem đầu vào có thay đổi không
    final urlChanged = widget.pdfUrl != oldWidget.pdfUrl;
    final bytesChanged = widget.pdfBytes != oldWidget.pdfBytes;

    if (urlChanged || bytesChanged) {
      print('Debug: Đầu vào thay đổi, khởi tạo lại viewer');
      _initializeViewer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Lỗi hiển thị PDF',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            if (widget.pdfUrl != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở PDF trong tab mới'),
                onPressed: () {
                  html.window.open(widget.pdfUrl!, '_blank');
                },
              ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải PDF...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              children: [
                HtmlElementView(viewType: _viewId),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
                    tooltip: 'Mở trong tab mới',
                    onPressed: () {
                      html.window.open(_pdfUrl, '_blank');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại'),
                onPressed: _initializeViewer,
              ),
              const SizedBox(width: 16),
              if (widget.pdfUrl != null || _pdfUrl.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở PDF trong tab mới'),
                  onPressed: () {
                    html.window.open(_pdfUrl, '_blank');
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget đơn giản để tải xuống PDF
class PdfDownloadButton extends StatelessWidget {
  /// Dữ liệu bytes của PDF
  final Uint8List pdfBytes;

  /// Tên file khi tải xuống
  final String fileName;

  /// Constructor
  const PdfDownloadButton({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('Tải PDF'),
      onPressed: () {
        try {
          _downloadPdf();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi tải PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _downloadPdf() {
    // Kiểm tra dữ liệu
    if (pdfBytes.isEmpty) {
      throw Exception('Dữ liệu PDF trống');
    }

    // Kiểm tra vài byte đầu tiên để xác nhận đây là PDF
    final header =
        pdfBytes.sublist(0, pdfBytes.length > 5 ? 5 : pdfBytes.length);
    final headerString = String.fromCharCodes(header);
    if (!headerString.startsWith('%PDF')) {
      print(
          'WARNING: File không phải là PDF: ${header.map((e) => e.toRadixString(16)).join(' ')}');

      // Hiển thị vài byte đầu tiên để debug
      final previewBytes =
          pdfBytes.sublist(0, pdfBytes.length > 30 ? 30 : pdfBytes.length);
      print(
          'Preview bytes: ${previewBytes.map((e) => e.toRadixString(16)).join(' ')}');
      print('Preview as text: ${String.fromCharCodes(previewBytes)}');
    }

    // Đảm bảo tên file có đuôi .pdf
    final safeFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

    // Tạo blob với MIME type chính xác
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    print('Đang tải xuống PDF: $safeFileName (${pdfBytes.length} bytes)');

    // Tạo và kích hoạt download
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', safeFileName)
      ..setAttribute(
          'target', '_blank') // Tránh các vấn đề với một số trình duyệt
      ..click();

    // Giải phóng URL sau một khoảng thời gian ngắn
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
