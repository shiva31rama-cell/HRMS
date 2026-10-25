import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onAuthenticated});
  final ApiService api;
  final ValueChanged<Map<String, dynamic>> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _staffLogin = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final body = <String, dynamic>{'email': _email.text.trim(), 'password': _password.text};
      final path = _register ? '/auth/register' : '/auth/login';
      if (_register) {
        body['name'] = _name.text.trim();
        body['phone'] = _phone.text.trim();
      }
      final data = Map<String, dynamic>.from(await widget.api.post(path, body) as Map);
      final user = Map<String, dynamic>.from(data['user'] as Map);
      if (_staffLogin && !['admin', 'warden'].contains(user['role'])) {
        setState(() => _error = 'This account is not an admin or warden account. Use student sign-in.');
        return;
      }
      await widget.api.setToken(data['token'].toString());
      if (mounted) widget.onAuthenticated(user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 18 : 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: compact
                  ? _formCard()
                  : Row(children: [
                      Expanded(child: _welcomeCard()),
                      const SizedBox(width: 26),
                      SizedBox(width: 400, child: _formCard()),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFF145B4B), Color(0xFF27856C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 34),
      ),
      const SizedBox(height: 40),
      const Text('A simpler way to manage hostel life.',
          style: TextStyle(color: Colors.white, fontSize: 34, height: 1.15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Text('Room allocation, student support, and hostel updates in one workspace.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 16, height: 1.5)),
      const SizedBox(height: 32),
      const _Feature(icon: Icons.meeting_room_outlined, label: 'Room and bed occupancy'),
      const SizedBox(height: 14),
      const _Feature(icon: Icons.handyman_outlined, label: 'Maintenance tracking'),
      const SizedBox(height: 14),
      const _Feature(icon: Icons.campaign_outlined, label: 'Official hostel notices'),
      const SizedBox(height: 38),
      Text('HOSTEL ROOM MANAGEMENT SYSTEM',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.68), letterSpacing: 1.2, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _formCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(27),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE5F4ED), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.apartment_rounded, color: Color(0xFF176B58)),
            ),
            const SizedBox(width: 12),
            const Text('HostelHub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 30),
          Text(
              _register ? 'Create your account' : _staffLogin ? 'Admin / staff sign in' : 'Welcome back',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              _register
                  ? 'Register a student account to get started.'
                  : _staffLogin
                      ? 'Use your administrator or warden account.'
                      : 'Sign in to continue to your hostel workspace.',
              style: const TextStyle(color: Color(0xFF68766F), height: 1.4)),
          const SizedBox(height: 22),
          if (_register) ...[
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)), validator: _required),
            const SizedBox(height: 13),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 13),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
            validator: (value) => value != null && value.contains('@') && value.contains('.') ? null : 'Enter a valid email.',
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
            ),
            validator: (value) => value != null && value.length >= 8 ? null : 'Use at least 8 characters.',
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFF9A3030))),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_register ? Icons.person_add_alt_1 : Icons.login_rounded),
              label: Text(_busy
                  ? 'Please wait…'
                  : _register
                      ? 'Create account'
                      : _staffLogin
                          ? 'Staff sign in'
                          : 'Sign in'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => setState(() {
                if (_register) {
                  _register = false;
                  _staffLogin = false;
                } else if (_staffLogin) {
                  _staffLogin = false;
                } else {
                  _register = true;
                }
                _error = null;
              }),
              child: Text(_register
                  ? 'Already registered? Sign in'
                  : _staffLogin
                      ? 'Use regular sign in'
                      : 'New student? Create an account'),
            ),
          ),
          if (!_register) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => setState(() {
                  _staffLogin = !_staffLogin;
                  _error = null;
                }),
                icon: Icon(_staffLogin ? Icons.person_outline : Icons.admin_panel_settings_outlined),
                label: Text(_staffLogin ? 'Student sign in' : 'Admin / Staff sign in'),
              ),
            ),
          ],
          const Text(
            'Staff accounts are created by the administrator. Student registration never grants staff access.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF68766F), fontSize: 11, height: 1.4),
          ),
        ]),
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFFC0F0E0), size: 22),
    const SizedBox(width: 12),
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
  ]);
}
