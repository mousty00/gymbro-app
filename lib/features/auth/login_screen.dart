import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import 'auth_widgets.dart';
import 'session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).login(_username.text, _password.text);
      // il router porta in home
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isEmailNotVerified) {
        showMessage(context, 'Verifica prima la tua email con il codice che ti abbiamo inviato.');
        context.push('/auth/verify?username=${Uri.encodeComponent(_username.text.trim())}');
      } else {
        showMessage(context, e.statusCode == 401 ? 'Username o password non corretti' : e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Bentornato',
      subtitle: 'Accedi per riprendere i tuoi allenamenti.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                LabeledField(
                  label: 'Username',
                  controller: _username,
                  hint: 'il_tuo_username',
                  validator: requiredField,
                  autofillHints: const [AutofillHints.username],
                ),
                PasswordField(controller: _password, validator: requiredField, onSubmitted: (_) => _submit()),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/auth/forgot'),
            child: const Text('Password dimenticata?'),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Accedi', loading: _loading, onPressed: _submit),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.pushReplacement('/auth/signup'),
            child: const Text.rich(
              TextSpan(
                text: 'Non hai un account? ',
                style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500),
                children: [TextSpan(text: 'Registrati', style: TextStyle(color: AppColors.blue))],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
