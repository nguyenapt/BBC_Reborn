import 'package:flutter/material.dart';
import '../services/language_manager.dart';
import '../utils/lle_level_groups.dart';
import 'compact_ghost_badge.dart';

class LevelFilterChipsRow extends StatelessWidget {
  final String selectedFilter;
  final List<String> availableLevels;
  final ValueChanged<String> onSelect;
  final LanguageManager languageManager;

  const LevelFilterChipsRow({
    super.key,
    required this.selectedFilter,
    required this.availableLevels,
    required this.onSelect,
    required this.languageManager,
  });

  String _levelLabel(String levelKey) {
    if (levelKey == LleLevelGroups.otherKey) {
      return languageManager.getText('lleLevelOther');
    }
    return levelKey;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    final chips = <String>[
      LleLevelGroups.allFilterKey,
      ...availableLevels,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final filter = chips[i];
                final isAll = filter == LleLevelGroups.allFilterKey;
                final isSelected = selectedFilter == filter;
                final color = isAll
                    ? strongAccent
                    : (filter == 'A1' || filter == 'A2'
                        ? strongAccent
                        : colorScheme.tertiary);
                return InkWell(
                  onTap: () => onSelect(filter),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: CompactGhostBadge(
                      icon: isAll
                          ? Icons.grid_view_rounded
                          : Icons.school_outlined,
                      label: isAll
                          ? languageManager.getText('lleLevelAll')
                          : _levelLabel(filter),
                      color: isSelected
                          ? color
                          : colorScheme.onSurface.withOpacity(0.45),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
