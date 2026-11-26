# Run Tracker

แอป Flutter บันทึกการวิ่ง เชื่อม Supabase สำหรับ Authentication และฐานข้อมูล PostgreSQL

## ตั้งค่า Supabase

1. สร้าง Supabase project แล้วเปิด **SQL Editor**
2. สำหรับโปรเจกต์ใหม่ ให้คัดลอกและรัน [`supabase/schema.sql`](supabase/schema.sql) เพื่อสร้างตาราง `run_tb`, เปิด RLS และสร้าง bucket `run-images` พร้อม policies หากรัน schema รุ่นก่อนหน้านี้ไปแล้ว ให้รัน [`supabase/add_run_image_path.sql`](supabase/add_run_image_path.sql) เพื่อเพิ่มคอลัมน์เก็บ path ของรูป
3. คัดลอก Project URL และ publishable key จากหน้า Project Connect ของ Supabase
4. เปิด **Anonymous Sign-Ins** ใน Supabase Dashboard ที่ Authentication > Sign In / Providers เพื่อให้แอปสร้างบัญชีแบบไม่ต้องกรอกอีเมลหรือรหัสผ่าน

สร้างไฟล์ตั้งค่า local จากตัวอย่าง แล้วใส่ Project URL และ publishable key ของคุณ:

```sh
cp supabase.local.json.example supabase.local.json
```

แก้ `supabase.local.json` ให้เป็นรูปแบบนี้:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

จากนั้นรัน:

```sh
flutter run --dart-define-from-file=supabase.local.json
```

ไฟล์ `supabase.local.json` ถูกเพิ่มไว้ใน `.gitignore` เพื่อไม่ให้ค่าตั้งค่าของเครื่องถูก commit ใช้เฉพาะ publishable key (`sb_publishable_...`) สำหรับแอป client ห้ามใส่ secret key หรือ `service_role` key ในแอป Flutter

หากไม่ส่งค่าตั้งค่า Supabase แอปจะเปิดด้วยข้อมูลตัวอย่างในเครื่อง เมื่อใส่ URL และ publishable key ถูกต้อง แอปจะเข้าสู่ระบบแบบไม่ระบุตัวตนโดยอัตโนมัติ แล้วอ่านและบันทึกข้อมูลผ่าน Supabase โดยไม่ต้องกรอกอีเมลหรือรหัสผ่าน

## โครงสร้างข้อมูล

ตาราง `public.run_tb` เก็บ `user_id`, `place`, `distance_km`, `duration_minutes`, `run_date`, `note`, `image_path` และ `created_at` โดย RLS จำกัดให้ผู้ใช้เข้าถึงแถวของตนเองเท่านั้น ส่วน bucket `run-images` เป็น private และกำหนด path เป็น `<user_id>/<filename>` แอปสร้าง signed URL ชั่วคราวเพื่อแสดงรูป โดยไม่เปิด bucket เป็นสาธารณะ

หน้าบันทึกเลือกรูปจากอัลบั้มได้ รองรับ JPG, PNG, WebP และ HEIC เมื่อเชื่อม Supabase แอปจะอัปโหลดรูปก่อนบันทึกรายการ หากบันทึกรายการไม่สำเร็จ แอปจะลบไฟล์ที่อัปโหลดค้างไว้ออก
