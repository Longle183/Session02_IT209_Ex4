#!/usr/bin/env bash
# ==============================================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Script: commands.sh
# ==============================================================================

# Thoát ngay lập tức nếu có bất kỳ lệnh nào bị lỗi
set -e

echo "=== [BƯỚC 1] Dọn dẹp tài nguyên cũ (nếu có) ==="
docker rm -f app-container db-server 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true
echo "=> Dọn dẹp hoàn tất."
echo ""

echo "=== [BƯỚC 2] Tạo Custom Bridge Network và Named Volume ==="
# 1. Tạo Custom Bridge Network tên 'app-net'
docker network create --driver bridge app-net

# 2. Tạo Named Volume tên 'db-data'
docker volume create db-data

echo "=> Kiểm tra danh sách Network và Volume vừa tạo:"
docker network ls | grep app-net
docker volume ls | grep db-data
echo ""

echo "=== [BƯỚC 3] Khởi chạy Database Container (PostgreSQL 15) ==="
# Khởi chạy postgres:15-alpine tên 'db-server' tham gia network 'app-net'
# Mount volume 'db-data' vào thư mục dữ liệu chuẩn của Postgres
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine

echo "=> Đang chờ db-server khởi động hoàn tất (5s)..."
sleep 5
echo ""

echo "=== [BƯỚC 4] Khởi chạy Backend Container ==="
# Khởi chạy Backend Container tham gia 'app-net', truyền hostname DB là 'db-server'
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=mydb \
  -e DB_USER=myuser \
  -e DB_PASSWORD=mypassword \
  alpine:latest sh -c "tail -f /dev/null"

echo "=> Danh sách các container đang chạy:"
docker ps
echo ""

echo "=== [BƯỚC 5] Kiểm tra Network & DNS Resolution (Ping) ==="
echo "--- 5.1. Inspect network 'app-net' ---"
docker network inspect app-net

echo "--- 5.2. Ping db-server từ Backend (app-container) qua hostname ---"
docker exec -i app-container ping -c 2 db-server
echo ""

echo "=== [BƯỚC 6] Kiểm tra Data Persistence (Lưu trữ bền vững) ==="
echo "--- 6.1. Tạo bảng và thêm dữ liệu vào db-server ---"
docker exec -i db-server psql -U myuser -d mydb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50), email VARCHAR(50));"
docker exec -i db-server psql -U myuser -d mydb -c "INSERT INTO users (name, email) VALUES ('Nguyen Van A', 'vana@example.com'), ('Tran Thi B', 'thib@example.com');"

echo "--- 6.2. Truy vấn dữ liệu ban đầu ---"
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"

echo "--- 6.3. Xóa cứng container db-server (docker rm -f) ---"
docker rm -f db-server

echo "--- 6.4. Khởi chạy container db-server mới gắn cùng Volume db-data ---"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine

echo "=> Đang chờ container db-server mới khởi động (5s)..."
sleep 5

echo "--- 6.5. Xác minh dữ liệu không bị mất trong container mới ---"
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"

echo ""
echo "=============================================================================="
echo "=> THÀNH CÔNG: Toàn bộ quá trình kiểm tra Custom Network & Volume hoàn tất!"
echo "=============================================================================="
