# 📊 Hướng Dẫn Tính Năng Group Trailing & Tỉa Lệnh

## 🎯 1. Group Trailing (Trailing Theo Nhóm)

### Cách hoạt động:
- EA chia các lệnh DCA Âm thành **nhiều nhóm** dựa trên thứ tự mở lệnh
- Mỗi nhóm có **điểm hòa vốn riêng** và được trailing độc lập
- Khi 1 nhóm đạt lợi nhuận → đóng nhóm đó, không ảnh hưởng nhóm khác

### Ví dụ thực tế:

| Nhóm | Lệnh thuộc nhóm | Điểm hòa vốn | Trạng thái |
|------|-----------------|--------------|------------|
| Nhóm 1 | Lệnh 1-4 | 2745.00 | ✅ Đang lời 200 pip → Đang trailing |
| Nhóm 2 | Lệnh 5-9 | 2760.00 | ⏳ Chưa đủ lời → Chờ giá |
| Nhóm 3 | Lệnh 10-14 | 2780.00 | ⏳ Chưa đủ lời → Chờ giá |

**Kết quả:** Nhóm 1 đóng lời độc lập, Nhóm 2 & 3 vẫn tiếp tục chạy.

---

## 💰 2. Quỹ Tỉa Lệnh (Fund-Based Trimming)

### Cách hoạt động:
1. **Tích lũy quỹ:** Mỗi khi lệnh đóng lời → lợi nhuận được cộng vào quỹ
2. **Tỉa lệnh:** Khi quỹ đủ → dùng quỹ để đóng lệnh xa nhất đang lỗ
3. **Reset quỹ:** Sau khi tỉa xong → quỹ về 0, bắt đầu chu kỳ mới

### Ví dụ thực tế:

**Bước 1 - Tích lũy:**
- Lệnh #1 đóng lời: +$5 → Quỹ Buy = $5
- Lệnh #2 đóng lời: +$8 → Quỹ Buy = $13
- Lệnh #3 đóng lời: +$12 → Quỹ Buy = $25

**Bước 2 - Tỉa:**
- Lệnh xa nhất đang lỗ: -$20
- Mục tiêu lời sau tỉa: $5
- Cần: $20 + $5 = $25
- Quỹ có: $25 ✅ ĐỦ → Đóng lệnh lỗ

**Bước 3 - Reset:**
- Quỹ Buy = $0
- Bắt đầu tích lũy lại từ đầu

---

## 📋 Thứ Tự Ưu Tiên Tỉa Lệnh

| Ưu tiên | Loại lệnh | Mô tả |
|---------|-----------|-------|
| 1️⃣ | DCA Dương | Lệnh thuận xu hướng bị lỗ |
| 2️⃣ | Initial | Lệnh đầu tiên bị lỗ |
| 3️⃣ | DCA Âm | Lệnh ngược xu hướng bị lỗ |

---

## ⚡ Lưu Ý Quan Trọng

1. **Quỹ Buy và Quỹ Sell** hoạt động độc lập
2. **Trailing từng nhóm** giúp chốt lời nhanh hơn, không phải chờ toàn bộ lệnh
