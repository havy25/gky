import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_errors.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text);
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
                    const Icon(Icons.bakery_dining,
                        size: 64, color: Color(0xFF8D5524)),
                    const SizedBox(height: 8),
                    Text('Tiệm Bánh Ngọt - Admin',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email không hợp lệ'
                          : null,
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : FilledButton(
                              onPressed: _login,
                              child: const Text('Đăng nhập')),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterPage())),
                      child: const Text('Chưa có tài khoản? Tạo tài khoản mới'),
                    ),
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
