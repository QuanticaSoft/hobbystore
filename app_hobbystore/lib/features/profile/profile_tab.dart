import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_retry.dart';
import '../session/user.dart';
import '../session/user_session.dart';

class ProfileTab extends StatelessWidget {
  final OtpAuth auth;

  const ProfileTab({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final user = session.user;

    final Widget body;
    if (user != null) {
      body = _ProfileForm(user: user, auth: auth);
    } else if (session.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ErrorRetry(
        message: session.errorMessage ?? 'No se pudo cargar tu perfil.',
        onRetry: session.load,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: body,
    );
  }
}

class _ProfileForm extends StatefulWidget {
  final User user;
  final OtpAuth auth;

  const _ProfileForm({required this.user, required this.auth});

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  static const _maxLength = 60;

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.user.displayName,
  );
  late final _cityController = TextEditingController(text: widget.user.city);

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Campo requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<UserSession>().updateProfile(
        displayName: _nameController.text,
        city: _cityController.text,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_android),
            title: const Text('Teléfono'),
            subtitle: Text(widget.user.phone),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
            textCapitalization: TextCapitalization.words,
            maxLength: _maxLength,
            validator: _required,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'Ciudad'),
            textCapitalization: TextCapitalization.words,
            maxLength: _maxLength,
            validator: _required,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => widget.auth.logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
