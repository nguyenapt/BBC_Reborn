import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_remote_config.dart';
import '../services/app_update_service.dart';
import '../services/language_manager.dart';

/// Hiển thị dialog nhắc cập nhật dựa trên RTDB [AppUpdate].
class AppUpdateCoordinator {
  AppUpdateCoordinator._();

  static bool _dialogShowing = false;
  static DateTime? _lastCheckStarted;

  static const _resumeMinGap = Duration(seconds: 30);
  static const _prefsDismissToken = 'app_update_soft_dismiss_token';

  static String _softDismissToken(AppUpdateRemoteConfig c) {
    return '${c.latestBuild ?? 0}|${c.latestVersion ?? ''}';
  }

  static Future<bool> _shouldSkipOptional(AppUpdateRemoteConfig c) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsDismissToken);
    return saved != null && saved == _softDismissToken(c);
  }

  static Future<void> _saveOptionalDismissed(AppUpdateRemoteConfig c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDismissToken, _softDismissToken(c));
  }

  static Widget _updateIcon(BuildContext context) {
    return Icon(
      Icons.system_update_rounded,
      size: 32,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  /// Tiêu đề dialog: dùng style chuẩn [titleLarge] và **đậm** rõ ràng.
  static Widget _dialogTitle(BuildContext context, String text) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Text(
      text,
      style: style?.copyWith(fontWeight: FontWeight.w700) ??
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
    );
  }

  /// [fromResume]: true khi app quay lại foreground (có throttle nhẹ).
  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool fromResume = false,
  }) async {
    if (kIsWeb) return;
    if (_dialogShowing) return;
    if (!context.mounted) return;
    if (fromResume &&
        _lastCheckStarted != null &&
        DateTime.now().difference(_lastCheckStarted!) < _resumeMinGap) {
      return;
    }
    _lastCheckStarted = DateTime.now();

    final outcome = await AppUpdateService.instance.check(
      bypassCache: fromResume,
    );
    if (!context.mounted) return;
    if (outcome.urgency == AppUpdateUrgency.none) return;

    if (outcome.urgency == AppUpdateUrgency.optional) {
      if (await _shouldSkipOptional(outcome.config)) return;
    }
    if (!context.mounted) return;

    _dialogShowing = true;
    final lang = LanguageManager();
    try {
      if (outcome.urgency == AppUpdateUrgency.forced) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              icon: _updateIcon(ctx),
              title: _dialogTitle(
                ctx,
                outcome.config.updateTitle?.isNotEmpty == true
                    ? outcome.config.updateTitle!
                    : lang.getText('appUpdateTitle'),
              ),
              content: Text(
                outcome.config.updateMessage?.isNotEmpty == true
                    ? outcome.config.updateMessage!
                    : lang.getText('appUpdateMessageForced'),
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    final ok =
                        await AppUpdateService.instance.tryAndroidImmediateUpdate();
                    if (!ctx.mounted) return;
                    if (!ok) {
                      await AppUpdateService.instance.openStore(
                        outcome.config,
                        defaultTargetPlatform,
                      );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(lang.getText('appUpdateButtonUpdate')),
                ),
              ],
            );
          },
        );
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return AlertDialog(
              icon: _updateIcon(ctx),
              title: _dialogTitle(
                ctx,
                outcome.config.updateTitle?.isNotEmpty == true
                    ? outcome.config.updateTitle!
                    : lang.getText('appUpdateTitle'),
              ),
              content: Text(
                outcome.config.updateMessage?.isNotEmpty == true
                    ? outcome.config.updateMessage!
                    : lang.getText('appUpdateMessageSoft'),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _saveOptionalDismissed(outcome.config);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(lang.getText('appUpdateButtonLater')),
                ),
                FilledButton(
                  onPressed: () async {
                    final started = await AppUpdateService.instance
                        .tryAndroidFlexibleUpdate();
                    if (!ctx.mounted) return;
                    if (!started) {
                      await AppUpdateService.instance.openStore(
                        outcome.config,
                        defaultTargetPlatform,
                      );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(lang.getText('appUpdateButtonUpdate')),
                ),
              ],
            );
          },
        );
      }
    } finally {
      _dialogShowing = false;
    }
  }
}
