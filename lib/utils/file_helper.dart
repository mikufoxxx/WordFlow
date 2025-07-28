import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件操作帮助类
class FileHelper {
  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 11+ 需要特殊处理
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      
      // 兼容旧版本Android
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
      ].request();
      
      return statuses[Permission.storage]?.isGranted ?? false;
    } else if (Platform.isIOS) {
      // iOS不需要特殊权限
      return true;
    }
    return false;
  }

  /// 选择导出目录
  static Future<String?> selectExportDirectory() async {
    try {
      // 请求权限
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception('存储权限被拒绝');
      }

      // 选择目录
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      return selectedDirectory;
    } catch (e) {
      throw Exception('选择目录失败: $e');
    }
  }

  /// 选择导入文件
  static Future<PlatformFile?> selectImportFile() async {
    try {
      // 请求权限
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception('存储权限被拒绝');
      }

      // 选择CSV文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.first;
      }
      return null;
    } catch (e) {
      throw Exception('选择文件失败: $e');
    }
  }

  /// 获取默认导出目录
  static Future<String> getDefaultExportDirectory() async {
    if (Platform.isAndroid) {
      // Android: 使用Downloads目录
      Directory? downloadsDir;
      try {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!downloadsDir.existsSync()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } catch (e) {
        downloadsDir = await getExternalStorageDirectory();
      }
      return downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;
    } else if (Platform.isIOS) {
      // iOS: 使用Documents目录
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      // 其他平台
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  /// 保存文件到指定目录
  static Future<String> saveFile(String directory, String fileName, String content) async {
    final file = File('$directory/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return file.path;
  }

  /// 读取文件内容
  static Future<String> readFile(String filePath) async {
    final file = File(filePath);
    return await file.readAsString(encoding: utf8);
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 创建目录
  static Future<void> createDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// 获取文件大小（格式化字符串）
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
} 