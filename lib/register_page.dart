import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_errors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Lưu tên hiển thị vào Firebase Auth (không tạo thêm collection nào
      // trong Firestore, giữ đúng yêu cầu chỉ có 4 trường của sản phẩm)
      await cred.user?.updateDisplayName(_name.text.trim());
      await cred.user?.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo tài khoản thành công')));
      // Đóng trang đăng ký; AuthGate ở main.dart tự chuyển sang trang sản phẩm
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add,
                        size: 64, color: Color(0xFF8D5524)),
                    const SizedBox(height: 8),
                    Text('Đăng ký tài khoản admin',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Họ tên', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nhập họ tên'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        final ok =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
                        return ok ? null : 'Email không hợp lệ';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePass,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePass
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu tối thiểu 6 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideConfirm,
                      decoration: InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hideConfirm
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _hideConfirm = !_hideConfirm),
                        ),
                      ),
                      validator: (v) => v != _password.text
                          ? 'Mật khẩu nhập lại không khớp'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : FilledButton(
                              onPressed: _register,
                              child: const Text('Đăng ký')),
                    ),
                    TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.pop(context),
                        child: const Text('Đã có tài khoản? Đăng nhập')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
