from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import shutil
import time
import base64
from io import BytesIO
from docx2pdf import convert
import urllib.parse
from fastapi.staticfiles import StaticFiles
from typing import Optional
from PyPDF2 import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.utils import ImageReader
from PIL import Image
from datetime import datetime
import unicodedata
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
VIETNAMESE_FONT_AVAILABLE = False
try:
    font_path = os.path.join(os.path.dirname(__file__), 'fonts', 'DejaVuSans.ttf')
    if os.path.exists(font_path):
        pdfmetrics.registerFont(TTFont('DejaVuSans', font_path))
        pdfmetrics.registerFont(TTFont('DejaVuSans-Bold', os.path.join(os.path.dirname(__file__), 'fonts', 'DejaVuSans-Bold.ttf')))
        VIETNAMESE_FONT_AVAILABLE = True
        print("Đã đăng ký font DejaVuSans để hỗ trợ tiếng Việt")
    else:
        noto_path = os.path.join(os.path.dirname(__file__), 'fonts', 'NotoSans-Regular.ttf')
        if os.path.exists(noto_path):
            pdfmetrics.registerFont(TTFont('NotoSans', noto_path))
            pdfmetrics.registerFont(TTFont('NotoSans-Bold', os.path.join(os.path.dirname(__file__), 'fonts', 'NotoSans-Bold.ttf')))
            VIETNAMESE_FONT_AVAILABLE = True
            print("Đã đăng ký font NotoSans để hỗ trợ tiếng Việt")
        else:
            raise Exception("Không tìm thấy font hỗ trợ tiếng Việt")
except Exception as e:
    VIETNAMESE_FONT_AVAILABLE = False
    print(f"Không thể đăng ký font hỗ trợ tiếng Việt: {str(e)}")
    print("Sử dụng font Helvetica mặc định của ReportLab")
def normalize_vietnamese_text(text):
    if not VIETNAMESE_FONT_AVAILABLE:
        text = unicodedata.normalize('NFKD', text)
        text = ''.join([c for c in text if not unicodedata.combining(c)])
    return text
app = FastAPI(title="DOCX to PDF Converter")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
os.makedirs("temp", exist_ok=True)
os.makedirs("static/pdfs", exist_ok=True)
os.makedirs("static/signatures", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def read_root():
    return {"message": "DOCX to PDF Converter API"}

@app.get("/view/{pdf_id}")
async def view_pdf(pdf_id: str):
    pdf_path = f"static/pdfs/{pdf_id}.pdf"
    print(f"Yêu cầu xem PDF: {pdf_id}, đường dẫn: {pdf_path}")
    
    if not os.path.exists(pdf_path):
        print(f"PDF không tồn tại: {pdf_path}")
        raise HTTPException(status_code=404, detail="PDF không tồn tại")
    file_size = os.path.getsize(pdf_path)
    try:
        with open(pdf_path, 'rb') as f:
            header = f.read(10)
            header_hex = ' '.join([f'{b:02x}' for b in header])
            print(f"PDF header (hex): {header_hex}")
            if not header.startswith(b'%PDF-'):
                print(f"File không phải định dạng PDF, header: {header_hex}")
                raise HTTPException(status_code=400, detail="File không phải định dạng PDF")
            
            # Log phiên bản PDF
            pdf_version = header[5:8].decode('ascii', errors='ignore')
            print(f"Phiên bản PDF: {pdf_version}")
    except Exception as e:
        print(f"Lỗi khi đọc file PDF: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi khi đọc file: {str(e)}")
    
    print(f"Trả về file PDF: {pdf_path}, kích thước: {file_size} bytes")

    response = FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        headers={
            "Content-Type": "application/pdf",
            "Content-Disposition": f"inline; filename={pdf_id}.pdf",
            "Content-Length": str(file_size),
            "Cache-Control": "no-cache",
            "X-Content-Type-Options": "nosniff"
        }
    )
    
    return response

