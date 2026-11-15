# مجهول — دردشة عشوائية (MVP)

## 1) Supabase (مجاني)
1. أنشئ مشروعاً على supabase.com.
2. SQL Editor ← الصق محتوى `schema.sql` ← Run.
3. Project Settings ← API: انسخ Project URL و anon key إلى `config.js`.
4. Authentication ← Providers: فعّل Email (للتجربة عطّل Confirm email).
5. لتفعيل Google: أنشئ OAuth Client في Google Cloud، والصق Client ID/Secret في Supabase، وأضف رابط callback الذي يعرضه Supabase في Google.

## 2) GitHub
1. أنشئ مستودعاً جديداً وارفع كل الملفات (بدون الـ zip).
2. Settings ← Pages ← Deploy from branch ← main / root.
3. سيظهر رابط مثل `https://USER.github.io/REPO/`.
4. في Supabase: Authentication ← URL Configuration: ضع هذا الرابط في Site URL و Redirect URLs.

## 3) على الهاتف
افتح الرابط في Chrome (أندرويد) أو Safari (آيفون) ← "إضافة إلى الشاشة الرئيسية".

## إدارة البلاغات
Table Editor ← reports. لحظر مستخدم: Authentication ← Users ← Ban user.
