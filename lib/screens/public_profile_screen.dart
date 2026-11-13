import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final Future<PublicProfile?> _profile = appState.db.getPublicProfile(widget.userId);

  @override
  Widget build(BuildContext context) {
    return VenexusShell(
      title: appState.t('profile.publicTitle'),
      currentIndex: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(title: appState.t('profile.publicTitle'), description: appState.t('profile.originVisibility'), accentColor: AppColors.blue),
          const SizedBox(height: 16),
          FutureBuilder<PublicProfile?>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return SectionCard(child: Text(appState.t('profile.publicLoadFailed')));
              final profile = snapshot.data;
              if (profile == null) return SectionCard(child: Text(appState.t('profile.publicUnavailable')));

              final country = profile.originCountry?.trim();
              final region = profile.originRegion?.trim();
              return SectionCard(
                accentColor: AppColors.blue,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(color: AppColors.gray50),
                          child: profile.avatarPath == null || profile.avatarPath!.isEmpty
                              ? const Icon(Icons.account_circle_outlined, size: 52, color: AppColors.blue)
                              : StoredImage(value: profile.avatarPath, width: 64, height: 64),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(profile.name, style: const TextStyle(color: AppColors.purple, fontSize: 20, fontWeight: FontWeight.w800))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(appState.t('profile.originCountry'), style: const TextStyle(color: AppColors.gray600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(country == null || country.isEmpty ? appState.t('profile.originNotProvided') : country),
                    const SizedBox(height: 16),
                    Text(appState.t('profile.originRegion'), style: const TextStyle(color: AppColors.gray600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(region == null || region.isEmpty ? appState.t('profile.originNotProvided') : region),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
