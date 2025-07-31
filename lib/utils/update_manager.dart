import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_helper.dart';

/// 更新管理器 - 处理应用的后台下载和安装
class UpdateManager {
  static final Dio _dio = Dio();
  static String? _downloadPath;
  static CancelToken? _cancelToken;

  /// 下载并安装更新（简化版本，用于兼容性）
  static Future<bool> downloadAndInstall(
    VersionInfo versionInfo,
    Function(double) onProgress,
  ) async {
    return await downloadAndInstallUpdate(
      null, // context可以为null
      versionInfo,
      onProgress,
      (status) {}, // 空的状态回调
    );
  }

  /// 检查并下载更新
  static Future<bool> downloadAndInstallUpdate(
    BuildContext? context,
    VersionInfo versionInfo,
    Function(double) onProgress,
    Function(String) onStatusChange,
  ) async {
    try {
      // 检查平台支持
      if (!Platform.isAndroid) {
        onStatusChange('当前仅支持Android平台的自动更新');
        return false;
      }

      // 检查权限
      if (!await _checkPermissions()) {
        onStatusChange('需要存储权限才能下载更新');
        return false;
      }

      // 获取下载URL
      final downloadUrl = await _getDirectDownloadUrl(versionInfo.downloadUrl);
      if (downloadUrl == null) {
        onStatusChange('无法获取下载链接');
        return false;
      }

      // 准备下载路径
      final downloadPath = await _prepareDownloadPath(versionInfo.version);
      if (downloadPath == null) {
        onStatusChange('无法创建下载目录');
        return false;
      }

      _downloadPath = downloadPath;
      _cancelToken = CancelToken();

      onStatusChange('开始下载更新包...');

      // 下载文件
      await _dio.download(
        downloadUrl,
        downloadPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            onStatusChange('下载中... ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      onStatusChange('下载完成，准备安装...');

      // 安装APK
      final installResult = await _installApk(downloadPath);
      if (installResult) {
        onStatusChange('安装包已准备就绪');
        return true;
      } else {
        onStatusChange('安装失败');
        return false;
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        onStatusChange('下载已取消');
      } else {
        onStatusChange('下载失败: ${e.toString()}');
      }
      return false;
    }
  }

  /// 取消下载
  static void cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
    _cancelToken = null;
  }

  /// 清理下载文件
  static Future<void> cleanupDownloadFile() async {
    if (_downloadPath != null && File(_downloadPath!).existsSync()) {
      try {
        await File(_downloadPath!).delete();
      } catch (e) {
        debugPrint('清理下载文件失败: $e');
      }
    }
    _downloadPath = null;
  }

  /// 检查必要权限
  static Future<bool> _checkPermissions() async {
    // Android 13+ 不需要存储权限
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    
    if (androidInfo.version.sdkInt >= 33) {
      // Android 13+ 只需要安装权限
      return await Permission.requestInstallPackages.request().isGranted;
    } else {
      // Android 12 及以下需要存储权限
      final storageStatus = await Permission.storage.request();
      final installStatus = await Permission.requestInstallPackages.request();
      return storageStatus.isGranted && installStatus.isGranted;
    }
  }

  /// 获取直接下载链接
  static Future<String?> _getDirectDownloadUrl(String downloadUrl) async {
    try {
      // 现在downloadUrl已经是完整的代理下载链接，直接返回
      // 格式: http://git.techox.cc/https://github.com/mikufoxxx/WordFlow/releases/download/v1.0.4/app-release.apk
      
      if (downloadUrl.isNotEmpty) {
        // 可以选择验证URL是否有效（可选）
        try {
          final response = await _dio.head(downloadUrl);
          if (response.statusCode == 200) {
            return downloadUrl;
          }
        } catch (e) {
          // 如果验证失败，仍然返回URL，让下载时处理错误
          debugPrint('验证下载链接时出错: $e');
          return downloadUrl;
        }
      }
      
      return downloadUrl.isNotEmpty ? downloadUrl : null;
    } catch (e) {
      debugPrint('获取下载链接失败: $e');
      return null;
    }
  }

  /// 准备下载路径
  static Future<String?> _prepareDownloadPath(String version) async {
    try {
      Directory downloadDir;
      
      if (Platform.isAndroid) {
        // Android: 使用外部存储的Download目录
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          downloadDir = Directory('${externalDir.path}/Download');
        } else {
          // 备用方案：使用应用文档目录
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else {
        // 其他平台使用应用文档目录
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (!downloadDir.existsSync()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = 'wordflow-v$version.apk';
      final filePath = '${downloadDir.path}/$fileName';
      
      // 如果文件已存在，删除旧文件
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      return filePath;
    } catch (e) {
      debugPrint('准备下载路径失败: $e');
      return null;
    }
  }

  /// 安装APK文件
  static Future<bool> _installApk(String apkPath) async {
    try {
      if (!File(apkPath).existsSync()) {
        debugPrint('APK文件不存在: $apkPath');
        return false;
      }

      // 使用open_filex打开APK文件，让系统处理安装
      final result = await OpenFilex.open(apkPath);
      
      // OpenFilex.open 返回 OpenResult 对象
      // type 为 ResultType.done 表示成功打开
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('打开APK文件失败: $e');
      return false;
    }
  }

  /// 获取下载进度文本
  static String getProgressText(double progress) {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}