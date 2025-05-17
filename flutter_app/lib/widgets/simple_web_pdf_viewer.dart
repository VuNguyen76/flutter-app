import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:ui_web' as ui_web;

/// Widget đơn giản để hiển thị PDF trên web với các tùy chọn dự phòng
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
  late String _pdfUrl;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  final String _uniqueViewerId =
      DateTime.now().millisecondsSinceEpoch.toString();

  // Các chế độ xem PDF
  bool _useDirectIframe = false;
  bool _useGoogleViewer = false;
  bool _useMicrosoftViewer = false;

  // Trạng thái trình duyệt
  late final Map<String, bool> _browserInfo;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-view-$_uniqueViewerId';
    _initBrowserInfo();
    _initializeViewer();
  }

  /// Khởi tạo thông tin về trình duyệt
  void _initBrowserInfo() {
    _browserInfo = {};
    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();

      // Xác định trình duyệt
      _browserInfo['isChrome'] =
          userAgent.contains('chrome') && !userAgent.contains('edge');
      _browserInfo['isEdge'] = userAgent.contains('edg');
      _browserInfo['isFirefox'] = userAgent.contains('firefox');
      _browserInfo['isSafari'] =
          userAgent.contains('safari') && !userAgent.contains('chrome');
      _browserInfo['isIE'] =
          userAgent.contains('trident') || userAgent.contains('msie');
      _browserInfo['isOpera'] = userAgent.contains('opr');

      // Platform
      _browserInfo['isWindows'] = userAgent.contains('windows');
      _browserInfo['isMac'] = userAgent.contains('mac');
      _browserInfo['isLinux'] = userAgent.contains('linux');
      _browserInfo['isAndroid'] = userAgent.contains('android');
      _browserInfo['isIOS'] =
          userAgent.contains('iphone') || userAgent.contains('ipad');

      // Log thông tin
      print(
          'DEBUG: Thông tin trình duyệt: ${_browserInfo.entries.where((e) => e.value).map((e) => e.key).join(', ')}');
    } catch (e) {
      print('Lỗi khi xác định trình duyệt: $e');
      _browserInfo['unknown'] = true;
    }

    // Quyết định chế độ xem dựa trên trình duyệt
    _decideViewingMode();
  }

  /// Quyết định chế độ xem PDF dựa trên trình duyệt
  void _decideViewingMode() {
    // Always use direct iframe for all browsers
    _useDirectIframe = true;
    _useGoogleViewer = false;
    _useMicrosoftViewer = false;

    print('DEBUG: Chế độ xem PDF: sử dụng iframe trực tiếp');
  }

  /// Khởi tạo PDF viewer
  void _initializeViewer() {
    try {
      setState(() {
        _isInitialized = false;
        _isLoading = true;
        _error = null;
      });

      // Xử lý URL hoặc bytes
      if (widget.pdfUrl != null) {
        _pdfUrl = widget.pdfUrl!;
        print('DEBUG: Sử dụng URL PDF được cung cấp: $_pdfUrl');

        final uri = Uri.tryParse(_pdfUrl);
        if (uri == null) {
          setState(() {
            _error = 'URL PDF không hợp lệ';
          });
          return;
        }

        // Các tham số bổ sung để đảm bảo cache không gây vấn đề
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (_pdfUrl.contains('?')) {
          _pdfUrl = '$_pdfUrl&_t=$timestamp';
        } else {
          _pdfUrl = '$_pdfUrl?_t=$timestamp';
        }
      } else if (widget.pdfBytes != null) {
        if (widget.pdfBytes!.isEmpty) {
          setState(() {
            _error = 'PDF bytes trống';
          });
          return;
        }

        // Kiểm tra PDF signature
        if (widget.pdfBytes!.length > 4) {
          final header = widget.pdfBytes!.sublist(0, 4);
          final headerString = String.fromCharCodes(header);
          final headerHex =
              header.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

          print('DEBUG: PDF header: $headerString (hex: $headerHex)');

          if (!headerString.startsWith('%PDF')) {
            print(
                'CẢNH BÁO: Không tìm thấy PDF signature trong bytes: $headerHex');
          }
        }

        // Tạo Blob URL thay vì base64 để cải thiện hiệu suất
        try {
          final blob = html.Blob([widget.pdfBytes!], 'application/pdf');
          _pdfUrl = html.Url.createObjectUrlFromBlob(blob);
          print('DEBUG: Đã tạo Blob URL cho PDF: $_pdfUrl');
        } catch (blobError) {
          print('Lỗi khi tạo Blob URL: $blobError, sử dụng Base64 thay thế');
          // Fallback to base64 if blob fails
          final base64 = base64Encode(widget.pdfBytes!);
          _pdfUrl = 'data:application/pdf;base64,$base64';
          print('DEBUG: Đã tạo Base64 URL cho PDF (độ dài: ${base64.length})');
        }
      } else {
        setState(() {
          _error = 'Không có dữ liệu PDF';
        });
        return;
      }

      // Đăng ký factory cho HTML element
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        try {
          // Tạo div container
          final container = html.DivElement()
            ..id = 'pdf-container-$_uniqueViewerId'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.overflow = 'hidden'
            ..style.border = 'none'
            ..style.position = 'relative';

          // Luôn sử dụng iframe trực tiếp
          print('DEBUG: Sử dụng iframe trực tiếp');
          _createDirectIframe(container);

          return container;
        } catch (e) {
          print('Lỗi khi tạo PDF viewer HTML: $e');
          setState(() {
            _error = 'Lỗi tạo viewer: $e';
          });
          return html.DivElement()..text = 'Lỗi: $e';
        }
      });

      // Đánh dấu đã khởi tạo sau một khoảng thời gian nhỏ để đảm bảo HTML element được tạo
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Lỗi khởi tạo PDF viewer: $e');
      setState(() {
        _error = 'Lỗi: $e';
        _isInitialized = false;
        _isLoading = false;
      });
    }
  }

  /// Tạo iframe để xem PDF trực tiếp
  void _createDirectIframe(html.DivElement container) {
    try {
      // Tạo iframe cho xem PDF trực tiếp
      final iframe = html.IFrameElement()
        ..src = _pdfUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'auto'
        ..setAttribute('type', 'application/pdf')
        ..setAttribute('title', 'PDF Viewer')
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('webkitallowfullscreen', 'true')
        ..setAttribute('mozallowfullscreen', 'true')
        ..id = 'pdf-iframe-$_uniqueViewerId';

      // Bắt sự kiện load để phát hiện lỗi
      iframe.onLoad.listen((event) {
        print('DEBUG: iframe đã tải xong');
      });

      iframe.onError.listen((event) {
        print('DEBUG: Lỗi khi tải iframe: $event');
      });

      // Thêm iframe vào container
      container.children.add(iframe);

      // Thêm một lớp overlay để kiểm tra xem iframe có hiển thị được không
      final overlay = html.DivElement()
        ..id = 'pdf-overlay-$_uniqueViewerId'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.display = 'none'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.backgroundColor = 'rgba(255, 255, 255, 0.9)';

      final overlayContent = html.DivElement()
        ..style.textAlign = 'center'
        ..style.padding = '20px';

      final overlayText = html.ParagraphElement()
        ..text = 'Không thể hiển thị PDF trực tiếp. Vui lòng mở trong tab mới:'
        ..style.marginBottom = '15px'
        ..style.color = 'red';

      overlayContent.children.add(overlayText);

      final openNewTabBtn = html.ButtonElement()
        ..text = 'Mở trong tab mới'
        ..style.margin = '5px'
        ..style.padding = '8px 12px'
        ..style.border = '1px solid #ccc'
        ..style.backgroundColor = '#f0f0f0'
        ..style.cursor = 'pointer';

      openNewTabBtn.addEventListener('click', (event) {
        event.preventDefault();
        html.window.open(_pdfUrl, '_blank');
      });

      overlayContent.children.add(openNewTabBtn);
      overlay.children.add(overlayContent);

      container.children.add(overlay);

      // Sau 3 giây kiểm tra xem iframe có hiển thị được không
      Future.delayed(const Duration(seconds: 3), () {
        try {
          // Kiểm tra trạng thái iframe
          if (iframe.contentWindow == null) {
            print(
                'DEBUG: iframe không có nội dung sau 3 giây, hiển thị overlay');
            overlay.style.display = 'flex';
          }
        } catch (e) {
          print('DEBUG: Lỗi khi kiểm tra iframe: $e');
        }
      });
    } catch (e) {
      print('DEBUG: Lỗi khi tạo iframe trực tiếp: $e');
      // Thêm một thông báo lỗi vào container
      container.children.add(html.ParagraphElement()
        ..text = 'Lỗi khi hiển thị PDF: $e'
        ..style.color = 'red'
        ..style.padding = '10px');
    }
  }

  @override
  void dispose() {
    // Giải phóng URL nếu đã tạo từ Blob
    if (widget.pdfBytes != null && _pdfUrl.startsWith('blob:')) {
      try {
        html.Url.revokeObjectUrl(_pdfUrl);
        print('DEBUG: Đã giải phóng Blob URL: $_pdfUrl');
      } catch (e) {
        print('Lỗi khi giải phóng URL: $e');
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SimpleWebPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kiểm tra nếu dữ liệu PDF thay đổi, khởi tạo lại viewer
    if ((oldWidget.pdfBytes != widget.pdfBytes) ||
        (oldWidget.pdfUrl != widget.pdfUrl)) {
      print('DEBUG: Dữ liệu PDF đã thay đổi, khởi tạo lại viewer');
      _initializeViewer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: HtmlElementView(
        viewType: _viewId,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Lỗi không xác định',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (_pdfUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở PDF trong tab mới'),
                onPressed: () {
                  html.window.open(_pdfUrl, '_blank');
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Đang tải PDF...'),
          if (_pdfUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở trong tab mới'),
                    onPressed: () {
                      html.window.open(_pdfUrl, '_blank');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
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
          'target', '_blank'); // Tránh các vấn đề với một số trình duyệt

    // Kích hoạt download
    anchor.click();

    // Giải phóng URL sau một khoảng thời gian ngắn
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
