# Bài 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

## 1. Mục Tiêu
- **Custom Bridge Network**: Tạo mạng `app-net` để các container giao tiếp nội bộ qua tên service/container (`db-server`) thông qua cơ chế DNS resolution của Docker.
- **Named Volume**: Tạo volume `db-data` lưu trữ dữ liệu PostgreSQL bền vững (Data Persistence) độc lập với vòng đời container.

---

## 2. Cấu Trúc Thư Mục
```text
homework/session_10/ex4/
├── commands.sh               # Script tự động thực thi toàn bộ kịch bản
├── README.md                 # Hướng dẫn chi tiết & báo cáo kết quả
└── screenshots/              # Thư mục lưu 2 ảnh kết quả trả về
```

---

## 3. Các Bước Thực Hiện Chi Tiết

### Bước 1: Tạo Custom Bridge Network & Named Volume
```bash
# 1. Tạo mạng Bridge tùy chỉnh
docker network create --driver bridge app-net

# 2. Tạo Named Volume lưu dữ liệu DB
docker volume create db-data
```

### Bước 2: Khởi Chạy Database Container & Backend Container
```bash
# 1. Khởi chạy Database Container (PostgreSQL 15) tham gia app-net, mount volume db-data
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine

# 2. Khởi chạy Backend Container tham gia app-net, truyền cấu hình DB host là db-server
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=mydb \
  -e DB_USER=myuser \
  -e DB_PASSWORD=mypassword \
  alpine:latest sh -c "tail -f /dev/null"
```

---

## 4. Kết Quả Mong Đợi & Minh Chứng (2 Ảnh)

### Kết quả 1: Lệnh ping `db-server` từ Backend container giải mã thành công IP nội bộ của DB container

Thực thi lệnh ping từ `app-container` sang `db-server`:
```bash
docker exec -it app-container ping -c 2 db-server
```

> 📸 **HƯỚNG DẪN CHỤP ẢNH 1:**
> - **Lệnh chạy:** `docker exec -it app-container ping -c 2 db-server`
> - **Kết quả cần hiển thị trên ảnh:**
>   - Dòng: `PING db-server (172.xx.x.x): 56 data bytes` (cho thấy hostname `db-server` đã được Docker DNS giải mã thành công ra IP nội bộ).
>   - Thống kê: `2 packets transmitted, 2 packets received, 0% packet loss`.
> - **Lưu file ảnh tại:** `screenshots/ping_db_server.png`

---

### Kết quả 2: Dữ liệu DB nguyên vẹn sau khi tái tạo container DB

Thực hiện kịch bản test Data Persistence theo 3 bước:

#### 1. Thêm dữ liệu ban đầu vào container `db-server`:
```bash
docker exec -i db-server psql -U myuser -d mydb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50), email VARCHAR(50));"
docker exec -i db-server psql -U myuser -d mydb -c "INSERT INTO users (name, email) VALUES ('Nguyen Van A', 'vana@example.com'), ('Tran Thi B', 'thib@example.com');"
```

#### 2. Xóa cứng container DB (`docker rm -f`) và khởi chạy lại container DB mới gắn cùng Volume `db-data`:
```bash
# Xóa cứng container cũ
docker rm -f db-server

# Khởi chạy container DB mới gắn cùng volume db-data
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine
```

#### 3. Chờ 3-5 giây để DB mới khởi động và truy vấn xác minh dữ liệu:
```bash
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"
```

> 📸 **HƯỚNG DẪN CHỤP ẢNH 2:**
> - **Lệnh chạy:** Chạy lệnh xóa, tái tạo và truy vấn dữ liệu:
>   ```bash
>   docker rm -f db-server
>   docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_DB=mydb -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword postgres:15-alpine
>   # (Chờ 3-5 giây)
>   docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"
>   ```
> - **Kết quả cần hiển thị trên ảnh:**
>   - Lệnh xóa `docker rm -f db-server` thành công.
>   - Container mới được khởi tạo với ID mới.
>   - Bảng kết quả truy vấn `SELECT * FROM users;` **vẫn hiển thị đầy đủ 2 bản ghi** (`Nguyen Van A`, `Tran Thi B`), chứng minh dữ liệu lưu trên Volume không bị mất.
