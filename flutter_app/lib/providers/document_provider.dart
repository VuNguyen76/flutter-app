import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../services/conversion_service.dart';

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
          );

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
          );

          state = AsyncData([...state.valueOrNull ?? [], document]);
        }
      }
    }
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

        // Cập nhật trạng thái đã chuyển đổi thành công
        documents[index] = docToConvert.copyWith(
          isConverting: false,
          isConverted: true,
          pdfBytes: pdfData.bytes,
          pdfPath: 'web_pdf', // Giá trị giả lập cho path khi trên web
          webUrl: pdfData.webUrl, // Lưu URL để xem trực tiếp
        );
      } else {
        // Xử lý chuyển đổi trên mobile
        final filePath = await conversionService.convertDocxToPdf(
          File(docToConvert.path),
        );

        // Cập nhật trạng thái đã chuyển đổi thành công
        documents[index] = docToConvert.copyWith(
          isConverting: false,
          isConverted: true,
          pdfPath: filePath,
        );
      }

      state = AsyncData(documents);
    } catch (e) {
      // Cập nhật trạng thái lỗi
      documents[index] = docToConvert.copyWith(
        isConverting: false,
        error: e.toString(),
      );
      state = AsyncData(documents);
    }
  }

  void removeDocument(int index) {
    if (state.valueOrNull == null) return;

    final documents = [...state.value!];
    documents.removeAt(index);
    state = AsyncData(documents);
  }
}
