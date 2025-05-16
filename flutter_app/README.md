# DOCX to PDF Converter

Ứng dụng Flutter để chuyển đổi tài liệu từ định dạng DOCX sang PDF với độ chính xác cao.

## Tính năng

- Chọn và tải lên file DOCX từ thiết bị
- Chuyển đổi DOCX sang PDF với định dạng được giữ nguyên
- Xem file PDF sau khi chuyển đổi
- Hỗ trợ cả file DOCX và PDF
- Giao diện người dùng thân thiện

## Cài đặt

### Yêu cầu

- Flutter 3.0.0 trở lên
- Dart 3.0.0 trở lên
- Backend Python đang chạy trên port 1046 (xem thư mục `backend`)

### Các bước cài đặt

1. Clone repository
2. Cài đặt các phụ thuộc:

```bash
flutter pub get
```

3. Chạy build_runner để tạo code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Chạy ứng dụng:

```bash
flutter run
```

## Cấu hình

Backend Python cần chạy trước khi sử dụng ứng dụng:

```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 1046
```

URL kết nối trong ứng dụng đã được cài đặt sẵn:

```dart
static const String baseUrl = 'http://localhost:1046';
```

## Lưu ý

- Đảm bảo backend Python đã chạy trước khi sử dụng ứng dụng Flutter
- Backend cần có Microsoft Office hoặc LibreOffice được cài đặt để chuyển đổi chính xác
- Kiểm tra cấu hình mạng nếu có vấn đề kết nối từ ứng dụng tới backend
