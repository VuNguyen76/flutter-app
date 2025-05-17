import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../services/conversion_service.dart';
import '../screens/signature_screen.dart';

part 'document_provider.g.dart';

@Riverpod(keepAlive: true)
class DocumentNotifier extends _$DocumentNotifier {
  @override
  Future<List<DocumentModel>> build() async {
    return [];
  }

  Future<void> pickAndAddDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
      allowMultiple: false,
      withData: true, // Để đảm bảo lấy được bytes trên web
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      if (kIsWeb) {
        // Xử lý trên nền tảng web
        if (file.bytes != null) {
          final fileName = file.name;
          final isPdf = fileName.toLowerCase().endsWith('.pdf');

          // Tạo đối tượng DocumentModel
          final document = DocumentModel(
            fileName: fileName,
            path: 'web_file', // Giá trị tạm thời cho path trên web
            isPdf: isPdf,
            bytes: file.bytes,
            pdfId: isPdf
                ? _generateTempPdfId(fileName)
                : null, // Tạo ID tạm nếu là PDF
          );

          if (isPdf) {
            print('Tạo PDF ID cho file đã chọn: ${document.pdfId}');
          }

          state = AsyncData([...state.valueOrNull ?? [], document]);
        }
      } else {
        // Xử lý trên nền tảng mobile
        if (file.path != null) {
          // Kiểm tra xem file có phải là PDF hay không
          final isPdf = file.path!.toLowerCase().endsWith('.pdf');
          final document = DocumentModel(
            fileName: file.name,
            path: file.path!,
            isPdf: isPdf,
            pdfId: isPdf
                ? _generateTempPdfId(file.name)
                : null, // Tạo ID tạm nếu là PDF
          );

          if (isPdf) {
            print('Tạo PDF ID cho file đã chọn: ${document.pdfId}');
          }

          state = AsyncData([...state.valueOrNull ?? [], document]);
        }
      }
    }
  }

  // Helper để tạo PDF ID tạm thời cho các file PDF được chọn trực tiếp
  String _generateTempPdfId(String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'local_${timestamp}_${fileName.hashCode}';
  }

  Future<void> convertDocument(int index) async {
    if (state.valueOrNull == null) return;

    final documents = [...state.value!];
    final docToConvert = documents[index];

    // Nếu đã là PDF hoặc đang chuyển đổi, không làm gì cả
    if (docToConvert.isPdf || docToConvert.isConverting) return;

    // Cập nhật trạng thái đang chuyển đổi
    documents[index] = docToConvert.copyWith(isConverting: true, error: null);
    state = AsyncData(documents);

    try {
      final conversionService = ConversionService();

      if (kIsWeb) {
        // Xử lý chuyển đổi trên web
        if (docToConvert.bytes == null) {
          throw Exception('Không có dữ liệu file để chuyển đổi');
        }

        // Chuyển đổi và lấy kết quả
        final pdfData = await conversionService.convertDocxBytesToPdf(
          docToConvert.bytes!,
          docToConvert.fileName,
        );

        // Log URL nếu có
        if (pdfData.webUrl != null) {
          print('URL PDF để xem: ${pdfData.webUrl}');
        } else {
          print('Không có URL PDF trực tiếp, sẽ sử dụng blob URL');
        }

        // Lấy PDF ID từ response
        String? pdfId = pdfData.pdfId;
        if (pdfId != null && pdfId.isNotEmpty) {
          print('Nhận được PDF ID từ server: $pdfId');
        } else {
          // Tạo PDF ID nếu không có từ server
          pdfId = _generateTempPdfId(docToConvert.fileName);
          print('Không nhận được PDF ID từ server, tạo ID tạm: $pdfId');
        }

        // Cập nhật trạng thái đã chuyển đổi thành công
        documents[index] = docToConvert.copyWith(
          isConverting: false,
          isConverted: true,
          pdfBytes: pdfData.bytes,
          pdfPath: 'web_pdf', // Giá trị giả lập cho path khi trên web
          webUrl: pdfData.webUrl, // Lưu URL để xem trực tiếp
          pdfId: pdfId, // Lưu PDF ID cho việc ký tên
        );

        print('Đã cập nhật document với pdfId: ${documents[index].pdfId}');
      } else {
        // Xử lý chuyển đổi trên mobile
        final pdfData = await conversionService.convertDocxToPdf(
          File(docToConvert.path),
        );

        print(
            'Đã chuyển đổi sang PDF, kết quả: filePath=${pdfData.filePath}, pdfId=${pdfData.pdfId}');

        // Cập nhật trạng thái đã chuyển đổi thành công
        documents[index] = docToConvert.copyWith(
          isConverting: false,
          isConverted: true,
          pdfPath: pdfData.filePath,
          pdfId: pdfData.pdfId,
        );

        print('Đã cập nhật document với pdfId: ${documents[index].pdfId}');
      }

      state = AsyncData(documents);
    } catch (e) {
      // Cập nhật trạng thái lỗi
      documents[index] = docToConvert.copyWith(
        isConverting: false,
        error: e.toString(),
      );
      state = AsyncData(documents);
      print('Lỗi khi chuyển đổi document: $e');
    }
  }

  void removeDocument(int index) {
    if (state.valueOrNull == null) return;

    final documents = [...state.value!];
    documents.removeAt(index);
    state = AsyncData(documents);
  }

  // Phương thức để chuyển đến màn hình ký tài liệu
  void navigateToSignDocument(int index, BuildContext context) {
    if (state.valueOrNull == null) return;

    final documents = state.value!;
    if (index >= documents.length) return;

    final document = documents[index];

    // Kiểm tra xem file đã được chuyển đổi sang PDF chưa
    if (!document.isConverted && !document.isPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chuyển đổi tài liệu sang PDF trước khi ký'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Tạo PDF ID nếu không có (dù cho đã là PDF hoặc đã chuyển đổi)
    var pdfId = document.pdfId;
    if (pdfId == null || pdfId.isEmpty) {
      pdfId = _generateTempPdfId(document.fileName);

      // Cập nhật document với PDF ID mới
      final updatedDocuments = [...documents];
      updatedDocuments[index] = document.copyWith(pdfId: pdfId);
      state = AsyncData(updatedDocuments);

      print('Đã tạo PDF ID mới: $pdfId');
    } else {
      print('Sử dụng PDF ID hiện có: $pdfId');
    }

    // Determine the correct file path
    final filePath = document.isPdf
        ? document.fileName
        : document.fileName.replaceAll('.docx', '.pdf');

    // Chuyển đến màn hình ký tài liệu
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureScreen(
          pdfId: pdfId,
          pdfUrl: document.webUrl,
          pdfBytes: document.pdfBytes,
          filePath: filePath,
        ),
      ),
    );
  }

  // Đánh dấu tài liệu đã được ký
  void markDocumentAsSigned(int index) {
    if (state.valueOrNull == null) return;

    final documents = [...state.value!];
    if (index >= documents.length) return;

    documents[index] = documents[index].copyWith(isSigned: true);
    state = AsyncData(documents);
  }
}
