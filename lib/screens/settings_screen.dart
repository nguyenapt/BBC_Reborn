import 'package:flutter/material.dart';
import '../services/language_manager.dart';
import '../services/auth_service.dart';
import '../services/image_cache_service.dart';
import '../widgets/auth_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageManager _languageManager = LanguageManager();
  final AuthService _authService = AuthService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  int _cacheSize = 0;
  bool _isLoadingCacheSize = true;
  
  // Notification settings - tạm thời để đó, sẽ phát triển sau
  bool _pushNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
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
          appBar: AppBar(
            title: Text(_languageManager.getText('settings')),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Authentication Section
              _buildAuthSection(),
              const SizedBox(height: 16),
              
              // Language Section
          Card(
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
                        items: LanguageManager.supportedLocales.map<DropdownMenuItem<Locale>>((Locale locale) {
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
          ),
          
          const SizedBox(height: 16),
          
          // Theme Section
          Card(
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
          ),
          
          const SizedBox(height: 16),
          
          // Font Size Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.text_fields, color: Colors.orange),
                      const SizedBox(width: 12),
                      Text(
                        _languageManager.getText('fontSize'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _languageManager.getText('selectFontSize'),
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
                        value: _languageManager.currentFontSize,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (String? newFontSize) {
                          if (newFontSize != null) {
                            _languageManager.changeFontSize(newFontSize);
                          }
                        },
                        items: ['small', 'normal', 'large'].map<DropdownMenuItem<String>>((String fontSize) {
                          return DropdownMenuItem<String>(
                            value: fontSize,
                            child: Text(_languageManager.getFontSizeName(fontSize)),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Cache Management Section
          _buildCacheSection(),
          const SizedBox(height: 16),
          
          // Notification Settings Section
          _buildNotificationSection(),
          const SizedBox(height: 16),
          
          
          
            ],
          ),
        );
      },
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 12),
                Text(
                  _languageManager.getText('account'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_authService.isLoggedIn) ...[
              // User info when logged in
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
            ] else ...[
              // Login/Register buttons when not logged in
              Text(
                _languageManager.getText('loginToSync'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              // Google login button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleGoogleLogin(),
                  icon: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage('https://developers.google.com/identity/images/g-logo.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  label: Text(_languageManager.getText('loginWithGoogle')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _authService.currentUser!;
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('logoutSuccess')),
          backgroundColor: Colors.green,
        ),
      );
    }
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
        title: const Text('Xóa Cache'),
        content: const Text('Bạn có chắc chắn muốn xóa tất cả cache hình ảnh?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _imageCacheService.clearCache();
      await _loadCacheSize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa cache thành công'),
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
                Text(
                  _languageManager.getText('pushNotifications'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _languageManager.getText('enablePushNotifications'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _pushNotificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _pushNotificationsEnabled = value;
                    });
                    // TODO: Implement notification settings logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value 
                            ? _languageManager.getText('notificationsEnabled')
                            : _languageManager.getText('notificationsDisabled')
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  activeColor: Colors.orange,
                ),
              ],
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
}