import 'package:dukkan/services/app_language.dart';

class Strings {
  static final Map<String, Map<String, String>> _dict = {
    'ar': {
      'follow': 'متابعة',
      'following': 'تتابعه',
      'share': 'مشاركة',
      'message': 'رسالة',
      'search': 'بحث',
      'add_to_cart': 'إضافة للسلة',
      'settings': 'الإعدادات',
      'notifications_enable': 'تفعيل الإشعارات',
      'privacy_policy': 'سياسة الخصوصية',
      'terms': 'الشروط والأحكام',
      'support_contact': 'الدعم / اتصل بنا',
      'delete_account': 'حذف الحساب',
      'following_tab': 'المتابَعون',
      'no_results': 'لا توجد نتائج',
      'search_hint': 'ابحث عن منتج...',
      'product_name': 'اسم المنتج',
      'product_desc': 'وصف المنتج',
      'product_price': 'سعر المنتج',
      'category_label': 'القسم',
      'media_pick': 'صورة / فيديو المنتج',
      'image_selected': 'تم اختيار صورة',
      'choose_image': 'اختر صورة',
      'video_selected': 'تم اختيار فيديو',
      'choose_video': 'اختر فيديو',
      'video_upload_info': 'سيتم رفع هذا الفيديو وعرضه في صفحة الريلز',
      'options': 'الخيارات',
      'add_option': 'إضافة خيار',
      'publish_product': 'نشر المنتج',
      'required_fields': 'الرجاء إدخال جميع الحقول المطلوبة واختيار القسم',
      'select_media_or_url':
          'الرجاء اختيار صورة/فيديو أو إدخال رابط صورة للمنتج',
      'product_saved': 'تم حفظ المنتج في Firestore',
      'login_to_view_profile': 'الرجاء تسجيل الدخول لعرض الملف الشخصي',
      'my_orders': 'طلباتي',
      'seller_dashboard': 'لوحة البائع',
      'admin_dashboard': 'لوحة المدير',
      'edit_profile': 'تعديل الملف الشخصي',
      'logout': 'تسجيل الخروج',
    },
    'en': {
      'follow': 'Follow',
      'following': 'Following',
      'share': 'Share',
      'message': 'Message',
      'search': 'Search',
      'add_to_cart': 'Add to cart',
      'settings': 'Settings',
      'notifications_enable': 'Enable notifications',
      'privacy_policy': 'Privacy Policy',
      'terms': 'Terms & Conditions',
      'support_contact': 'Support / Contact Us',
      'delete_account': 'Delete Account',
      'following_tab': 'Following',
      'no_results': 'No results',
      'search_hint': 'Search products...',
      'product_name': 'Product Name',
      'product_desc': 'Product Description',
      'product_price': 'Product Price',
      'category_label': 'Category',
      'media_pick': 'Product Image / Video',
      'image_selected': 'Image selected',
      'choose_image': 'Choose image',
      'video_selected': 'Video selected',
      'choose_video': 'Choose video',
      'video_upload_info': 'This video will be uploaded and shown in Reels',
      'options': 'Options',
      'add_option': 'Add option',
      'publish_product': 'Publish Product',
      'required_fields': 'Please fill all required fields and choose category',
      'select_media_or_url': 'Please select image/video or enter an image URL',
      'product_saved': 'Product saved to Firestore',
      'login_to_view_profile': 'Please log in to view profile',
      'my_orders': 'My Orders',
      'seller_dashboard': 'Seller Dashboard',
      'admin_dashboard': 'Admin Dashboard',
      'edit_profile': 'Edit Profile',
      'logout': 'Log out',
    },
  };

  static String t(String key) {
    final lang = AppLanguage.instance.lang.value;
    return _dict[lang]?[key] ?? _dict['ar']?[key] ?? key;
  }

  static String category(String name) {
    final lang = AppLanguage.instance.lang.value;
    if (lang == 'ar') return name;
    const Map<String, String> map = {
      'الكل': 'All',
      'مواد التجميل': 'Cosmetics',
      'ملابس نسائية': 'Women Fashion',
      'أطفال': 'Kids',
      'مركبات': 'Vehicles',
      'مواد منزلية': 'Home Goods',
      'غذائية': 'Groceries',
      'كتب وأدوات مكتبية': 'Books & Stationery',
      'رياضة وترفيه': 'Sports & Entertainment',
      'حيوانات أليفة': 'Pets',
      'أجهزة إلكترونية': 'Electronics',
      'خدمات': 'Services',
      'أخرى': 'Other',
      // إضافات لصفحة النشر
      'الكترونيات': 'Electronics',
      'كهربائيات': 'Electricals',
      'البسة رجالية': 'Men Fashion',
      'البسة نسائية': 'Women Fashion',
      'ألعاب': 'Toys',
    };
    return map[name] ?? name;
  }

  static String gender(String name) {
    final lang = AppLanguage.instance.lang.value;
    if (lang == 'ar') return name;
    const Map<String, String> map = {'ذكر': 'Male', 'أنثى': 'Female'};
    return map[name] ?? name;
  }

  static String country(String name) {
    final lang = AppLanguage.instance.lang.value;
    if (lang == 'ar') return name;
    const Map<String, String> map = {
      'السعودية': 'Saudi Arabia',
      'الإمارات': 'United Arab Emirates',
      'قطر': 'Qatar',
      'الكويت': 'Kuwait',
      'البحرين': 'Bahrain',
      'عمان': 'Oman',
      'اليمن': 'Yemen',
      'مصر': 'Egypt',
      'الأردن': 'Jordan',
      'سوريا': 'Syria',
      'لبنان': 'Lebanon',
      'العراق': 'Iraq',
      'المغرب': 'Morocco',
      'الجزائر': 'Algeria',
      'تونس': 'Tunisia',
      'السودان': 'Sudan',
    };
    return map[name] ?? name;
  }
}
