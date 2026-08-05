import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/language_manager.dart';
import '../services/auth_service.dart';
import '../services/image_cache_service.dart';
import '../services/rate_app_service.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import '../services/push_notification_service.dart';
import '../services/consent_service.dart';
import '../services/review_reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageManager _languageManager = LanguageManager();
  final AuthService _authService = AuthService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final ConsentService _consentService = ConsentService();
  int _cacheSize = 0;
  bool _isLoadingCacheSize = true;
  String _appVersionLabel = '—';

  bool _pushNotificationsEnabled = true;
  bool _grammarReviewNotif = true;
  bool _streakRiskNotif = true;
  bool _dailyPracticeNotif = true;
  bool _wordOfDayNotif = true;
  bool _speakingReviewNotif = true;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _loadPushPreference();
    _loadNotificationPreferences();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    if (kIsWeb) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersionLabel = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _appVersionLabel = '—');
      }
    }
  }

  Future<void> _loadPushPreference() async {
    final enabled = await PushNotificationService.instance.getEpisodePushEnabled();
    if (mounted) {
      setState(() {
        _pushNotificationsEnabled = enabled;
      });
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final reminder = ReviewReminderService();
    final grammar = await reminder.getPreference(ReviewReminderService.prefGrammarReview);
    final streak = await reminder.getPreference(ReviewReminderService.prefStreakRisk);
    final daily = await reminder.getPreference(ReviewReminderService.prefDailyPractice);
    final word = await reminder.getPreference(ReviewReminderService.prefWordOfDay);
    final speaking = await reminder.getPreference(ReviewReminderService.prefSpeakingReview);
    if (mounted) {
      setState(() {
        _grammarReviewNotif = grammar;
        _streakRiskNotif = streak;
        _dailyPracticeNotif = daily;
        _wordOfDayNotif = word;
        _speakingReviewNotif = speaking;
      });
    }
  }

  Future<void> _setReminderPref(String key, bool value) async {
    await ReviewReminderService().setPreference(key, value);
  }

  Future<void> _loadCacheSize() async {
    final size = await _imageCacheService.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _isLoadingCacheSize = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, child) {
        return Scaffold(
          body: Column(
            children: [
              // Custom Header
              _buildHeader(),

              const SizedBox(height: 16),
              
              // Body content
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Text(
        _languageManager.getText('settings'),
        style: theme.textTheme.headlineSmall!.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: FloatingBottomNavBar.scrollPadding(
        context,
        left: 16,
        top: 16,
        right: 16,
        bottom: 16,
      ),
      children: [
        // Authentication Section
        _buildAuthSection(),
        const SizedBox(height: 16),
        
        // Language Section
        _buildLanguageSection(),
        const SizedBox(height: 16),

        // Theme Section
        _buildThemeSection(),
        const SizedBox(height: 16),

        // Cache Section
        _buildCacheSection(),
        const SizedBox(height: 16),

        // Rate App Section
        _buildRateAppSection(),
        const SizedBox(height: 16),

        // Notification Section
        _buildNotificationSection(),
        const SizedBox(height: 16),

        // Privacy options (CMP / UMP)
        if (!kIsWeb) ...[
          _buildPrivacyOptionsSection(),
          const SizedBox(height: 16),
        ],

        // About Section
        //_buildAboutSection(),
      ],
    );
  }

  Widget _buildAuthSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_authService.isLoggedIn) ...[
              Column(
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 40,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _languageManager.getText('account'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _languageManager.getText('loginToSync'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_authService.isLoggedIn) ...[
              _buildUserInfo(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: Text(_languageManager.getText('logout')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isDeletingAccount ? null : _handleDeleteAccount,
                  icon: _isDeletingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(_languageManager.getText('deleteAccount')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAuthDialog(true),
                      icon: const Icon(Icons.login),
                      label: Text(_languageManager.getText('login')),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAuthDialog(false),
                      icon: const Icon(Icons.person_add),
                      label: Text(_languageManager.getText('register')),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildOrSignInWithSeparator(),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.iOS) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleAppleLogin(),
                        icon: const Icon(Icons.apple, size: 20),
                        label: const Text('Apple'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleGoogleLogin(),
                      icon: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              'https://developers.google.com/identity/images/g-logo.png',
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      label: const Text('Google'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrSignInWithSeparator() {
    final lineColor = Colors.grey[300]!;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        );
    return Row(
      children: [
        Expanded(child: Divider(color: lineColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _languageManager.getText('orSignInWith'),
            style: textStyle,
          ),
        ),
        Expanded(child: Divider(color: lineColor, thickness: 1)),
      ],
    );
  }

  Widget _buildUserInfo() {
    final user = _authService.currentUser!;
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _languageManager.getText('syncedToCloud'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showAuthDialog(bool isLogin) {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(isLogin: isLogin),
    );
  }

  Future<void> _handleAppleLogin() async {
    try {
      final result = await _authService.loginWithApple();

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageManager.getText('loginSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? _languageManager.getText('unknownError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_languageManager.getText('unknownError')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      final result = await _authService.loginWithGoogle();
      
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageManager.getText('loginSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? _languageManager.getText('unknownError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_languageManager.getText('unknownError')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageManager.getText('logout')),
        content: Text(_languageManager.getText('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageManager.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_languageManager.getText('logout')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('logoutSuccess')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageManager.getText('deleteAccountConfirmTitle')),
        content: Text(_languageManager.getText('deleteAccountConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageManager.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text(_languageManager.getText('deleteAccount')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runDeleteAccount();
  }

  Future<void> _runDeleteAccount({String? password}) async {
    setState(() => _isDeletingAccount = true);

    AuthResult result;
    try {
      result = await _authService.deleteAccount(password: password);
    } catch (e) {
      result = AuthResult.error('$e');
    }

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('deleteAccountSuccess')),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (result.error == AuthService.requiresRecentLoginCode) {
      final enteredPassword = await _promptPasswordForDelete();
      if (enteredPassword == null || enteredPassword.isEmpty || !mounted) {
        return;
      }
      await _runDeleteAccount(password: enteredPassword);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error != null && result.error!.isNotEmpty
              ? '${_languageManager.getText('deleteAccountFailed')}: ${result.error}'
              : _languageManager.getText('deleteAccountFailed'),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<String?> _promptPasswordForDelete() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageManager.getText('reauthRequired')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_languageManager.getText('enterPasswordToDelete')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _languageManager.getText('password'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageManager.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text(_languageManager.getText('deleteAccount')),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  Widget _buildCacheSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('imageCache'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('manageImageCache'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _languageManager.getText('cacheSize'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                _isLoadingCacheSize
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _imageCacheService.formatCacheSize(_cacheSize),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleClearCache,
                    icon: const Icon(Icons.clear_all),
                    label: Text(_languageManager.getText('clearCache')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleRefreshCacheSize,
                    icon: const Icon(Icons.refresh),
                    label: Text(_languageManager.getText('refresh')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageManager.getText('clearImageCacheDialogTitle')),
        content: Text(_languageManager.getText('clearImageCacheDialogBody')),
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

    if (confirmed == true) {
      await _imageCacheService.clearCache();
      await _loadCacheSize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageManager.getText('clearImageCacheSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _handleRefreshCacheSize() async {
    await _loadCacheSize();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _languageManager.getText('pushNotifications'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('notificationDescription'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildNotificationToggle(
              label: _languageManager.getText('enablePushNotifications'),
              value: _pushNotificationsEnabled,
              onChanged: (value) async {
                setState(() => _pushNotificationsEnabled = value);
                await PushNotificationService.instance.setEpisodePushEnabled(value);
              },
            ),
            _buildNotificationToggle(
              label: _languageManager.getText('notifGrammarReview'),
              value: _grammarReviewNotif,
              onChanged: (value) async {
                setState(() => _grammarReviewNotif = value);
                await _setReminderPref(ReviewReminderService.prefGrammarReview, value);
              },
            ),
            _buildNotificationToggle(
              label: _languageManager.getText('notifStreakRisk'),
              value: _streakRiskNotif,
              onChanged: (value) async {
                setState(() => _streakRiskNotif = value);
                await _setReminderPref(ReviewReminderService.prefStreakRisk, value);
              },
            ),
            _buildNotificationToggle(
              label: _languageManager.getText('notifDailyPractice'),
              value: _dailyPracticeNotif,
              onChanged: (value) async {
                setState(() => _dailyPracticeNotif = value);
                await _setReminderPref(ReviewReminderService.prefDailyPractice, value);
              },
            ),
            _buildNotificationToggle(
              label: _languageManager.getText('notifWordOfDay'),
              value: _wordOfDayNotif,
              onChanged: (value) async {
                setState(() => _wordOfDayNotif = value);
                await _setReminderPref(ReviewReminderService.prefWordOfDay, value);
              },
            ),
            _buildNotificationToggle(
              label: _languageManager.getText('notifSpeakingReview'),
              value: _speakingReviewNotif,
              onChanged: (value) async {
                setState(() => _speakingReviewNotif = value);
                await _setReminderPref(ReviewReminderService.prefSpeakingReview, value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _languageManager.getText('notificationFeatureNote'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.orange,
    );
  }

  Widget _buildPrivacyOptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _languageManager.getText('adPrivacyOptionsTitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<PrivacyOptionsRequirementStatus>(
              future: _consentService.refreshConsentState().then(
                    (_) => _consentService.privacyOptionsRequirementStatus,
                  ),
              builder: (context, snapshot) {
                final status = snapshot.data;
                final statusLabel = switch (status) {
                  PrivacyOptionsRequirementStatus.required =>
                    _languageManager.getText('privacyOptionsStatusRequired'),
                  PrivacyOptionsRequirementStatus.notRequired =>
                    _languageManager.getText('privacyOptionsStatusNotRequired'),
                  _ => _languageManager.getText('privacyOptionsStatusUpdating'),
                };

                return Text(
                  _languageManager.getTextWithParams(
                    'privacyOptionsStatusLabel',
                    {'status': statusLabel},
                  ),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _consentService.refreshConsentState();
                  final requirementStatus =
                      _consentService.privacyOptionsRequirementStatus;

                  if (requirementStatus !=
                      PrivacyOptionsRequirementStatus.required) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _languageManager
                              .getText('privacyOptionsNotRequiredInfo'),
                        ),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                    setState(() {});
                    return;
                  }

                  final errorMessage =
                      await _consentService.showPrivacyOptionsForm();
                  if (!mounted) return;

                  if (errorMessage == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _languageManager
                              .getText('privacyOptionsUpdateSuccess'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _languageManager.getTextWithParams(
                            'privacyOptionsOpenError',
                            {'error': errorMessage},
                          ),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  setState(() {});
                },
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(
                  _languageManager.getText('managePrivacyChoices'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('language'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('selectLanguage'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _languageManager,
              builder: (context, child) {
                return DropdownButtonFormField<Locale>(
                  value: _languageManager.currentLocale,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      _languageManager.changeLanguage(newLocale);
                    }
                  },
                  items: LanguageManager.sortedSupportedLocales
                      .map<DropdownMenuItem<Locale>>((Locale locale) {
                    return DropdownMenuItem<Locale>(
                      value: locale,
                      child: Text(_languageManager.getLanguageName(locale.languageCode)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette, color: Colors.purple),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('theme'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('selectTheme'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _languageManager,
              builder: (context, child) {
                return DropdownButtonFormField<String>(
                  value: _languageManager.currentTheme,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (String? newTheme) {
                    if (newTheme != null) {
                      _languageManager.changeTheme(newTheme);
                    }
                  },
                  items: ['light', 'dark', 'system'].map<DropdownMenuItem<String>>((String theme) {
                    return DropdownMenuItem<String>(
                      value: theme,
                      child: Text(_languageManager.getThemeName(theme)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('about'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('aboutMessage'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _languageManager.getText('version'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _appVersionLabel,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _languageManager.getText('developer'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'BBC Learning Team',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateAppSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('rateAppInSettings'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('rateAppMessage'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await RateAppService.markAsRated();
                  await RateAppService.openStore();
                },
                icon: const Icon(Icons.star),
                label: Text(_languageManager.getText('rateNow')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}