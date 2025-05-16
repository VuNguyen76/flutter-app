# DOCX to PDF Converter Backend

API service để chuyển đổi file DOCX sang PDF với độ chính xác cao.

## Cài đặt

1. Cài đặt Python 3.8+ và pip
2. Cài đặt các phụ thuộc:

```bash
pip install -r requirements.txt
```

3. Trên Windows, cài thêm Microsoft Office hoặc LibreOffice để docx2pdf hoạt động.

## Chạy server

```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 1046
```

## API Endpoints

- `GET /`: Kiểm tra API hoạt động
- `POST /convert/`: Tải lên file DOCX và nhận lại file PDF đã chuyển đổi

## Sử dụng

1. Gửi file DOCX bằng POST request đến `/convert/`
2. Nhận lại file PDF đã chuyển đổi

Ví dụ sử dụng curl:

```bash
curl -X POST -F "file=@document.docx" http://localhost:1046/convert/ --output converted.pdf
```

## Lưu ý

1. API cần Microsoft Office hoặc LibreOffice được cài đặt
2. Trong môi trường production, nên giới hạn CORS origins
