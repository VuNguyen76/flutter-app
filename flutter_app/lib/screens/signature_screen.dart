import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signature/signature.dart';
import '../services/signature_service.dart';
import '../widgets/pdf_viewer.dart';
import '../providers/document_provider.dart';
import '../models/document_model.dart';
import 'package:http/http.dart' as http;

class SignatureScreen extends HookConsumerWidget {
  final String pdfId;
  final String fileName;

  const SignatureScreen({
    super.key,
    required this.pdfId,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Log thông tin PDF ID cho việc debug
    useEffect(() {
      print('SignatureScreen - PDF ID: $pdfId, FileName: $fileName');
      return null;
    }, const []);

    // Lấy danh sách documents để tìm document phù hợp với pdfId
    final documentsAsync = ref.watch(documentNotifierProvider);
    final document = useMemoized(() {
      if (documentsAsync.value == null) return null;
      try {
        return documentsAsync.value!.firstWhere(
          (doc) => doc.pdfId == pdfId,
        );
      } catch (e) {
        print('Không tìm thấy document với pdfId: $pdfId');
        return null;
      }
    }, [documentsAsync.value, pdfId]);

    useEffect(() {
      if (document != null) {
        print(
            'Tìm thấy document: ${document.fileName}, isPdf: ${document.isPdf}, isConverted: ${document.isConverted}');
        if (document.pdfBytes != null) {
          print(
              'Document có pdfBytes, kích thước: ${document.pdfBytes!.length} bytes');
        } else if (document.bytes != null && document.isPdf) {
          print(
              'Document có bytes, kích thước: ${document.bytes!.length} bytes');
        } else {
          print('Document không có dữ liệu bytes');
        }
      } else {
        print('Không tìm thấy document cho pdfId: $pdfId');
      }
      return null;
    }, [document]);

    // State cho chữ ký
    final signatureControllerA = useState(
      SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.transparent,
      ),
    );

    final signatureControllerB = useState(
      SignatureController(
        penStrokeWidth: 3,
        penColor: Colors.black,
        exportBackgroundColor: Colors.transparent,
      ),
    );

    // State cho tên người ký
    final nameAController = useTextEditingController();
    final nameBController = useTextEditingController();

    // State cho process
    final isLoading = useState(false);
    final activeTabIndex = useState(0);

    // Xử lý submit chữ ký
    Future<void> handleSubmit() async {
      if (signatureControllerA.value.isEmpty &&
          signatureControllerB.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng ký ít nhất một chữ ký'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Hiển thị loading
      isLoading.value = true;

      try {
        print('Bắt đầu quá trình ký PDF với ID: $pdfId');

        // Chuyển đổi chữ ký thành base64
        String? signatureAData;
        if (!signatureControllerA.value.isEmpty) {
          final signatureABytes = await signatureControllerA.value.toPngBytes();
          if (signatureABytes != null) {
            signatureAData =
                'data:image/png;base64,${base64Encode(signatureABytes)}';
            print('Đã chuyển đổi chữ ký A thành base64');
          }
        }

        String? signatureBData;
        if (!signatureControllerB.value.isEmpty) {
          final signatureBBytes = await signatureControllerB.value.toPngBytes();
          if (signatureBBytes != null) {
            signatureBData =
                'data:image/png;base64,${base64Encode(signatureBBytes)}';
            print('Đã chuyển đổi chữ ký B thành base64');
          }
        }

        // Lấy dữ liệu PDF nếu có
        Uint8List? pdfBytes;
        String? pdfFilename;

        if (pdfId.startsWith('local_') && document != null) {
          print('Sử dụng ID tự tạo, cần dữ liệu PDF để gửi đến server');
          if (document.isPdf && document.bytes != null) {
            // Nếu document là PDF gốc
            pdfBytes = document.bytes;
            pdfFilename = document.fileName;
            print(
                'Sử dụng bytes của PDF gốc, kích thước: ${pdfBytes!.length} bytes');
          } else if (document.isConverted && document.pdfBytes != null) {
            // Nếu document đã được chuyển đổi
            pdfBytes = document.pdfBytes;
            pdfFilename = document.fileName.replaceAll('.docx', '.pdf');
            print(
                'Sử dụng bytes của PDF đã chuyển đổi, kích thước: ${pdfBytes!.length} bytes');
          } else if (!kIsWeb && document.pdfPath != null) {
            // Trên mobile, đọc file từ đường dẫn
            try {
              final file = File(document.pdfPath!);
              if (await file.exists()) {
                pdfBytes = await file.readAsBytes();
                pdfFilename = document.fileName.replaceAll('.docx', '.pdf');
                print(
                    'Đã đọc file PDF từ đường dẫn: ${document.pdfPath}, kích thước: ${pdfBytes.length} bytes');
              } else {
                print('File PDF không tồn tại: ${document.pdfPath}');
              }
            } catch (e) {
              print('Lỗi khi đọc file PDF: $e');
            }
          }
        }

        // Gửi request ký PDF
        final service = SignatureService();
        print('Gửi request ký PDF với ID: $pdfId');
        print('SignatureA: ${signatureAData != null ? "Có" : "Không"}');
        print('SignatureB: ${signatureBData != null ? "Có" : "Không"}');
        print('NameA: ${nameAController.text}');
        print('NameB: ${nameBController.text}');
        print('PDF Bytes: ${pdfBytes != null ? "Có" : "Không"}');
        print('PDF Filename: ${pdfFilename ?? "Không có"}');

        final result = await service.signPdf(
          pdfId: pdfId,
          signatureAData: signatureAData,
          signatureAName:
              nameAController.text.isEmpty ? null : nameAController.text,
          signatureBData: signatureBData,
          signatureBName:
              nameBController.text.isEmpty ? null : nameBController.text,
          pdfBytes: pdfBytes,
          pdfFilename: pdfFilename,
        );

        print('Ký PDF thành công, URL kết quả: ${result.fullViewUrl}');
        print('PDF ID mới: ${result.pdfId}');
        print('Message: ${result.message}');
        print('View URL: ${result.viewUrl}');

        // Đánh dấu tài liệu đã được ký
        if (document != null) {
          final documentIndex =
              documentsAsync.value!.indexWhere((doc) => doc.pdfId == pdfId);
          if (documentIndex >= 0) {
            ref
                .read(documentNotifierProvider.notifier)
                .markDocumentAsSigned(documentIndex);
            print('Đã đánh dấu document đã ký');
          }
        }

        // Chuyển đến màn hình xem PDF đã ký
        if (context.mounted) {
          // Tạo tên file cho PDF đã ký
          final signedFileName =
              'signed_${fileName.replaceAll('.pdf', '')}.pdf';
          print('Chuyển hướng đến màn hình xem PDF đã ký: $signedFileName');
          print('URL đầy đủ: ${result.fullViewUrl}');

          if (result.fullViewUrl.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('URL xem PDF trống'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Tải về PDF đã ký để hiển thị
          try {
            final pdfResponse = await http.get(Uri.parse(result.fullViewUrl));
            print('Tải về PDF đã ký, status code: ${pdfResponse.statusCode}');

            if (pdfResponse.statusCode == 200) {
              print(
                  'Đã tải PDF đã ký thành công, kích thước: ${pdfResponse.bodyBytes.length} bytes');

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfViewer(
                    filePath: signedFileName,
                    pdfBytes: pdfResponse.bodyBytes,
                    pdfUrl: result.fullViewUrl,
                  ),
                ),
              );
            } else {
              print(
                  'Lỗi khi tải PDF đã ký: ${pdfResponse.statusCode} - ${pdfResponse.body}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Lỗi khi tải PDF đã ký: ${pdfResponse.statusCode}'),
                  backgroundColor: Colors.orange,
                ),
              );

              // Vẫn thử hiển thị với URL
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfViewer(
                    filePath: signedFileName,
                    pdfUrl: result.fullViewUrl,
                  ),
                ),
              );
            }
          } catch (e) {
            print('Lỗi khi tải PDF đã ký: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi khi tải PDF đã ký: $e'),
                backgroundColor: Colors.orange,
              ),
            );

