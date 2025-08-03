import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'settings_helper.dart';
import 'update_manager.dart';

/// 自动更新检测服务
/// 负责在应用启动和恢复时自动检查更新
class AutoUpdateService {
  static final AutoUpdateService _instance = AutoUpdateService._internal();
  factory AutoUpdateService() => _instance;
  AutoUpdateService._internal();

  static AutoUpdateService get instance => _instance;

  Timer? _updateCheckTimer;
  DateTime? _lastCheckTime;
  bool _isChecking = false;
  
  // 检查间隔（小时）- 延长到24小时，减少功耗和网络请求
  static const int _checkIntervalHours = 24;
  
  /// 初始化自动更新服务
  Future<void> initialize() async {
    await _loadLastCheckTime();
  }

  /// 加载上次检查时间
  Future<void> _loadLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckTimestamp = prefs.getInt('last_update_check_time');
    if (lastCheckTimestamp != null) {
      _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);
    }
  }

  /// 保存检查时间
  Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    _lastCheckTime = DateTime.now();
    await prefs.setInt('last_update_check_time', _lastCheckTime!.millisecondsSinceEpoch);
  }

  /// 检查是否需要进行更新检查
  bool _shouldCheckForUpdates() {
    if (_lastCheckTime == null) return true;
    
    final now = DateTime.now();
    final timeDifference = now.difference(_lastCheckTime!);
    return timeDifference.inHours >= _checkIntervalHours;
  }

  /// 应用启动时检查更新
  Future<void> checkOnAppStart(BuildContext context) async {
    if (!_shouldCheckForUpdates() || _isChecking) return;
    
    _isChecking = true;
    try {
      await _performUpdateCheck(context, isAutoCheck: true);
    } finally {
      _isChecking = false;
    }
  }

  /// 应用恢复时检查更新
  Future<void> checkOnAppResume(BuildContext context) async {
    if (!_shouldCheckForUpdates() || _isChecking) return;
    
    _isChecking = true;
    try {
      await _performUpdateCheck(context, isAutoCheck: true);
    } finally {
      _isChecking = false;
    }
  }

  /// 手动检查更新
  Future<void> checkManually(BuildContext context) async {
    if (_isChecking) return;
    
    _isChecking = true;
    try {
      await _performUpdateCheck(context, isAutoCheck: false);
    } finally {
      _isChecking = false;
    }
  }

  /// 执行更新检查
  Future<void> _performUpdateCheck(BuildContext context, {required bool isAutoCheck}) async {
    try {
      // 获取当前版本
      final packageInfo = await SettingsHelper.getPackageInfo();
      final currentVersion = packageInfo.version;
      
      // 检查更新
      final result = await SettingsHelper.checkForUpdates(currentVersion);
      
      if (result.hasUpdate && result.versionInfo != null) {
        // 保存检查时间
        await _saveLastCheckTime();
        
        // 显示更新对话框
        if (context.mounted) {
          _showUpdateDialog(context, result.versionInfo!, currentVersion, isAutoCheck);
        }
      } else if (!isAutoCheck) {
        // 手动检查时，即使没有更新也要提示
        if (context.mounted) {
          _showNoUpdateDialog(context);
        }
      }
      
      // 如果是自动检查且没有更新，也要保存检查时间
      if (isAutoCheck && !result.hasUpdate) {
        await _saveLastCheckTime();
      }
    } catch (e) {
      // 自动检查时不显示错误，手动检查时显示
      if (!isAutoCheck && context.mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(BuildContext context, VersionInfo versionInfo, String currentVersion, bool isAutoCheck) {
    final formattedNotes = SettingsHelper.formatReleaseNotes(versionInfo.releaseNotes);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(
        versionInfo: versionInfo,
        formattedNotes: formattedNotes,
        currentVersion: currentVersion,
        isAutoCheck: isAutoCheck,
      ),
    );
  }

  /// 显示无更新对话框
  void _showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('已是最新版本'),
          ],
        ),
        content: const Text('当前已是最新版本，无需更新。'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('检查更新失败'),
          ],
        ),
        content: Text('检查更新时发生错误：$error'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 停止自动检查
  void dispose() {
    _updateCheckTimer?.cancel();
    _updateCheckTimer = null;
  }
}

/// 更新对话框组件 - 支持后台下载和安装
class _UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;
  final String formattedNotes;
  final String currentVersion;
  final bool isAutoCheck;

  const _UpdateDialog({
    required this.versionInfo,
    required this.formattedNotes,
    required this.currentVersion,
    required this.isAutoCheck,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';
  bool _downloadCompleted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
      title: Row(
        children: [
          Icon(
            _isDownloading ? Icons.download : Icons.system_update,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(_isDownloading ? '正在更新' : '发现新版本'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isDownloading) ...[
                Text('当前版本: ${widget.currentVersion}'),
                const SizedBox(height: 8),
                Text('最新版本: ${widget.versionInfo.version}'),
                const SizedBox(height: 16),
                
                // 显示更新内容
                Text(
                  '更新内容:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                
                // 更新内容
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: widget.formattedNotes,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          height: 1.4,
                        ),
                        listBullet: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        h1: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        h2: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        h3: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        code: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                Text(
                  widget.isAutoCheck 
                      ? '检测到新版本，是否立即下载并安装？'
                      : '是否立即下载并安装更新？',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ] else ...[
                // 下载进度界面
                Column(
                  children: [
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[700] 
                          : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    if (_downloadCompleted) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '更新包已准备就绪，请按照系统提示完成安装',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('稍后更新'),
          ),
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('立即更新'),
          ),
        ] else if (!_downloadCompleted) ...[
          TextButton(
            onPressed: _cancelDownload,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('取消下载'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('完成'),
          ),
        ],
      ],
    );
  }

  /// 开始下载
  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusText = '正在准备下载...';
      _downloadProgress = 0.0;
    });

    try {
      final success = await UpdateManager.downloadAndInstall(
        widget.versionInfo,
        (progress) {
          setState(() {
            _downloadProgress = progress;
            _statusText = '正在下载更新包...';
          });
        },
      );
      
      if (success) {
        setState(() {
          _downloadCompleted = true;
          _statusText = '下载完成，正在安装...';
        });
      } else {
        setState(() {
          _isDownloading = false;
          _statusText = '';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('下载失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusText = '';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 取消下载
  Future<void> _cancelDownload() async {
    try {
      UpdateManager.cancelDownload();
      
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _statusText = '';
      });
    } catch (e) {
      // 忽略取消下载的错误
    }
  }
}