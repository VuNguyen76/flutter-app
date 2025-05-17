import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../providers/document_provider.dart';
import '../widgets/document_item.dart';
import '../widgets/pdf_viewer.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DOCX to PDF Converter',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2196F3), // Light Blue 500
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFE3F2FD), // Light Blue 50
            ],
          ),
        ),
        child: documentsAsync.when(
          data: (documents) {
            if (documents.isEmpty) {
              return _EmptyView(
                onAddDocument: () => ref
                    .read(documentNotifierProvider.notifier)
                    .pickAndAddDocument(),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final document = documents[index];
                return DocumentItem(
                  document: document,
                  onConvert: () => ref
                      .read(documentNotifierProvider.notifier)
                      .convertDocument(index),
                  onView: () {
                    if (document.isPdf || document.isConverted) {
                      if (kIsWeb) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewer(
                              filePath: document.fileName,
                              pdfUrl: document.webUrl,
                              pdfBytes: document.webUrl == null
                                  ? (document.isPdf
                                      ? document.bytes
                                      : document.pdfBytes)
                                  : null,
                            ),
                          ),
                        );
                      } else {
                        final path =
                            document.isPdf ? document.path : document.pdfPath!;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewer(filePath: path),
                          ),
                        );
                      }
                    }
                  },
                  onSign: (document.isPdf || document.isConverted) &&
                          !document.isSigned
                      ? () => ref
                          .read(documentNotifierProvider.notifier)
                          .navigateToSignDocument(index, context)
                      : null,
                  onDelete: () => ref
                      .read(documentNotifierProvider.notifier)
                      .removeDocument(index),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2196F3), // Light Blue 500
            ),
          ),
          error: (error, stack) => _ErrorView(
            error: error.toString(),
            onRetry: () => ref.invalidate(documentNotifierProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            ref.read(documentNotifierProvider.notifier).pickAndAddDocument(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm tài liệu'),
        backgroundColor: const Color(0xFF2196F3), // Light Blue 500
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAddDocument;

  const _EmptyView({required this.onAddDocument});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_copy_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có tài liệu nào',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1976D2), // Light Blue 700
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Nhấn nút + để thêm một tài liệu DOCX hoặc PDF',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddDocument,
            icon: const Icon(Icons.add),
            label: const Text('Thêm tài liệu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3), // Light Blue 500
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Đã xảy ra lỗi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1976D2), // Light Blue 700
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText.rich(
                  TextSpan(
                    text: error,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