            // Vẫn thử hiển thị với URL
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewer(
                  filePath: signedFileName,
                  pdfUrl: result.fullViewUrl,
                ),
              ),
            );
          }
        }
      } catch (e) {
        // Hiển thị lỗi
        print('Lỗi khi ký PDF: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Tắt loading
        isLoading.value = false;
      }
    }

    // Cleanup
    useEffect(() {
      return () {
        signatureControllerA.value.dispose();
        signatureControllerB.value.dispose();
      };
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ký tài liệu'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            onPressed: isLoading.value ? null : handleSubmit,
            icon: const Icon(Icons.check),
            tooltip: 'Hoàn thành',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              const Color(0xFFE3F2FD), // Light Blue 50
            ],
          ),
        ),
        child: isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        indicatorColor:
                            const Color(0xFF2196F3), // Light Blue 500
                        labelColor: const Color(0xFF2196F3), // Light Blue 500
                        unselectedLabelColor: Colors.grey,
                        onTap: (index) {
                          activeTabIndex.value = index;
                        },
                        tabs: const [
                          Tab(text: 'ĐẠI DIỆN BÊN A'),
                          Tab(text: 'ĐẠI DIỆN BÊN B'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab Đại diện bên A
                          _buildSignaturePanel(
                            context,
                            'A',
                            signatureControllerA.value,
                            nameAController,
                            () => signatureControllerA.value.clear(),
                          ),

                          // Tab Đại diện bên B
                          _buildSignaturePanel(
                            context,
                            'B',
                            signatureControllerB.value,
                            nameBController,
                            () => signatureControllerB.value.clear(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading.value ? null : handleSubmit,
        label: const Text('Ký và hoàn thành'),
        icon: const Icon(Icons.done_all),
        backgroundColor: const Color(0xFF2196F3), // Light Blue 500
      ),
    );
  }

  Widget _buildSignaturePanel(
    BuildContext context,
    String side,
    SignatureController controller,
    TextEditingController nameController,
    VoidCallback onClear,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Khung chữ ký
          Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Chữ ký đại diện bên $side',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1976D2), // Light Blue 700
                      ),
                    ),
                  ),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Signature(
                        controller: controller,
                        backgroundColor: Colors.white,
                        width: double.infinity,
                        height: 200,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.clear),
                          label: const Text('Xóa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tên người ký
          Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin người ký',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1976D2), // Light Blue 700
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên người ký',
                      hintText: 'Nhập tên người ký',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Color(0xFF42A5F5), // Light Blue 400
                      ),
                      labelStyle: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF2196F3), // Light Blue 500
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Preview
          Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xem trước',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1976D2), // Light Blue 700
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ĐẠI DIỆN BÊN $side',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1976D2), // Light Blue 700
                          ),
                        ),
                        const SizedBox(height: 50),
                        if (nameController.text.isNotEmpty)
                          Text(
                            nameController.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
