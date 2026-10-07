import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/game_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/game_button.dart';
import 'home_shell.dart';

/// Animated splash that auto-resumes a session, else offers sign-in.
class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({super.key});

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _checking = true;
  bool _busy = false;
  bool _signUp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  @override
  void dispose() {
    _anim.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    final auth = context.read<AuthService>();
    await Future<void>.delayed(const Duration(milliseconds: 1200)); // let the logo breathe
    final uid = auth.currentUid;
    if (uid != null) {
      await _enter(uid);
    } else if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _enter(String uid) async {
    final name = _name.text.trim().isEmpty ? null : _name.text.trim();
    await context.read<GameController>().signIn(uid, displayName: name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const HomeShell(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _enter(await action());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1B6B), Color(0xFF13104A), Color(0xFF07373F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, -8 * _anim.value),
                      child: Transform.rotate(angle: (_anim.value - 0.5) * 0.12, child: child),
                    ),
                    child: const Text('🗺️', style: TextStyle(fontSize: 92)),
                  ),
                  const SizedBox(height: 8),
                  ShaderMask(
                    shaderCallback: (r) =>
                        const LinearGradient(colors: [AppColors.teal, AppColors.gold]).createShader(r),
                    child: const Text(
                      'WalkQuest 3D',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const Text('Every step is an adventure.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 40),
                  if (_checking) const CircularProgressIndicator(color: AppColors.teal) else _form(auth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(AuthService auth) {
    return Column(
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Hero name', prefixIcon: Icon(Icons.shield_rounded)),
        ),
        if (auth.firebaseEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_rounded)),
          ),
          const SizedBox(height: 18),
          GameButton(
            label: _signUp ? 'Create account' : 'Sign in',
            icon: Icons.login_rounded,
            busy: _busy,
            onPressed: () => _run(
              () => _signUp
                  ? auth.signUpWithEmail(_email.text, _password.text)
                  : auth.signInWithEmail(_email.text, _password.text),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _signUp = !_signUp),
            child: Text(
              _signUp ? 'Have an account? Sign in' : 'New here? Create an account',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ] else
          const SizedBox(height: 18),
        GameButton(
          label: 'Play as Guest',
          icon: Icons.play_arrow_rounded,
          gradient: AppColors.gradientGo,
          busy: _busy && !auth.firebaseEnabled,
          onPressed: () => _run(auth.signInAsGuest),
        ),
        if (!auth.firebaseEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Offline mode — progress is saved on this device.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF8A80)),
            ),
          ),
      ],
    );
  }
}
