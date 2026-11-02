/// ============================================================================
/// ไฟล์ตั้งค่าการเชื่อมต่อฐานข้อมูล Supabase (Supabase Configuration)
/// ============================================================================
/// คุณสามารถนำค่า Project URL และ API Key (anon / public) จากหน้าเว็บ
/// Supabase Dashboard -> Project Settings -> API มาวางใส่ในตัวแปรด้านล่างได้เลย
/// หรือจะกดปุ่ม "ตั้งค่า Supabase" (ไอคอนมุมขวาบน) บนหน้าแอปเพื่อกรอกผ่านหน้าจอก็ได้
library;

class SupabaseConfig {
  /// 1. ใส่ Project URL ของคุณที่นี่ (เช่น 'https://xxxxxxxxxxxx.supabase.co')
  static const String defaultSupabaseUrl =
      'https://phfoxgelnxtorhhdanmt.supabase.co';

  /// 2. ใส่ API Key (anon / public) ของคุณที่นี่ (ขึ้นต้นด้วย 'eyJ...')
  static const String defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoZm94Z2Vsbnh0b3JoaGRhbm10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM1NjU5MjYsImV4cCI6MjEwOTE0MTkyNn0.Jjs_a0H1TjRkUykkctyTnmCkwWgGvELyjznuk2Lowto';

  /// ชื่อตารางในฐานข้อมูล Supabase
  static const String devicesTable = 'devices';
}
