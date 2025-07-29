import 'package:audioplayers/audioplayers.dart';

/// 音效服务类 - 提供统一的音效播放功能
class SoundService {
  /// 播放记住音效
  static void playRememberSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/remember.mp3'));
    
    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放忘记音效
  static void playForgotSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/forgot.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放点击音效
  static void playTapSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/tapin.mp3'));
    
    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放句子结果音效
  static void playResultSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/showdetail.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放成功音效
  static void playSuccessSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/success.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放错误音效
  static void playErrorSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/error.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放选择书籍音效
  static void playChooseBookSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/choosebook.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放选择按钮音效
  static void playChooseButtonSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/choosebuttonnew.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放下载成功音效
  static void playDownloadSuccessSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/downloadsuccess.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放加载音效
  static void playLoadingSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/loading.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放开关关闭音效
  static void playSwitchOffSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/switchoff.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放开关开启音效
  static void playSwitchOnSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/switchon.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }

  /// 播放点击关闭音效
  static void playTapOffSound() async {
    // 为每次播放创建独立的音频播放器实例
    final player = AudioPlayer();
    await player.setVolume(1);
    await player.play(AssetSource('sound/tapoff.mp3'));

    // 播放完成后释放资源
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  }
}