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
      if (widget.pdfUrl != null) {
        // Ưu tiên sử dụng URL nếu có
        _pdfUrl = widget.pdfUrl!;
        print('Debug: Sử dụng URL PDF được cung cấp: $_pdfUrl');
        // Đánh dấu đã sẵn sàng ngay lập tức cho URL trực tiếp
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
          }
        });
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

        final blob = html.Blob([widget.pdfBytes!], 'application/pdf');
        _pdfUrl = html.Url.createObjectUrlFromBlob(blob);

        print('Debug: Đã tạo blob URL cho PDF: $_pdfUrl');
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
            ..style.border = '1px solid #ddd';

          // Đánh dấu container đã được tạo
          print('Debug: Container đã được tạo với ID: ${container.id}');

          // Sử dụng object tag thay vì iframe để hiển thị PDF tốt hơn
          if (widget.pdfUrl != null || !_pdfUrl.startsWith('blob:')) {
            print('Debug: Sử dụng object tag cho URL trực tiếp');
            final object = html.ObjectElement()
              ..type = 'application/pdf'
              ..data = _pdfUrl
              ..style.width = '100%'
              ..style.height = '100%';

            object.onLoad.listen((_) {
              print('Debug: Object đã tải xong');
              if (mounted) {
                setState(() {
                  _isInitialized = true;
                });
              }
            });

            container.children.add(object);
          } else {
            print('Debug: Sử dụng iframe cho blob URL');
            // Tạo iframe trực tiếp cho blob URL
            final iframe = html.IFrameElement()
              ..src = _pdfUrl
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..setAttribute('type', 'application/pdf')
              ..setAttribute('title', 'PDF Viewer');

            iframe.onLoad.listen((_) {
              print('Debug: iframe đã tải xong');
              if (mounted) {
                setState(() {
                  _isInitialized = true;
                });
              }
            });

            container.children.add(iframe);
          }

          // Đánh dấu đã sẵn sàng sau một timeout để đảm bảo
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isInitialized) {
              print('Debug: Force init viewer sau timeout');
              setState(() {
                _isInitialized = true;
              });
            }
          });

          return container;
        } catch (e) {
          print('Lỗi khi tạo PDF viewer HTML: $e');
          setState(() {
            _error = 'Lỗi tạo viewer: $e';
          });
          return html.DivElement()..text = 'Lỗi: $e';
        }
      });
    } catch (e) {
      print('Lỗi khởi tạo PDF viewer: $e');
      setState(() {
        _error = 'Lỗi: $e';
      });
    }
  }

  @override
  void dispose() {
    // Giải phóng URL nếu được tạo từ bytes
    if (widget.pdfBytes != null) {
      html.Url.revokeObjectUrl(_pdfUrl);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Lỗi hiển thị PDF',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_error!, style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải PDF viewer...'),
            // Thêm nút để buộc hiển thị nếu bị kẹt
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitialized = true;
                });
              },
              child: Text('Hiển thị ngay'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewId),
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
