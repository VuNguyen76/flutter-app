// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DocumentModelImpl _$$DocumentModelImplFromJson(Map<String, dynamic> json) =>
    _$DocumentModelImpl(
      fileName: json['fileName'] as String,
      path: json['path'] as String,
      isPdf: json['isPdf'] as bool,
      pdfPath: json['pdfPath'] as String?,
      bytes: const Uint8ListConverter().fromJson(json['bytes'] as List<int>?),
      pdfBytes:
          const Uint8ListConverter().fromJson(json['pdfBytes'] as List<int>?),
      webUrl: json['webUrl'] as String?,
      pdfId: json['pdfId'] as String?,
      isConverting: json['isConverting'] as bool? ?? false,
      isConverted: json['isConverted'] as bool? ?? false,
      isSigned: json['isSigned'] as bool? ?? false,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$$DocumentModelImplToJson(_$DocumentModelImpl instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'path': instance.path,
      'isPdf': instance.isPdf,
      'pdfPath': instance.pdfPath,
      'bytes': const Uint8ListConverter().toJson(instance.bytes),
      'pdfBytes': const Uint8ListConverter().toJson(instance.pdfBytes),
      'webUrl': instance.webUrl,
      'pdfId': instance.pdfId,
      'isConverting': instance.isConverting,
      'isConverted': instance.isConverted,
      'isSigned': instance.isSigned,
      'error': instance.error,
    };

_$ConversionSuccessImpl _$$ConversionSuccessImplFromJson(
        Map<String, dynamic> json) =>
    _$ConversionSuccessImpl(
      pdfPath: json['pdfPath'] as String,
      pdfBytes:
          const Uint8ListConverter().fromJson(json['pdfBytes'] as List<int>?),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ConversionSuccessImplToJson(
        _$ConversionSuccessImpl instance) =>
    <String, dynamic>{
      'pdfPath': instance.pdfPath,
      'pdfBytes': const Uint8ListConverter().toJson(instance.pdfBytes),
      'runtimeType': instance.$type,
    };

_$ConversionFailureImpl _$$ConversionFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$ConversionFailureImpl(
      error: json['error'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ConversionFailureImplToJson(
        _$ConversionFailureImpl instance) =>
    <String, dynamic>{
      'error': instance.error,
      'runtimeType': instance.$type,
    };
