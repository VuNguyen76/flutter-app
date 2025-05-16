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
        title: const Text('DOCX to PDF Converter'),
        centerTitle: true,
      ),
      body: documentsAsync.when(
        data: (documents) {
          if (documents.isEmpty) {
            return const _EmptyView();
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
                onDelete: () => ref
                    .read(documentNotifierProvider.notifier)
                    .removeDocument(index),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(error: error.toString()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ref.read(documentNotifierProvider.notifier).pickAndAddDocument(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_copy_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có tài liệu nào',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút + để thêm một tài liệu DOCX',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            SelectableText.rich(
              TextSpan(
                text: error,
                style: TextStyle(color: Colors.red.shade700),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
