import 'package:firebase_auth/firebase_auth.dart';

/// Chuyển mã lỗi của Firebase Auth sang thông báo tiếng Việt
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Email này đã được đăng ký';
    case 'invalid-email':
      return 'Email không hợp lệ';
    case 'weak-password':
      return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
    case 'operation-not-allowed':
      return 'Chưa bật đăng nhập Email/Password trên Firebase Console';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Sai email hoặc mật khẩu';
    case 'user-disabled':
      return 'Tài khoản đã bị vô hiệu hóa';
    case 'too-many-requests':
      return 'Thử quá nhiều lần, vui lòng đợi một lúc';
    case 'network-request-failed':
      return 'Lỗi kết nối mạng';
    default:
      return e.message ?? 'Có lỗi xảy ra';
  }
}
