import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/document_model.dart';

class SignatureService {
  /// URL cho backend Python - sử dụng getter để trả về URL theo nền tảng
  static String get baseUrl {
    // Trên web, cần sử dụng IP thay vì localhost
    if (kIsWeb) {
      // Sử dụng địa chỉ IP thay vì localhost để trình duyệt có thể kết nối
      return 'http://127.0.0.1:1046';
    } else {
      // Trên mobile, localhost vẫn hoạt động tốt
      return 'http://localhost:1046';
    }
  }

  /// Gửi chữ ký để thêm vào PDF
  /// Trả về thông tin về file PDF đã ký
  Future<SignedPdfResult> signPdf({
    required String pdfId,
    String? signatureAData,
    String? signatureAName,
    String? signatureBData,
    String? signatureBName,
    Uint8List? pdfBytes,
    String? pdfFilename,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/sign-pdf');
      print('Gửi request ký PDF đến: $url');

      // Tạo form data
      var request = http.MultipartRequest('POST', url);

      // Thêm PDF ID
      request.fields['pdf_id'] = pdfId;
      print('Đã thêm pdf_id: $pdfId vào request');

      // Thêm chữ ký A nếu có
      if (signatureAData != null) {
        request.fields['signature_a_data'] = signatureAData;
        print('Đã thêm signature_a_data vào request');
      }

      // Thêm tên người ký A nếu có
      if (signatureAName != null) {
        request.fields['signature_a_name'] = signatureAName;
        print('Đã thêm signature_a_name: $signatureAName vào request');
      }

      // Thêm chữ ký B nếu có
      if (signatureBData != null) {
        request.fields['signature_b_data'] = signatureBData;
        print('Đã thêm signature_b_data vào request');
      }

      // Thêm tên người ký B nếu có
      if (signatureBName != null) {
        request.fields['signature_b_name'] = signatureBName;
        print('Đã thêm signature_b_name: $signatureBName vào request');
      }

      // Kiểm tra xem pdfId có phải là ID tự tạo (local) không
      // Nếu là ID tự tạo và có dữ liệu PDF, thêm file PDF vào request
      if (pdfId.startsWith('local_') &&
          pdfBytes != null &&
          pdfFilename != null) {
        print('Phát hiện PDF ID tự tạo, tải lên file PDF để ký');
        // Thêm file PDF vào request
        final pdfFile = http.MultipartFile.fromBytes(
          'file',
          pdfBytes,
          filename: pdfFilename,
          contentType: MediaType('application', 'pdf'),
        );
        request.files.add(pdfFile);
        print(
            'Đã thêm file PDF vào request: ${pdfFile.filename}, kích thước: ${pdfBytes.length} bytes');
      }

      // Gửi request
      print('Đang gửi request ký PDF...');
      final response = await request.send();

      // Kiểm tra status code
      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        print('Nhận phản hồi lỗi: ${response.statusCode} - $responseBody');
        throw Exception('Lỗi API: ${response.statusCode} - $responseBody');
      }

      // Parse response
      final responseData = await response.stream.bytesToString();

      // Parse JSON
      print('Response from sign-pdf: $responseData');

      // Sử dụng jsonDecode để parse JSON
      final parsedJson = jsonDecode(responseData);

      // Tạo SignedPdfResult từ Map
      final result = SignedPdfResult(
        message: parsedJson['message'] ?? 'PDF đã được ký',
        pdfId: parsedJson['pdf_id'] ?? '',
        viewUrl: parsedJson['view_url'] ?? '',
      );

      return result;
    } catch (e) {
      print('Lỗi chi tiết khi ký PDF: $e');
      throw Exception('Lỗi khi ký PDF: $e');
    }
  }
}

class SignedPdfResult {
  final String message;
  final String pdfId;
  final String viewUrl;

  SignedPdfResult({
    required this.message,
    required this.pdfId,
    required this.viewUrl,
  });

  factory SignedPdfResult.fromJson(String jsonStr) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);

      return SignedPdfResult(
        message: parsed['message'] ?? 'PDF đã được ký',
        pdfId: parsed['pdf_id'] ?? '',
        viewUrl: parsed['view_url'] ?? '',
      );
    } catch (e) {
      print('Lỗi khi parse JSON: $e');
      throw Exception('Lỗi khi parse dữ liệu JSON: $e');
    }
  }

  String get fullViewUrl {
    return '${SignatureService.baseUrl}$viewUrl';
  }
}