@app.post("/convert")
async def convert_docx_to_pdf(file: UploadFile = File(...)):
    # Log để debug
    print(f"Nhận yêu cầu chuyển đổi file: {file.filename}")

    if not file.filename.endswith('.docx'):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận file DOCX")
    
    # Tạo ID duy nhất cho file
    file_id = str(uuid.uuid4())
    timestamp = int(time.time())
    pdf_id = f"{timestamp}_{file_id[:8]}"
    
    # Đường dẫn đến file
    docx_path = f"temp/{file_id}.docx"
    pdf_temp_path = f"temp/{file_id}.pdf"
    pdf_static_path = f"static/pdfs/{pdf_id}.pdf"
    
    try:
        # Lưu file DOCX tải lên
        with open(docx_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Log để debug
        print(f"Đã lưu file DOCX tại: {docx_path}")
        
        # Chuyển đổi DOCX sang PDF
        convert(docx_path, pdf_temp_path)
        
        # Kiểm tra xem file PDF đã được tạo chưa
        if not os.path.exists(pdf_temp_path):
            raise Exception(f"Không thể tạo file PDF: {pdf_temp_path}")
            
        # Kiểm tra kích thước file PDF
        pdf_size = os.path.getsize(pdf_temp_path)
        if pdf_size == 0:
            raise Exception(f"File PDF được tạo nhưng rỗng: {pdf_temp_path}")
            
        # Sao chép file vào thư mục static để có thể phục vụ trực tiếp
        shutil.copy2(pdf_temp_path, pdf_static_path)
        
        # Log để debug
        print(f"Đã chuyển đổi thành công sang PDF: {pdf_static_path}, kích thước: {pdf_size} bytes")
        
        # Xử lý tên file an toàn (không có ký tự đặc biệt) cho header
        pdf_filename = file.filename.replace('.docx', '.pdf')
        safe_filename = urllib.parse.quote(pdf_filename)
        
        # URL để xem PDF trực tiếp
        view_url = f"/view/{pdf_id}"
        
        # Trả về file PDF với headers chính xác và URL để xem
        response = FileResponse(
            path=pdf_temp_path, 
            filename=pdf_filename,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename*=UTF-8''{safe_filename}",
                "Content-Type": "application/pdf"
            }
        )
        response.headers["X-PDF-View-URL"] = view_url
        response.headers["X-PDF-ID"] = pdf_id
        return response
    except Exception as e:
        # Xử lý lỗi
        print(f"Lỗi xử lý file: {str(e)}")
        if os.path.exists(docx_path):
            os.remove(docx_path)
        if os.path.exists(pdf_temp_path):
            os.remove(pdf_temp_path)
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý: {str(e)}")
    finally:
        # Đóng file
        file.file.close()

@app.post("/sign-pdf")
async def sign_pdf(
    pdf_id: str = Form(...),
    signature_a_data: Optional[str] = Form(None),
    signature_a_name: Optional[str] = Form(None),
    signature_b_data: Optional[str] = Form(None),
    signature_b_name: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None)
):
    try:
        # Log để debug
        print(f"Nhận yêu cầu ký PDF: {pdf_id}")
        
        # Đường dẫn đến file PDF gốc
        original_pdf_path = f"static/pdfs/{pdf_id}.pdf"
        
        # Kiểm tra xem có file upload không
        if file is not None and file.filename:
            print(f"Phát hiện file upload: {file.filename}")
            # Nếu là ID tự tạo (local_*), lưu file vào static/pdfs với tên là pdf_id.pdf
            if pdf_id.startswith("local_"):
                original_pdf_path = f"static/pdfs/{pdf_id}.pdf"
                # Lưu file
                with open(original_pdf_path, "wb") as buffer:
                    shutil.copyfileobj(file.file, buffer)
                print(f"Đã lưu file upload vào: {original_pdf_path}")
        
        # Kiểm tra file tồn tại
        if not os.path.exists(original_pdf_path):
            error_msg = f"PDF không tồn tại: {original_pdf_path}"
            print(error_msg)
            raise HTTPException(status_code=404, detail=error_msg)
        
        # ID cho file đã ký
        signed_id = f"signed_{uuid.uuid4()}"
        signed_pdf_path = f"static/pdfs/{signed_id}.pdf"
        
        # Lưu chữ ký nếu có
        sig_a_path = None
        if signature_a_data and signature_a_data.startswith('data:image'):
            sig_a_path = save_signature_image(signature_a_data, "a")
        
        sig_b_path = None
        if signature_b_data and signature_b_data.startswith('data:image'):
            sig_b_path = save_signature_image(signature_b_data, "b")
        
        # Thêm chữ ký vào PDF
        add_signatures_to_pdf(
            original_pdf_path,
            signed_pdf_path,
            sig_a_path,
            signature_a_name,
            sig_b_path,
            signature_b_name
        )
        
        # URL để xem PDF đã ký
        view_url = f"/view/{signed_id}"
        
        # Trả về URL để xem PDF đã ký
        return {
            "message": "Ký PDF thành công",
            "pdf_id": signed_id,
            "view_url": view_url
        }
    except Exception as e:
        print(f"Lỗi khi ký PDF: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi khi ký PDF: {str(e)}")

