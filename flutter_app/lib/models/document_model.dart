import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:io';
import 'dart:typed_data';

part 'document_model.freezed.dart';
part 'document_model.g.dart';

// Converter cho Uint8List
class Uint8ListConverter implements JsonConverter<Uint8List?, List<int>?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(List<int>? json) {
    return json != null ? Uint8List.fromList(json) : null;
  }

  @override
  List<int>? toJson(Uint8List? object) {
    return object?.toList();
  }
}

@freezed
class DocumentModel with _$DocumentModel {
  const factory DocumentModel({
    required String fileName,
    required String path,
    required bool isPdf,
    String? pdfPath,
    @Uint8ListConverter() Uint8List? bytes,
    @Uint8ListConverter() Uint8List? pdfBytes,
    String? webUrl,
    String? pdfId,
    @Default(false) bool isConverting,
    @Default(false) bool isConverted,
    @Default(false) bool isSigned,
    String? error,
  }) = _DocumentModel;

  factory DocumentModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentModelFromJson(json);
}

@freezed
class ConversionResult with _$ConversionResult {
  const factory ConversionResult.success({
    required String pdfPath,
    @Uint8ListConverter() Uint8List? pdfBytes,
  }) = ConversionSuccess;

  const factory ConversionResult.failure({
    required String error,
  }) = ConversionFailure;

  factory ConversionResult.fromJson(Map<String, dynamic> json) =>
      _$ConversionResultFromJson(json);
}
