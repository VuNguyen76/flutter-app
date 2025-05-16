from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import shutil
import time
from docx2pdf import convert
import urllib.parse
from fastapi.staticfiles import StaticFiles

app = FastAPI(title="DOCX to PDF Converter")

# Cấu hình CORS để cho phép truy cập từ ứng dụng Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Trong môi trường production, nên giới hạn origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Đảm bảo thư mục temp tồn tại
os.makedirs("temp", exist_ok=True)
os.makedirs("static/pdfs", exist_ok=True)

# Mount thư mục static để phục vụ các file tĩnh
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def read_root():
    return {"message": "DOCX to PDF Converter API"}

@app.get("/view/{pdf_id}")
async def view_pdf(pdf_id: str):
    pdf_path = f"static/pdfs/{pdf_id}.pdf"
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="PDF không tồn tại")
    
    return FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        headers={"Content-Type": "application/pdf"}
    )

@app.post("/convert")
async def convert_docx_to_pdf(file: UploadFile = File(...)):
    # Log để debug
    print(f"Nhận yêu cầu chuyển đổi file: {file.filename}")
    
    # Kiểm tra file có phải là docx không
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

# Để chạy ứng dụng: python -m uvicorn main:app --reload --host 0.0.0.0 --port 1046
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1046) 