import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PdfData {
  final String fileName;
  final String? filePath; // Đường dẫn cho mobile
  final Uint8List? bytes; // Bytes cho web
  final String? webUrl; // URL cho web (optional)

  PdfData({
    required this.fileName,
    this.filePath,
    this.bytes,
    this.webUrl,
  });
}

class ConversionService {
  // URL cho backend Python - sử dụng getter để trả về URL theo nền tảng
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

  /// Chuyển đổi file DOCX sang PDF trên thiết bị di động
  ///
  /// Trả về đường dẫn tới file PDF đã chuyển đổi nếu thành công
  /// Ném ra ngoại lệ nếu xảy ra lỗi
  Future<String> convertDocxToPdf(File docxFile) async {
    try {
      final url = Uri.parse('$baseUrl/convert');

      // Tạo request multipart
      final request = http.MultipartRequest('POST', url);

      // Thêm file vào request
      final fileStream = http.ByteStream(docxFile.openRead());
      final fileLength = await docxFile.length();

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: path.basename(docxFile.path),
      );

      request.files.add(multipartFile);

      // Gửi request
      final streamedResponse = await request.send();

      // Kiểm tra status code và headers
      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw Exception(
            'Lỗi API: ${streamedResponse.statusCode} - $responseBody');
      }

      // Kiểm tra Content-Type
      final contentType = streamedResponse.headers['content-type'];
      if (contentType == null || !contentType.contains('application/pdf')) {
        throw Exception('Phản hồi không phải là PDF: $contentType');
      }

      // Lưu file PDF vào bộ nhớ thiết bị
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(docxFile.path);
      final pdfFile = File('${tempDir.path}/$fileName.pdf');

      final fileBytes = await streamedResponse.stream.toBytes();

      // Kiểm tra nếu không có bytes
      if (fileBytes.isEmpty) {
        throw Exception('Không nhận được dữ liệu PDF từ server');
      }

      await pdfFile.writeAsBytes(fileBytes);

      // Kiểm tra file đã tồn tại
      if (!await pdfFile.exists()) {
        throw Exception('Không thể lưu file PDF');
      }

      return pdfFile.path;
    } catch (e) {
      throw Exception('Lỗi khi chuyển đổi file: $e');
    }
  }

  /// Chuyển đổi bytes của file DOCX sang PDF trên nền tảng web
  ///
  /// Trả về đối tượng PdfData chứa thông tin file PDF đã chuyển đổi
  /// Ném ra ngoại lệ nếu xảy ra lỗi
  Future<PdfData> convertDocxBytesToPdf(
      Uint8List bytes, String fileName) async {
    try {
      final url = Uri.parse('$baseUrl/convert');

      // Ghi log tên file gốc
      print('Tên file gốc: $fileName');

      // Tạo request multipart
      final request = http.MultipartRequest('POST', url);

      // Thêm bytes vào request
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      );

      request.files.add(multipartFile);

      // Thêm headers cho CORS
      request.headers['Access-Control-Allow-Origin'] = '*';

      // Gửi request
      final streamedResponse = await request.send();

      // Kiểm tra status code
      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw Exception(
            'Lỗi API: ${streamedResponse.statusCode} - $responseBody');
      }

      // Ghi log headers để debug
      print('Response headers: ${streamedResponse.headers}');

      // Kiểm tra Content-Type
      final contentType = streamedResponse.headers['content-type'];
      if (contentType == null || !contentType.contains('application/pdf')) {
        throw Exception('Phản hồi không phải là PDF: $contentType');
      }

      // Lấy bytes của PDF đã chuyển đổi
      final pdfBytes = await streamedResponse.stream.toBytes();

      // Kiểm tra nếu không có bytes
      if (pdfBytes.isEmpty) {
        throw Exception('Không nhận được dữ liệu PDF từ server');
      }

      // Kiểm tra signature PDF
      if (pdfBytes.length > 4) {
        final signature = String.fromCharCodes(pdfBytes.sublist(0, 4));
        print('PDF signature: $signature');
        if (signature != '%PDF') {
          print('CẢNH BÁO: Dữ liệu không bắt đầu bằng signature PDF');
          print('Bytes đầu: ${pdfBytes.sublist(0, 20)}');
        }
      }

      // Trên web, chúng ta trả về cả bytes để hiển thị và lưu
      final newFileName = fileName.replaceAll('.docx', '.pdf');
      print('Tên file PDF: $newFileName');

      // Lấy URL xem PDF từ header nếu có
      String? pdfViewUrl;
      if (streamedResponse.headers.containsKey('x-pdf-view-url')) {
        final urlPath = streamedResponse.headers['x-pdf-view-url']!;
        pdfViewUrl = '$baseUrl$urlPath';
        print('URL xem PDF: $pdfViewUrl');

        // Kiểm tra URL có thể truy cập được không
        try {
          final testRequest = http.Request('GET', Uri.parse(pdfViewUrl));
          final testResponse = await http.Client().send(testRequest);

          if (testResponse.statusCode != 200) {
            print(
                'CẢNH BÁO: URL PDF không thể truy cập: ${testResponse.statusCode}');
            // Không đặt null, vẫn thử sử dụng URL này
          } else {
            print('URL PDF có thể truy cập được!');
          }
        } catch (e) {
          print('Lỗi khi kiểm tra URL: $e');
          // Không đặt null, vẫn thử sử dụng URL này
        }
      } else {
        print('Không tìm thấy x-pdf-view-url trong headers');
        print('Tất cả headers: ${streamedResponse.headers}');
      }

      return PdfData(
        fileName: newFileName,
        bytes: pdfBytes,
        webUrl: pdfViewUrl,
      );
    } catch (e) {
      print('Lỗi chi tiết: $e');
      throw Exception('Lỗi khi chuyển đổi file trên web: $e');
    }
  }
}
