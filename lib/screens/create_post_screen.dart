import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _images = [];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 72);
    if (files.isEmpty) return;
    final encoded = <String>[];
    for (final file in files.take(3)) {
      final bytes = await file.readAsBytes();
      encoded.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    setState(() {
      _images
        ..clear()
        ..addAll(encoded);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final error = await appState.addPost(title: _title.text, body: _body.text, images: _images);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/forum', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return VenexusShell(
      title: appState.t('forum.newPost'),
      currentIndex: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(route: '/forum'),
          PageIntro(title: appState.t('forum.newPost'), description: 'Compartilhe uma dúvida, experiência ou orientação para a comunidade.', accentColor: AppColors.yellow),
          const SizedBox(height: 16),
          SectionCard(
            accentColor: AppColors.yellow,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 12),
                TextField(controller: _body, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Conteúdo')),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.image_outlined), label: const Text('Adicionar até 3 imagens')),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _images
                        .map((value) => Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.gray200))),
                              clipBehavior: Clip.hardEdge,
                              child: StoredImage(value: value, height: 80, width: 80),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _submit, child: Text(appState.t('common.save').toUpperCase())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
