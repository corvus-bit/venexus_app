import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchResultItem> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _results = appState.search(value));
  }

  @override
  Widget build(BuildContext context) {
    return VenexusShell(
      title: appState.t('search.title'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(title: appState.t('search.title'), description: appState.t('search.placeholder'), accentColor: AppColors.blue),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: appState.t('search.placeholder')),
          ),
          const SizedBox(height: 16),
          if (_controller.text.trim().length < 2)
            InlineNotice(title: appState.t('common.search'), text: appState.t('search.minChars'), accentColor: AppColors.yellow)
          else if (_results.isEmpty)
            InlineNotice(title: appState.t('common.search'), text: appState.t('search.empty'), accentColor: AppColors.red)
          else
            ..._results.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: item.route == null ? null : () => Navigator.pushNamed(context, item.route!),
                    child: SectionCard(
                      accentColor: AppColors.blue,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.blue))),
                            child: const Icon(Icons.search, color: AppColors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(item.type, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gray600, height: 1.55)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.gray300),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
