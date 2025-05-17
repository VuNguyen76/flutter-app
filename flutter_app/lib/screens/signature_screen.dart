import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/pdf_viewer.dart';
import '../services/signature_service.dart';
import '../models/document_model.dart';
import 'dart:typed_data';
import 'package:signature/signature.dart';

class SignatureScreen extends StatefulWidget {
  final String? pdfId;
  final String? pdfUrl;
  final Uint8List? pdfBytes;
  final String filePath;

  const SignatureScreen({
    Key? key,
    this.pdfId,
    this.pdfUrl,
    this.pdfBytes,
    required this.filePath,
  }) : super(key: key);

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  bool _isLoading = false;
  bool _isSigning = false;
  String? _error;
  String? _signedPdfUrl;
  String? _signedPdfId;

  // Signature data
  String? _signatureAData;
  String? _signatureAName;
  String? _signatureBData;
  String? _signatureBName;

  final _signatureService = SignatureService();

  Future<void> _handleSignature() async {
    if (_signatureAData == null && _signatureBData == null) {
      setState(() {
        _error = 'Vui lòng ký ít nhất một chữ ký';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSigning = true;
      _error = null;
    });

    try {
      // Sử dụng SignatureService để ký PDF
      final result = await _signatureService.signPdf(
        pdfId: widget.pdfId ?? 'local_pdf',
        signatureAData: _signatureAData,
        signatureAName: _signatureAName,
        signatureBData: _signatureBData,
        signatureBName: _signatureBName,
        pdfBytes: widget.pdfBytes,
        pdfFilename: widget.filePath,
      );

      setState(() {
        _signedPdfUrl = result.fullViewUrl;
        _signedPdfId = result.pdfId;
        _isSigning = false;
      });

      print('Đã ký PDF thành công: ${result.message}');
      print('URL để xem PDF đã ký: $_signedPdfUrl');
    } catch (e) {
      setState(() {
        _error = 'Lỗi khi ký PDF: $e';
        _isSigning = false;
      });
      print('Lỗi khi ký PDF: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setSignatureA(String data, String name) {
    setState(() {
      _signatureAData = data;
      _signatureAName = name;
    });
  }

  void _setSignatureB(String data, String name) {
    setState(() {
      _signatureBData = data;
      _signatureBName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Nếu đã ký, trả về kết quả với trạng thái đã ký
        if (_signedPdfId != null) {
          Navigator.of(context).pop({
            'pdfId': _signedPdfId,
            'signed': true,
            'url': _signedPdfUrl,
          });
          return false; // Ngăn không cho pop mặc định vì chúng ta đã xử lý
        }
        return true; // Cho phép pop mặc định nếu chưa ký
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              _signedPdfUrl != null ? 'Tài liệu đã ký' : 'Ký tài liệu PDF'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Nếu đã ký, trả về thông tin đã ký
              if (_signedPdfId != null) {
                Navigator.of(context).pop({
                  'pdfId': _signedPdfId,
                  'signed': true,
                  'url': _signedPdfUrl,
                });
              } else {
                Navigator.of(context).pop(); // Quay lại nếu chưa ký
              }
            },
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _signedPdfUrl != null
                  ? _buildSignedPdfView()
                  : _buildSignatureForm(),
        ),
      ),
    );
  }

  Widget _buildSignedPdfView() {
    return Column(
      children: [
        Expanded(
          child: PdfViewer(
            filePath: widget.filePath,
            pdfUrl: _signedPdfUrl,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureForm() {
    // Lấy kích thước màn hình để làm responsive
    final size = MediaQuery.of(context).size;
    final maxPreviewHeight =
        size.height * 0.3; // Giới hạn chiều cao của preview PDF

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview PDF với chiều cao tự thích ứng
          Container(
            height: maxPreviewHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.pdfBytes != null
                ? PdfViewer(
                    filePath: widget.filePath,
                    pdfBytes: widget.pdfBytes,
                  )
                : widget.pdfUrl != null
                    ? PdfViewer(
                        filePath: widget.filePath,
                        pdfUrl: widget.pdfUrl,
                      )
                    : const Center(
                        child: Text('Không có dữ liệu PDF để hiển thị'),
                      ),
          ),

          const SizedBox(height: 16),

          // Signature Form
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          const Text(
            'Chữ ký các bên',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Bên A
          _buildSignatureSection(
            title: 'Bên A',
            signatureData: _signatureAData,
            signatureName: _signatureAName,
            onSign: (data, name) => _setSignatureA(data, name),
          ),

          const SizedBox(height: 16),

          // Bên B
          _buildSignatureSection(
            title: 'Bên B',
            signatureData: _signatureBData,
            signatureName: _signatureBName,
            onSign: (data, name) => _setSignatureB(data, name),
          ),

          const SizedBox(height: 24),

          // Button for signing
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Ký tài liệu'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: _isSigning ? null : _handleSignature,
            ),
          ),

          // Thêm padding dưới để tránh bị overflow
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSignatureSection({
    required String title,
    required String? signatureData,
    required String? signatureName,
    required Function(String, String) onSign,
  }) {
    String displayName = "Chưa có tên";
    if (signatureName != null && signatureName.isNotEmpty) {
      displayName = signatureName;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 12),
          if (signatureData != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120, // Giảm chiều cao của khung chữ ký đã ký
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _convertSignatureDataToUint8List(signatureData),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Người ký: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Sửa chữ ký'),
                      onPressed: () => _showSignatureDialog(
                        context: context,
                        title: 'Chữ ký $title',
                        initialName: signatureName,
                        onSign: onSign,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24), // Giảm padding
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.draw_outlined,
                    size: 40, // Giảm kích thước icon
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có chữ ký',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.draw),
                    label: const Text('Thêm chữ ký'),
                    onPressed: () => _showSignatureDialog(
                      context: context,
                      title: 'Chữ ký $title',
                      onSign: onSign,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSignatureDialog({
    required BuildContext context,
    required String title,
    String? initialName,
    required Function(String, String) onSign,
  }) {
    final SignatureController _controller = SignatureController(
      penStrokeWidth: 5, // Giảm độ dày của nét ký
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final TextEditingController _nameController =
        TextEditingController(text: initialName);

    // Lấy kích thước màn hình để làm responsive
    final size = MediaQuery.of(context).size;
    final signatureHeight = size.height * 0.3; // Tối đa 30% chiều cao màn hình

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text("Vẽ chữ ký của bạn vào ô bên dưới:"),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: signatureHeight,
                    child: Signature(
                      controller: _controller,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Xóa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade800,
                      ),
                      onPressed: () => _controller.clear(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tên người ký',
                    hintText: 'Nhập tên của bạn',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (_controller.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Vui lòng ký trước khi xác nhận')),
                          );
                          return;
                        }

                        try {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          final signatureBytes = await _controller.toPngBytes(
                            height: 600,
                            width: 800,
                          );

                          Navigator.of(context).pop();

                          if (signatureBytes == null) {
                            throw Exception('Không thể xuất chữ ký');
                          }

                          final base64Image = base64Encode(signatureBytes);
                          final signatureData =
                              'data:image/png;base64,$base64Image';

                          String name = _nameController.text.trim();
                          if (name.isEmpty) {
                            name = "Không có tên";
                          } else if (name.length > 1) {
                            name = name.split(' ').map((word) {
                              if (word.isEmpty) return word;
                              if (word.length == 1) return word.toUpperCase();
                              return word[0].toUpperCase() + word.substring(1);
                            }).join(' ');
                          }

                          onSign(signatureData, name);
                          Navigator.of(context).pop();
                        } catch (e) {
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi khi xử lý chữ ký: $e')),
                          );
                        }
                      },
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Uint8List _convertSignatureDataToUint8List(String data) {
    try {
      // Parse data URL format: data:image/png;base64,<data>
      if (data.startsWith('data:')) {
        final split = data.split(',');
        if (split.length != 2) {
          print('Định dạng data URL không hợp lệ');
          throw Exception('Định dạng data URL không hợp lệ');
        }

        final base64String = split[1];
        try {
          final decoded = base64Decode(base64String);
          if (decoded.isEmpty) {
            throw Exception('Dữ liệu base64 giải mã rỗng');
          }
          return decoded;
        } catch (e) {
          print('Lỗi khi decode base64: $e');
          throw Exception('Không thể giải mã dữ liệu base64');
        }
      } else {
        print('Định dạng dữ liệu chữ ký không hợp lệ: không phải data URL');
        throw Exception('Định dạng dữ liệu chữ ký không hợp lệ');
      }
    } catch (e) {
      print('Lỗi khi chuyển đổi chữ ký: $e');
      // Tạo một hình ảnh đơn giản với chữ "Chữ ký không hợp lệ" để hiển thị
      return _createErrorSignatureImage();
    }
  }

  // Phương thức tạo hình ảnh lỗi đơn giản - trả về Uint8List của một hình ảnh PNG 1x1
  Uint8List _createErrorSignatureImage() {
    // Đây là dữ liệu của một PNG 1x1 pixel màu đỏ
    return Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      2,
      0,
      0,
      0,
      144,
      119,
      83,
      222,
      0,
      0,
      0,
      1,
      115,
      82,
      71,
      66,
      0,
      174,
      206,
      28,
      233,
      0,
      0,
      0,
      4,
      103,
      65,
      77,
      65,
      0,
      0,
      177,
      143,
      11,
      252,
      97,
      5,
      0,
      0,
      0,
      9,
      112,
      72,
      89,
      115,
      0,
      0,
      14,
      195,
      0,
      0,
      14,
      195,
      1,
      199,
      111,
      168,
      100,
      0,
      0,
      0,
      12,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      96,
      96,
      96,
      0,
      0,
      0,
      4,
      0,
      1,
      218,
      169,
      39,
      208,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130
    ]);
  }

  // Hàm xử lý khi người dùng hoàn tất ký (đã tự động được gọi)
  void _onCompleteSigning() {
    if (_signedPdfId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng ký tài liệu trước khi hoàn tất')),
      );
      return;
    }

    // Trả về kết quả để đánh dấu tài liệu đã ký
    Navigator.of(context).pop({
      'pdfId': _signedPdfId,
      'signed': true,
      'url': _signedPdfUrl,
    });
  }
}