def save_signature_image(data_url: str, prefix: str) -> str:
    """Lưu chữ ký từ data URL thành file hình ảnh"""
    try:
        # Tách phần dữ liệu từ data URL
        header, encoded = data_url.split(",", 1)
        binary_data = base64.b64decode(encoded)
        
        # Tạo tên file duy nhất
        file_name = f"signature_{prefix}_{uuid.uuid4()}.png"
        file_path = f"static/signatures/{file_name}"
        
        # Lưu file
        with open(file_path, "wb") as f:
            f.write(binary_data)
        
        return file_path
    except Exception as e:
        print(f"Lỗi khi lưu chữ ký: {str(e)}")
        return None

def add_signatures_to_pdf(
    original_pdf_path: str,
    output_pdf_path: str,
    signature_a_path: Optional[str],
    signature_a_name: Optional[str],
    signature_b_path: Optional[str],
    signature_b_name: Optional[str]
) -> None:
    """Thêm chữ ký vào PDF bằng cách tạo trang mới"""
    try:
        print(f"Bắt đầu thêm chữ ký vào PDF: {original_pdf_path}")
        print(f"Chữ ký A: {signature_a_path}, Tên A: {signature_a_name}")
        print(f"Chữ ký B: {signature_b_path}, Tên B: {signature_b_name}")
        
        # Kiểm tra file gốc
        if not os.path.exists(original_pdf_path):
            raise Exception(f"File PDF gốc không tồn tại: {original_pdf_path}")
            
        # Đọc và kiểm tra file PDF gốc
        try:
            with open(original_pdf_path, 'rb') as f:
                header = f.read(10)
                header_hex = ' '.join([f'{b:02x}' for b in header])
                print(f"PDF gốc header (hex): {header_hex}")
                
                if not header.startswith(b'%PDF-'):
                    raise Exception(f"File gốc không phải PDF hợp lệ, header: {header_hex}")
                    
            # Đặt lại con trỏ file
            f.close()
        except Exception as check_error:
            print(f"Lỗi khi kiểm tra file PDF gốc: {str(check_error)}")
            raise check_error
        
        # Đọc PDF gốc
        reader = PdfReader(original_pdf_path)
        print(f"Đã đọc PDF gốc, số trang: {len(reader.pages)}")
        
        # Kiểm tra số trang
        if len(reader.pages) == 0:
            raise Exception("PDF gốc không có trang nào")
        
        writer = PdfWriter()
        
        # Thêm tất cả các trang từ PDF gốc vào writer
        for i in range(len(reader.pages)):
            writer.add_page(reader.pages[i])
            print(f"Đã thêm trang {i+1}/{len(reader.pages)} vào writer")
        
        # Tạo trang mới cho chữ ký
        signature_page = BytesIO()
        c = canvas.Canvas(signature_page, pagesize=A4)
        
        # Kích thước trang A4 (595 x 842 points)
        width, height = A4
        print(f"Kích thước trang A4: {width} x {height} points")
        
        # Kiểm tra và sử dụng font phù hợp
        if VIETNAMESE_FONT_AVAILABLE:
            # Kiểm tra xem DejaVu hay Noto Sans đang được sử dụng
            dejavu_path = os.path.join(os.path.dirname(__file__), 'fonts', 'DejaVuSans.ttf')
            if os.path.exists(dejavu_path):
                print("Sử dụng font DejaVuSans cho tiếng Việt")
                main_font = "DejaVuSans"
                bold_font = "DejaVuSans-Bold"
            else:
                print("Sử dụng font NotoSans cho tiếng Việt")
                main_font = "NotoSans"
                bold_font = "NotoSans-Bold"
        else:
            print("Sử dụng font Helvetica (không hỗ trợ đầy đủ tiếng Việt)")
            main_font = "Helvetica"
            bold_font = "Helvetica-Bold"
            
        # Các tiêu đề và nhãn tiếng Việt
        title = normalize_vietnamese_text("TRANG CHỮ KÝ XÁC NHẬN")
        subtitle = normalize_vietnamese_text("Tài liệu này đã được ký điện tử bởi các bên")
        party_a = normalize_vietnamese_text("BÊN A")
        party_b = normalize_vietnamese_text("BÊN B")
        current_date = datetime.now().strftime("%d/%m/%Y")
        date_label = normalize_vietnamese_text(f"Ngày ký: {current_date}")
        
        # Đặt text rendering mode để tối ưu cho tiếng Việt
        c.setFillColorRGB(0, 0, 0)  # Đảm bảo màu chữ là đen
        
        # Thêm tiêu đề trang chữ ký
        c.setFont(bold_font, 18)
        
        # Vẽ các tiêu đề
        c.drawString(width/2 - 110, height - 50, title)
        c.setFont(main_font, 12)
        c.drawString(width/2 - 140, height - 70, subtitle)
        
        # Vẽ đường kẻ ngang
        c.setLineWidth(1)
        c.line(50, height - 90, width - 50, height - 90)
        
        # Vẽ khung chữ ký
        # Bên A - Bên trái
        c.setLineWidth(1)
        c.rect(50, height/2 - 50, 230, 150)  # Tăng kích thước từ 200x120 lên 230x150
        c.setFont(bold_font, 14)
        c.drawString(145, height/2 + 120, party_a)
        print("Đã vẽ khung chữ ký bên A")
        
        # Thêm chữ ký và tên nếu có
        if signature_a_path:
            try:
                if not os.path.exists(signature_a_path):
                    print(f"CẢNH BÁO: File chữ ký A không tồn tại: {signature_a_path}")
                else:
                    img = Image.open(signature_a_path)
                    img_width, img_height = img.size
                    print(f"Đã mở ảnh chữ ký A, kích thước: {img_width}x{img_height} px")
                    
                    # Căn giữa chữ ký trong khung
                    sig_width = 180
                    sig_x = 50 + (230 - sig_width) / 2
                    sig_y = height/2 - 30
                    
                    c.drawImage(ImageReader(img), sig_x, sig_y, width=sig_width, height=120, preserveAspectRatio=True)
                    print("Đã thêm ảnh chữ ký A vào PDF")
            except Exception as img_error:
                print(f"Lỗi khi thêm ảnh chữ ký A: {str(img_error)}")
                # Tiếp tục mà không dừng lại
        
        if signature_a_name:
            # Căn giữa tên người ký với font lớn hơn
            c.setFont(bold_font, 12)
            signature_a_name = normalize_vietnamese_text(signature_a_name)
            text_width = c.stringWidth(signature_a_name, bold_font, 12)
            text_x = 50 + (230 - text_width) / 2
            c.drawString(text_x, height/2 - 45, signature_a_name)
            print(f"Đã thêm tên A: {signature_a_name}")
        
        # Bên B - Bên phải
        c.setLineWidth(1)
        c.rect(315, height/2 - 50, 230, 150)  # Tăng kích thước từ 200x120 lên 230x150
        c.setFont(bold_font, 14)
        c.drawString(410, height/2 + 120, party_b)
        print("Đã vẽ khung chữ ký bên B")
        
        # Thêm chữ ký và tên nếu có
        if signature_b_path:
            try:
                if not os.path.exists(signature_b_path):
                    print(f"CẢNH BÁO: File chữ ký B không tồn tại: {signature_b_path}")
                else:
                    img = Image.open(signature_b_path)
                    img_width, img_height = img.size
                    print(f"Đã mở ảnh chữ ký B, kích thước: {img_width}x{img_height} px")
                    
                    # Căn giữa chữ ký trong khung
                    sig_width = 180
                    sig_x = 315 + (230 - sig_width) / 2
                    sig_y = height/2 - 30
                    
                    c.drawImage(ImageReader(img), sig_x, sig_y, width=sig_width, height=120, preserveAspectRatio=True)
                    print("Đã thêm ảnh chữ ký B vào PDF")
            except Exception as img_error:
                print(f"Lỗi khi thêm ảnh chữ ký B: {str(img_error)}")
                # Tiếp tục mà không dừng lại
        
        if signature_b_name:
            # Căn giữa tên người ký với font lớn hơn
            c.setFont(bold_font, 12)
            signature_b_name = normalize_vietnamese_text(signature_b_name)
            text_width = c.stringWidth(signature_b_name, bold_font, 12)
            text_x = 315 + (230 - text_width) / 2
            c.drawString(text_x, height/2 - 45, signature_b_name)
            print(f"Đã thêm tên B: {signature_b_name}")
        
        # Thêm ngày tháng ở cuối trang
        c.setFont(main_font, 10)
        c.drawString(width/2 - 50, 50, date_label)
        
        # Lưu canvas
        c.save()
        print("Đã lưu canvas trang chữ ký")
        
        # Đọc trang chữ ký
        signature_page.seek(0)
        try:
            signature_pdf = PdfReader(signature_page)
            print(f"Đã đọc trang chữ ký PDF, số trang: {len(signature_pdf.pages)}")
            
            # Thêm trang chữ ký vào PDF
            writer.add_page(signature_pdf.pages[0])
            print("Đã thêm trang chữ ký vào PDF")
            
            # Tạo thư mục đích nếu không tồn tại
            output_dir = os.path.dirname(output_pdf_path)
            if not os.path.exists(output_dir):
                os.makedirs(output_dir)
                print(f"Đã tạo thư mục đích: {output_dir}")
            
            # Lưu PDF đã ký
            with open(output_pdf_path, "wb") as output_file:
                writer.write(output_file)
                print(f"Đã ghi PDF đã ký vào: {output_pdf_path}")
            
            # Kiểm tra file đã tạo
            if os.path.exists(output_pdf_path):
                file_size = os.path.getsize(output_pdf_path)
                print(f"Đã ký PDF thành công: {output_pdf_path}, kích thước: {file_size} bytes")
                
                # Kiểm tra xem file có phải là PDF hợp lệ không
                with open(output_pdf_path, 'rb') as f:
                    check_header = f.read(10)
                    check_header_hex = ' '.join([f'{b:02x}' for b in check_header])
                    print(f"PDF đã ký header (hex): {check_header_hex}")
                    
                    if not check_header.startswith(b'%PDF-'):
                        print(f"CẢNH BÁO: File đã ký có thể không phải PDF hợp lệ: {check_header_hex}")
            else:
                error_msg = f"Lỗi: File PDF đã ký không tồn tại sau khi lưu"
                print(error_msg)
                raise Exception(error_msg)
        except Exception as pdf_error:
            print(f"Lỗi khi xử lý trang chữ ký PDF: {str(pdf_error)}")
            raise pdf_error
        
    except Exception as e:
        print(f"Lỗi khi thêm chữ ký vào PDF: {str(e)}")
        raise e

# Để chạy ứng dụng: python -m uvicorn main:app --reload --host 0.0.0.0 --port 1046
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1046) 