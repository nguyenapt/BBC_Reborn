import 'package:flutter/material.dart';

import '../services/app_cache_manager.dart';
import '../services/language_manager.dart';

/// Bottom sheet checklist để chọn và xóa từng loại cache.
class ClearCacheBottomSheet extends StatefulWidget {
  const ClearCacheBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const ClearCacheBottomSheet(),
    );
  }

  @override
  State<ClearCacheBottomSheet> createState() => _ClearCacheBottomSheetState();
}

class _ClearCacheBottomSheetState extends State<ClearCacheBottomSheet> {
  final AppCacheManager _cacheManager = AppCacheManager();
  final LanguageManager _languageManager = LanguageManager();

  List<CacheCategoryInfo> _categories = const [];
  final Set<AppCacheCategory> _selected = {};
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final infos = await _cacheManager.getCategoryInfos();
    if (!mounted) return;
    setState(() {
      _categories = infos;
      _selected
        ..clear()
        ..addAll(
          infos.where((c) => c.selectedByDefault).map((c) => c.id),
        );
      _isLoading = false;
    });
  }

  String _titleFor(AppCacheCategory id) {
    switch (id) {
      case AppCacheCategory.images:
        return _languageManager.getText('cacheCategoryImages');
      case AppCacheCategory.audioStream:
        return _languageManager.getText('cacheCategoryAudioStream');
      case AppCacheCategory.downloads:
        return _languageManager.getText('cacheCategoryDownloads');
      case AppCacheCategory.aiLocal:
        return _languageManager.getText('cacheCategoryAiLocal');
    }
  }

  String _subtitleFor(AppCacheCategory id) {
    switch (id) {
      case AppCacheCategory.images:
        return _languageManager.getText('cacheCategoryImagesDesc');
      case AppCacheCategory.audioStream:
        return _languageManager.getText('cacheCategoryAudioStreamDesc');
      case AppCacheCategory.downloads:
        return _languageManager.getText('cacheCategoryDownloadsDesc');
      case AppCacheCategory.aiLocal:
        return _languageManager.getText('cacheCategoryAiLocalDesc');
    }
  }

  IconData _iconFor(AppCacheCategory id) {
    switch (id) {
      case AppCacheCategory.images:
        return Icons.image_outlined;
      case AppCacheCategory.audioStream:
        return Icons.headphones_outlined;
      case AppCacheCategory.downloads:
        return Icons.download_outlined;
      case AppCacheCategory.aiLocal:
        return Icons.smart_toy_outlined;
    }
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      _selected.clear();
      if (selectAll) {
        _selected.addAll(_categories.map((c) => c.id));
      }
    });
  }

  Future<void> _handleClear() async {
    if (_selected.isEmpty || _isClearing) return;

    final selectedLabels = _categories
        .where((c) => _selected.contains(c.id))
        .map((c) => _titleFor(c.id))
        .join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageManager.getText('clearCacheConfirmTitle')),
        content: Text(
          _languageManager
              .getText('clearCacheConfirmBody')
              .replaceAll('{items}', selectedLabels),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageManager.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_languageManager.getText('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await _cacheManager.clear(Set<AppCacheCategory>.from(_selected));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isClearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('clearCacheFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final allSelected =
        _categories.isNotEmpty && _selected.length == _categories.length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _languageManager.getText('manageAppCache'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _languageManager.getText('manageAppCacheHint'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isClearing
                      ? null
                      : () => _toggleSelectAll(!allSelected),
                  child: Text(
                    allSelected
                        ? _languageManager.getText('deselectAll')
                        : _languageManager.getText('selectAll'),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _categories[index];
                    final checked = _selected.contains(item.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: _isClearing
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(item.id);
                                } else {
                                  _selected.remove(item.id);
                                }
                              });
                            },
                      secondary: Icon(_iconFor(item.id)),
                      title: Text(_titleFor(item.id)),
                      subtitle: Text(
                        '${_subtitleFor(item.id)}\n'
                        '${_cacheManager.formatSize(item.sizeBytes)}',
                      ),
                      isThreeLine: true,
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    _selected.isEmpty || _isClearing ? null : _handleClear,
                icon: _isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_languageManager.getText('clearSelectedCache')),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
