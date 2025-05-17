import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/pdf_viewer.dart';
import '../services/signature_service.dart';
import '../models/document_model.dart';
import 'dart:typed_data';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ký tài liệu PDF'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _signedPdfUrl != null
              ? _buildSignedPdfView()
              : _buildSignatureForm(),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.draw),
                label: const Text('Ký lại'),
                onPressed: () {
                  setState(() {
                    _signedPdfUrl = null;
                    _signedPdfId = null;
                  });
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Hoàn thành'),
                onPressed: () {
                  Navigator.of(context).pop(_signedPdfId);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview PDF
          Container(
            height: 300,
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

          const SizedBox(height: 24),

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

          const SizedBox(height: 24),

          // Bên B
          _buildSignatureSection(
            title: 'Bên B',
            signatureData: _signatureBData,
            signatureName: _signatureBName,
            onSign: (data, name) => _setSignatureB(data, name),
          ),

          const SizedBox(height: 32),

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (signatureData != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.memory(
                    _convertSignatureDataToUint8List(signatureData),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Người ký: ${signatureName ?? "Chưa có tên"}'),
                const SizedBox(height: 8),
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
            )
          else
            TextButton.icon(
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
    );
  }

  void _showSignatureDialog({
    required BuildContext context,
    required String title,
    String? initialName,
    required Function(String, String) onSign,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Signature pad would be here
              Container(
                height: 200,
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                // For this example, we're just using a placeholder
                child: const Center(
                  child: Text('Vùng ký (Placeholder)'),
                ),
              ),

              const SizedBox(height: 16),

              // Name input
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Tên người ký',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: initialName),
                onChanged: (value) {
                  initialName = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              // For this example, we're just using a placeholder signature data
              final signatureData = 'data:image/png;base64,iVBORw0KG...';
              onSign(signatureData, initialName ?? '');
              Navigator.of(context).pop();
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Uint8List _convertSignatureDataToUint8List(String data) {
    try {
      // Parse data URL format: data:image/png;base64,<data>
      if (data.startsWith('data:')) {
        final base64String = data.split(',')[1];
        return base64Decode(base64String);
      } else {
        print('Invalid signature data format');
        // Return a simple 1x1 transparent pixel to avoid crash
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
          6,
          0,
          0,
          0,
          31,
          21,
          196,
          137,
          0,
          0,
          0,
          13,
          73,
          68,
          65,
          84,
          120,
          218,
          99,
          252,
          207,
          192,
          0,
          0,
          3,
          1,
          1,
          0,
          242,
          213,
          89,
          108,
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
    } catch (e) {
      print('Error decoding signature data: $e');
      // Return a simple 1x1 transparent pixel to avoid crash
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
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        13,
        73,
        68,
        65,
        84,
        120,
        218,
        99,
        252,
        207,
        192,
        0,
        0,
        3,
        1,
        1,
        0,
        242,
        213,
        89,
        108,
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
  }
}
