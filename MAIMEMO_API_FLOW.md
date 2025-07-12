# 墨墨API使用流程详解

## API调用流程

墨墨背单词API的正确使用流程分为两个关键步骤：

### 第一步：获取单词的voc_id

在进行任何单词相关操作之前，必须先通过单词的拼写获取其在墨墨系统中的唯一标识符（voc_id）。

**API接口：**
```
GET /vocabulary?spelling={word}
```

**示例请求：**
```
GET https://open.maimemo.com/open/api/v1/vocabulary?spelling=apple
```

**响应示例：**
```json
{
  "success": true,
  "data": {
    "voc": {
      "id": "voc-12345678"
    }
  }
}
```

### 第二步：使用voc_id进行具体操作

获取到voc_id后，就可以进行各种操作：

#### 1. 查询单词释义
```
GET /interpretations?voc_id=voc-12345678&page_size=10
```

#### 2. 查询单词例句
```
GET /phrases?voc_id=voc-12345678&page_size=10
```

#### 3. 添加例句到单词
```
POST /phrases
Content-Type: application/json

{
  "phrase": {
    "voc_id": "voc-12345678",
    "phrase": "I like to eat apples.",
    "interpretation": "我喜欢吃苹果。",
    "tags": ["词典"],
    "origin": "WordFlow Plugin"
  }
}
```

## 完整流程示例

以查询单词"apple"的释义为例：

### 步骤1：获取voc_id
```dart
final vocId = await MaimemoApiService.getVocabularyId('apple');
// 返回: "voc-12345678"
```

### 步骤2：查询释义
```dart
final interpretations = await MaimemoApiService.getInterpretations(
  vocId: vocId,
  pageSize: 10,
);
```

## 重要注意事项

### 1. 单词必须存在于墨墨系统中
- 并非所有单词都在墨墨系统中有对应的voc_id
- 如果单词不存在，第一步会返回错误
- 应用应该优雅地处理这种情况

### 2. voc_id的格式
- voc_id通常以"voc-"开头，后跟数字或字母
- 每个单词在墨墨系统中有唯一的voc_id
- voc_id不能直接从单词拼写推算出来

### 3. 错误处理
```dart
try {
  // 第一步：获取voc_id
  final vocId = await MaimemoApiService.getVocabularyId(word);
  
  // 第二步：使用voc_id查询数据
  final interpretations = await MaimemoApiService.getInterpretations(
    vocId: vocId,
    pageSize: 5,
  );
  
  // 处理结果
  print('找到 ${interpretations.length} 条释义');
  
} catch (e) {
  if (e.toString().contains('未找到单词')) {
    print('单词 "$word" 不在墨墨系统中');
  } else {
    print('API调用失败: $e');
  }
}
```

## 在WordFlow中的实现

### 主页面集成
主页面在显示单词时会自动尝试：
1. 获取单词的voc_id
2. 如果成功，获取更详细的释义和例句
3. 如果失败，使用默认的词库数据

### 测试页面
测试页面清楚地展示了这个两步流程：
- "获取释义"按钮会先获取voc_id，再查询释义
- "获取例句"按钮会先获取voc_id，再查询例句
- 每个步骤都会在日志中显示详细信息

### 云词本功能
云词本功能不需要voc_id，可以直接使用：
- 创建云词本：直接使用单词文本
- 添加单词到云词本：直接使用单词文本

## 常见问题

### Q: 为什么不能直接使用单词作为voc_id？
A: 墨墨系统使用内部ID来管理单词，这样可以：
- 处理同一单词的不同形式（单复数、时态等）
- 支持多语言和特殊字符
- 保证数据一致性

### Q: 如果单词不存在怎么办？
A: 应用会优雅降级：
- 使用本地词库的基础释义
- 显示默认的例句
- 不影响用户的学习体验

### Q: voc_id会变化吗？
A: 一般不会，但建议：
- 不要缓存voc_id太长时间
- 每次操作前重新获取是最安全的
- 处理voc_id失效的情况

## 测试建议

1. **先测试常见单词**：如 apple, book, hello
2. **测试不存在的单词**：如 asdfgh, xyz123
3. **测试特殊字符**：如带重音符号的单词
4. **测试中文单词**：查看是否支持中文
5. **查看完整的错误信息**：了解各种失败情况 