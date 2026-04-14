import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';
import '../utils/llm_api_service.dart';
import '../utils/performance_optimizer.dart';

class AiProviderSettingsCard extends StatefulWidget {
  const AiProviderSettingsCard({
    super.key,
    required this.onAvailabilityChanged,
  });

  final ValueChanged<bool> onAvailabilityChanged;

  @override
  State<AiProviderSettingsCard> createState() => _AiProviderSettingsCardState();
}

class _AiProviderSettingsCardState extends State<AiProviderSettingsCard> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  Timer? _debounceTimer;

  LlmProviderType _provider = LlmProviderType.openAiCompatible;
  List<LlmModelInfo> _models = const <LlmModelInfo>[];
  String? _selectedModel;
  bool _showApiKey = false;
  bool _isLoadingModels = false;
  bool _isTestingConnection = false;
  bool _isInitializing = true;
  bool _isHydratingConfig = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _baseUrlController.addListener(_handleDraftChanged);
    _apiKeyController.addListener(_handleDraftChanged);
    _loadInitialConfig();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _baseUrlController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    _apiKeyController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialConfig() async {
    final config = await LlmApiService.getConfig();
    if (!mounted) {
      return;
    }

    _isHydratingConfig = true;
    setState(() {
      _provider = config.provider;
      _baseUrlController.text = config.baseUrl.isEmpty
          ? config.provider.suggestedBaseUrl
          : config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _selectedModel = config.model.isEmpty ? null : config.model;
      _isInitializing = false;
      _statusMessage = config.provider.helpText;
    });
    _isHydratingConfig = false;

    _notifyAvailability();

    if (_hasCredentials) {
      await _loadModels(
        showFeedback: false,
        saveSelection: true,
        preserveSelectionOnFailure: true,
      );
    }
  }

  bool get _hasCredentials {
    return _normalizedBaseUrl.isNotEmpty && _normalizedApiKey.length >= 10;
  }

  bool get _isReady {
    return _normalizedBaseUrl.isNotEmpty &&
        _normalizedApiKey.length >= 10 &&
        (_selectedModel?.trim().isNotEmpty ?? false);
  }

  String get _normalizedBaseUrl => _baseUrlController.text.trim();

  String get _normalizedApiKey => _apiKeyController.text.trim();

  Future<void> _handleDraftChanged() async {
    if (_isHydratingConfig) {
      return;
    }

    _debounceTimer?.cancel();
    await LlmApiService.updateConfig(
      provider: _provider,
      baseUrl: _normalizedBaseUrl,
      apiKey: _normalizedApiKey,
      model: _selectedModel ?? '',
    );

    _notifyAvailability();

    if (!_hasCredentials) {
      if (mounted) {
        setState(() {
          _models = const <LlmModelInfo>[];
          _selectedModel = null;
          _statusMessage = _provider.helpText;
        });
      }
      await LlmApiService.clearModelSelection();
      _notifyAvailability();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      _loadModels(showFeedback: false, saveSelection: true);
    });
  }

  Future<void> _handleProviderChanged(LlmProviderType? value) async {
    if (value == null) {
      return;
    }

    setState(() {
      _provider = value;
      _models = const <LlmModelInfo>[];
      _selectedModel = null;
      if (_baseUrlController.text.trim().isEmpty ||
          _baseUrlController.text.trim() == _provider.suggestedBaseUrl) {
        _baseUrlController.text = value.suggestedBaseUrl;
      }
      _statusMessage = value.helpText;
    });

    await LlmApiService.updateConfig(
      provider: value,
      baseUrl: _normalizedBaseUrl,
      apiKey: _normalizedApiKey,
      model: '',
    );
    _notifyAvailability();

    if (_hasCredentials) {
      await _loadModels(showFeedback: false, saveSelection: true);
    }
  }

  Future<void> _showProviderSelector() async {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor =
        isDarkMode ? AppTheme.darkPrimaryTextColor : AppTheme.darkGray;
    final Color subtitleColor =
        isDarkMode ? AppTheme.mediumGray : AppTheme.coolGray500;

    final LlmProviderType? selected = await showDialog<LlmProviderType>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor:
            isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: OptimizedText(
          '选择接口模式',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LlmProviderType.values.map((LlmProviderType item) {
              return RadioListTile<LlmProviderType>(
                key: ValueKey<String>('ai_provider_option_${item.name}'),
                title: OptimizedText(
                  item.displayName,
                  style: TextStyle(color: titleColor),
                ),
                subtitle: OptimizedText(
                  item.helpText,
                  style: TextStyle(color: subtitleColor),
                ),
                value: item,
                groupValue: _provider,
                onChanged: (LlmProviderType? value) {
                  Navigator.of(dialogContext).pop(value);
                },
                activeColor: isDarkMode
                    ? AppTheme.darkPrimaryGray
                    : AppTheme.primaryGray,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('ai_provider_selector_close_button'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (!mounted || selected == null || selected == _provider) {
      return;
    }

    await _handleProviderChanged(selected);
  }

  Future<void> _loadModels({
    required bool showFeedback,
    required bool saveSelection,
    bool preserveSelectionOnFailure = false,
  }) async {
    if (!_hasCredentials || _isLoadingModels) {
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _statusMessage = '正在获取模型列表...';
    });

    try {
      final models = await LlmApiService.fetchModels(
        provider: _provider,
        baseUrl: _normalizedBaseUrl,
        apiKey: _normalizedApiKey,
      );

      String? resolvedModel = _selectedModel;
      final hasCurrentModel = models.any((item) => item.id == resolvedModel);
      if (!hasCurrentModel) {
        resolvedModel = models.first.id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _models = models;
        _selectedModel = resolvedModel;
        _statusMessage = '已获取 ${models.length} 个模型';
      });

      if (saveSelection) {
        await LlmApiService.updateConfig(
          provider: _provider,
          baseUrl: _normalizedBaseUrl,
          apiKey: _normalizedApiKey,
          model: resolvedModel ?? '',
        );
      }

      _notifyAvailability();

      if (showFeedback && mounted) {
        _showSnackBar('模型列表获取成功，共 ${models.length} 个');
      }
    } on LlmApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _models = const <LlmModelInfo>[];
        if (!preserveSelectionOnFailure) {
          _selectedModel = null;
        }
        _statusMessage = error.message;
      });
      if (!preserveSelectionOnFailure) {
        await LlmApiService.updateConfig(model: '');
      }
      _notifyAvailability();

      if (showFeedback && mounted) {
        _showSnackBar(error.message);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _models = const <LlmModelInfo>[];
        if (!preserveSelectionOnFailure) {
          _selectedModel = null;
        }
        _statusMessage = '模型列表获取失败：$error';
      });
      if (!preserveSelectionOnFailure) {
        await LlmApiService.updateConfig(model: '');
      }
      _notifyAvailability();

      if (showFeedback && mounted) {
        _showSnackBar('模型列表获取失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_isTestingConnection) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _statusMessage = '正在测试连接...';
    });

    final result = await LlmApiService.testConnection(
      overrideConfig: LlmProviderConfig(
        provider: _provider,
        baseUrl: _normalizedBaseUrl,
        apiKey: _normalizedApiKey,
        model: _selectedModel ?? '',
      ),
      autoSelectFirstModel: true,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _models = result.models.isEmpty ? _models : result.models;
      _selectedModel = result.selectedModel ?? _selectedModel;
      _statusMessage = result.message;
      _isTestingConnection = false;
    });

    await LlmApiService.updateConfig(
      provider: _provider,
      baseUrl: _normalizedBaseUrl,
      apiKey: _normalizedApiKey,
      model: _selectedModel ?? '',
    );
    _notifyAvailability();
    _showSnackBar(result.message);
  }

  Future<void> _pasteApiKey() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty) {
      _showSnackBar('剪贴板为空');
      return;
    }

    _apiKeyController.text = value;
    _showSnackBar('API Key 已粘贴');
  }

  Future<void> _selectModel(String? value) async {
    if (value == null || value.isEmpty) {
      return;
    }

    setState(() {
      _selectedModel = value;
      _statusMessage = '当前模型：$value';
    });

    await LlmApiService.updateConfig(
      provider: _provider,
      baseUrl: _normalizedBaseUrl,
      apiKey: _normalizedApiKey,
      model: value,
    );
    _notifyAvailability();
  }

  Future<void> _showModelSelector() async {
    if (_isInitializing || _models.isEmpty) {
      return;
    }

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor =
        isDarkMode ? AppTheme.darkPrimaryTextColor : AppTheme.darkGray;
    final Color subtitleColor =
        isDarkMode ? AppTheme.mediumGray : AppTheme.coolGray500;

    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor:
            isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            OptimizedText(
              '选择模型',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            OptimizedText(
              '共 ${_models.length} 个可用模型',
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.52,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _models.length,
              itemBuilder: (BuildContext context, int index) {
                final LlmModelInfo item = _models[index];

                return RadioListTile<String>(
                  key: ValueKey<String>('ai_model_option_${item.id}'),
                  title: OptimizedText(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: titleColor),
                  ),
                  subtitle: item.ownedBy?.isNotEmpty == true
                      ? OptimizedText(
                          item.ownedBy!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subtitleColor),
                        )
                      : null,
                  value: item.id,
                  groupValue: _selectedModel,
                  onChanged: (String? value) {
                    Navigator.of(dialogContext).pop(value);
                  },
                  activeColor: isDarkMode
                      ? AppTheme.darkPrimaryGray
                      : AppTheme.primaryGray,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('ai_model_selector_close_button'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (!mounted || selected == null || selected == _selectedModel) {
      return;
    }

    await _selectModel(selected);
  }

  void _notifyAvailability() {
    widget.onAvailabilityChanged(_isReady);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.coolGray600
            : AppTheme.coolGray300,
      ),
    );
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _tileTitleColor =>
      _isDarkMode ? AppTheme.darkPrimaryTextColor : AppTheme.darkGray;

  Color get _tileSubtitleColor =>
      _isDarkMode ? AppTheme.mediumGray : AppTheme.coolGray500;

  Color get _dividerColor =>
      _isDarkMode ? Colors.white.withValues(alpha: 0.06) : AppTheme.coolGray200;

  String get _selectedModelLabel {
    final String selected = _selectedModel?.trim() ?? '';
    if (selected.isEmpty) {
      return '';
    }

    for (final LlmModelInfo item in _models) {
      if (item.id == selected) {
        return item.label;
      }
    }

    return selected;
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _tileSubtitleColor,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: _tileSubtitleColor,
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: OptimizedText(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _tileTitleColor,
        ),
      ),
    );
  }

  Widget _buildSelectorTile({
    required String tileKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
  }) {
    final Color mutedColor = _tileSubtitleColor.withValues(alpha: 0.6);

    return ListTile(
      key: ValueKey<String>(tileKey),
      leading: Icon(
        icon,
        color: enabled ? null : mutedColor,
      ),
      title: OptimizedText(
        title,
        style: TextStyle(
          color: enabled ? _tileTitleColor : mutedColor,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: enabled ? _tileSubtitleColor : mutedColor,
        ),
      ),
      trailing: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: enabled ? _tileSubtitleColor : mutedColor,
            ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildActionTile({
    required String tileKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
  }) {
    final Color mutedColor = _tileSubtitleColor.withValues(alpha: 0.6);

    return ListTile(
      key: ValueKey<String>(tileKey),
      leading: Icon(
        icon,
        color: enabled ? null : mutedColor,
      ),
      title: OptimizedText(
        title,
        style: TextStyle(
          color: enabled ? _tileTitleColor : mutedColor,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        style: TextStyle(
          color: enabled ? _tileSubtitleColor : mutedColor,
        ),
      ),
      trailing: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: enabled ? onTap : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String selectedModelLabel = _selectedModelLabel;
    final String modelSubtitle = _isInitializing
        ? '正在初始化模型配置...'
        : selectedModelLabel.isNotEmpty
            ? '当前：$selectedModelLabel'
            : _hasCredentials
                ? (_models.isEmpty ? '请先获取模型列表' : '点击选择可用模型')
                : '请先填写 Base URL 与 API Key';
    final String statusText =
        _statusMessage ?? (_isReady ? '当前配置可用于 AI 功能' : '请继续完成 AI 接口配置');

    return Padding(
      key: const ValueKey<String>('ai_provider_settings_card'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OptimizedText(
              '支持 OpenAI 兼容、Responses 与 Anthropic 三种协议，填写完整信息后可直接拉取模型列表。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _tileSubtitleColor,
              ),
            ),
          ),
          _buildSelectorTile(
            tileKey: 'ai_provider_type_dropdown',
            title: '接口模式',
            subtitle: _provider.displayName,
            icon: Icons.tune_outlined,
            onTap: _showProviderSelector,
          ),
          _buildFieldLabel('Base URL'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey<String>('ai_provider_base_url_field'),
              controller: _baseUrlController,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hintText: _provider.suggestedBaseUrl,
                icon: Icons.link_outlined,
                suffixIcon: IconButton(
                  key: const ValueKey<String>(
                      'ai_provider_base_url_reset_button'),
                  tooltip: '恢复默认',
                  onPressed: () {
                    _baseUrlController.text = _provider.suggestedBaseUrl;
                  },
                  icon: const Icon(Icons.restart_alt_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildFieldLabel('API Key'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey<String>('ai_provider_api_key_field'),
              controller: _apiKeyController,
              obscureText: !_showApiKey,
              decoration: _buildInputDecoration(
                hintText: '请输入可用的 API Key',
                icon: Icons.key_outlined,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey<String>(
                          'ai_provider_api_key_paste_button'),
                      onPressed: _pasteApiKey,
                      tooltip: '粘贴 API Key',
                      icon: const Icon(Icons.paste_outlined),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                          'ai_provider_api_key_visibility_button'),
                      onPressed: () {
                        setState(() {
                          _showApiKey = !_showApiKey;
                        });
                      },
                      tooltip: _showApiKey ? '隐藏 API Key' : '显示 API Key',
                      icon: Icon(
                        _showApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: _dividerColor,
          ),
          _buildSelectorTile(
            tileKey: 'ai_provider_model_dropdown',
            title: '模型选择',
            subtitle: modelSubtitle,
            icon: Icons.memory_outlined,
            enabled: _models.isNotEmpty,
            loading: _isLoadingModels && !_isInitializing,
            onTap: _models.isEmpty ? null : _showModelSelector,
          ),
          _buildActionTile(
            tileKey: 'ai_provider_reload_models_button',
            title: '获取模型列表',
            subtitle: '从当前接口读取可用模型',
            icon: Icons.sync_outlined,
            enabled: _hasCredentials && !_isLoadingModels,
            loading: _isLoadingModels,
            onTap: _hasCredentials && !_isLoadingModels
                ? () => _loadModels(
                      showFeedback: true,
                      saveSelection: true,
                    )
                : null,
          ),
          _buildActionTile(
            tileKey: 'ai_provider_test_connection_button',
            title: '测试连接',
            subtitle: '验证当前配置是否可正常使用',
            icon: Icons.network_check_outlined,
            enabled: _hasCredentials && !_isTestingConnection,
            loading: _isTestingConnection,
            onTap: _hasCredentials && !_isTestingConnection
                ? _testConnection
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: OptimizedText(
              statusText,
              key: const ValueKey<String>('ai_provider_status_text'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _tileSubtitleColor,
              ),
            ),
          ),
          if (selectedModelLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OptimizedText(
                '当前已选模型：$selectedModelLabel',
                key: const ValueKey<String>('ai_provider_selected_model_text'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _tileTitleColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
