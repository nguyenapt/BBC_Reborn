import 'package:flutter/material.dart';

/// Shared chrome for passage overview blocks and in-flow native ads in grammar UI.
BoxDecoration passageOverviewPanelDecoration(BuildContext context) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.35),
  );
}
