# 墨墨API集成说明

## 概述

本项目已成功集成墨墨背单词的开放API，实现了以下功能：

1. **ListInterpretations API** - 获取单词释义列表
2. **ListPhrases API** - 获取单词例句列表

## 功能特性

### 1. API服务类 (`lib/utils/maimemo_api_service.dart`)
- 提供统一的API调用接口
- 支持Token管理和验证
- 包含完整的错误处理机制
- 支持分页查询

### 2. 设置页面集成
- 在设置页面可以配置API Token
- 支持Token验证功能
- 提供API测试功能
- 内置测试结果展示

### 3. 起始页面集成
- 在应用首次启动时可以配置Token
- 默认使用您提供的Token：`72191a782b95276a379495b2aa2c11bc41c8e06cc9f4e97a7f781894c7dc5b39`

### 4. 主页面集成
- 在背单词时会自动调用墨墨API获取更丰富的释义和例句
- 如果API调用失败，会自动降级到默认数据
- 支持异步数据加载

### 5. 专用测试页面
- 提供详细的API测试功能
- 支持单独测试各个API接口
- 包含完整的测试日志
- 可以测试特定单词的数据

## 使用方法

### 1. 配置API Token

#### 方法一：在起始页面配置
- 首次启动应用时，在第三页输入API Token
- 系统会自动预填您的Token

#### 方法二：在设置页面配置
1. 打开应用设置页面
2. 找到"墨墨背单词API"部分
3. 输入您的API Token
4. 点击"验证Token"按钮
5. 验证成功后点击"保存"

### 2. 测试API功能

#### 使用应用内测试
1. 在设置页面点击"API测试"
2. 进入专用测试页面
3. 可以测试以下功能：
   - 保存Token
   - 验证Token
   - 获取释义
   - 获取例句
   - 获取全部释义
   - 获取全部例句
   - 完整流程测试

#### 使用命令行测试
1. 在项目根目录运行：
   ```bash
   dart test_maimemo_demo.dart
   ```
2. 查看测试结果输出

### 3. 在学习中使用
- 正常使用背单词功能
- 系统会自动调用墨墨API获取更详细的释义和例句
- 如果API不可用，会自动使用默认数据

## API详细信息

### 基础配置
- **API端点**: `https://open.maimemo.com/open/api/v1`
- **认证方式**: Bearer Token
- **内容类型**: application/json

### 支持的接口

#### 1. 获取释义列表
```
GET /interpretations
```
参数：
- `voc_id` (可选): 单词ID
- `page_size` (可选): 每页数量
- `page_token` (可选): 分页标记

#### 2. 获取例句列表
```
GET /phrases
```
参数：
- `voc_id` (可选): 单词ID  
- `page_size` (可选): 每页数量
- `page_token` (可选): 分页标记

### 数据模型

#### 释义模型 (Interpretation)
```dart
class Interpretation {
  final String id;
  final String vocId;
  final String content;
  final String? partOfSpeech;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### 例句模型 (Phrase)
```dart
class Phrase {
  final String id;
  final String vocId;
  final String phrase;
  final String? interpretation;
  final List<String> tags;
  final String? origin;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

## 错误处理

系统包含完整的错误处理机制：

1. **网络错误**: 自动重试机制
2. **Token无效**: 提示用户重新配置
3. **API限制**: 显示相应错误信息
4. **数据解析错误**: 自动降级到默认数据

## 测试用例

### 基本测试
- [x] Token验证
- [x] 获取释义列表
- [x] 获取例句列表
- [x] 错误处理

### 集成测试
- [x] 设置页面集成
- [x] 起始页面集成
- [x] 主页面集成
- [x] 专用测试页面

### 性能测试
- [x] 异步数据加载
- [x] 降级机制
- [x] 缓存机制

## 注意事项

1. **Token安全**: Token会安全存储在本地，使用加密存储
2. **网络依赖**: 需要网络连接才能获取墨墨API数据
3. **降级机制**: 当API不可用时，会自动使用默认数据
4. **频率限制**: 请注意API的调用频率限制

## 故障排除

### 常见问题

1. **Token验证失败**
   - 检查Token是否正确
   - 确认网络连接正常
   - 检查API端点是否可访问

2. **API调用失败**
   - 检查网络连接
   - 确认Token有效期
   - 查看错误日志

3. **数据显示异常**
   - 检查数据模型映射
   - 确认API响应格式
   - 查看解析错误日志

### 调试建议

1. 使用专用测试页面进行调试
2. 查看详细的测试日志
3. 使用命令行测试脚本验证API连接
4. 检查Flutter应用的调试输出

## 更新日志

- **2024-01-XX**: 初始版本完成
  - 实现基本API集成
  - 添加设置页面支持
  - 完成主页面集成
  - 添加专用测试页面

## 技术支持

如果您在使用过程中遇到问题，请：

1. 首先使用测试页面进行诊断
2. 查看相关的错误日志
3. 检查网络连接和Token配置
4. 参考本文档的故障排除部分 