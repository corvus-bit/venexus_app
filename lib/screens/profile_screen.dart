import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _avatarPath;
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    final user = appState.currentUser!;
    _name = TextEditingController(text: user.name);
    _phone = TextEditingController(text: user.phone);
    _email = TextEditingController(text: user.email);
    _address = TextEditingController(text: user.address);
    _avatarPath = user.avatarPath;
    _language = user.language ?? appState.language;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 72, maxWidth: 1200);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarPath = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    await _saveProfile();
  }

  Future<void> _saveProfile({bool clearAvatar = false}) async {
    final error = await appState.updateProfile(
      name: _name.text,
      phone: _phone.text,
      address: _address.text,
      language: _language,
      avatarPath: _avatarPath,
      clearAvatar: clearAvatar,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('profile.saved'))));
    setState(() => _avatarPath = appState.currentUser?.avatarPath);
  }

  Future<void> _changePassword() async {
    final error = await appState.changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
      confirmPassword: _confirmPassword.text,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('profile.passwordSaved'))));
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser!;
    final isAdmin = user.role == UserRole.admin;

    return VenexusShell(
      title: appState.t('profile.title'),
      currentIndex: 4,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(title: appState.t('profile.title'), description: appState.t('profile.description'), accentColor: AppColors.blue),
          const SizedBox(height: 16),
          SectionCard(
            accentColor: AppColors.blue,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.gray50,
                    border: Border.fromBorderSide(BorderSide(color: AppColors.yellow)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: decodeStoredImage(_avatarPath) != null
                      ? StoredImage(value: _avatarPath, width: 80, height: 80)
                      : const Icon(Icons.account_circle_outlined, size: 64, color: AppColors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(color: AppColors.purple, fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
                      const SizedBox(height: 4),
                      Text(user.email, style: const TextStyle(color: AppColors.gray600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      if (isAdmin) ...[const SizedBox(height: 8), const AdminBadge()],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileSection(
            icon: Icons.camera_alt_outlined,
            title: appState.t('profile.photoTitle'),
            description: appState.language == AppLanguage.es ? 'Agrega o cambia tu imagen de perfil.' : 'Adicione ou altere sua imagem de perfil.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(onPressed: _pickAvatar, icon: const Icon(Icons.image_outlined), label: Text(appState.t('profile.uploadPhoto').toUpperCase())),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _avatarPath == null || _avatarPath!.isEmpty
                      ? null
                      : () async {
                          setState(() => _avatarPath = null);
                          await _saveProfile(clearAvatar: true);
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(appState.t('profile.removePhoto').toUpperCase()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileSection(
            icon: Icons.person_outline,
            title: appState.t('profile.personalTitle'),
            description: appState.language == AppLanguage.es ? 'Actualiza tus datos, dirección e idioma.' : 'Atualize seus dados, endereço e idioma.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_name, appState.t('auth.name')),
                _field(_phone, appState.t('auth.phone'), keyboardType: TextInputType.phone),
                _field(
                  _email,
                  appState.t('auth.email'),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true,
                ),
                _field(_address, appState.t('auth.address')),
                DropdownButtonFormField<AppLanguage>(
                  initialValue: _language,
                  decoration: InputDecoration(labelText: appState.t('common.language')),
                  items: [
                    DropdownMenuItem(value: AppLanguage.ptBR, child: Text(appState.t('common.portuguese'))),
                    DropdownMenuItem(value: AppLanguage.es, child: Text(appState.t('common.spanish'))),
                  ],
                  onChanged: (value) => setState(() => _language = value ?? AppLanguage.ptBR),
                ),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: () => _saveProfile(), child: Text(appState.t('profile.saveData').toUpperCase())),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileSection(
            icon: Icons.lock_outline,
            title: appState.t('profile.securityTitle'),
            description: appState.language == AppLanguage.es ? 'Cambia tu contraseña de acceso.' : 'Altere sua senha de acesso.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_currentPassword, appState.t('profile.currentPassword'), obscureText: true),
                _field(_newPassword, appState.t('profile.newPassword'), obscureText: true),
                _field(_confirmPassword, appState.t('profile.confirmPassword'), obscureText: true),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: _changePassword, child: Text(appState.t('profile.changePassword').toUpperCase())),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            _ProfileSection(
              icon: Icons.verified_user_outlined,
              title: appState.t('profile.permissionsTitle'),
              description: appState.t('profile.permissionsDescription'),
              child: InlineNotice(
                title: 'Admin: $senaiDomain',
                text: appState.t('profile.adminCanPublish'),
                accentColor: AppColors.yellow,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _ProfileSection(
            icon: Icons.shield_outlined,
            title: appState.t('profile.lgpdTitle'),
            description: appState.t('profile.lgpdDescription'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.gray50,
                border: Border(left: BorderSide(color: AppColors.yellow, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versão: ${user.lgpdVersion ?? lgpdVersion}', style: const TextStyle(color: AppColors.gray700, height: 1.55)),
                  Text('Aceite: ${user.lgpdAcceptedAt ?? 'Não registrado'}', style: const TextStyle(color: AppColors.gray700, height: 1.55)),
                  const SizedBox(height: 8),
                  Text(appState.t('profile.lgpdData'), style: const TextStyle(color: AppColors.gray700, height: 1.55)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.icon, required this.title, required this.description, required this.child});

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      accentColor: AppColors.blue,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.blue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.purple, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(description, style: const TextStyle(color: AppColors.gray600, fontSize: 13, height: 1.55)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
