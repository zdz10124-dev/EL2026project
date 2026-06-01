import 'dart:convert';
import 'dart:io';

import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/ai_analysis.dart';
import '../models/food_diary.dart';
import '../models/nutrition_analysis.dart';
import '../models/preference_analysis.dart';
import '../models/meal_record.dart';
import 'llm_service.dart';

/// 智能体服务 — 提供所有 AI 功能的高层接口
class AgentService {
  AgentService({required LlmService llmService})
      : _llm = llmService;

  final LlmService _llm;

  bool get isAvailable => _llm.isConfigured;

  // ===== 1. 图片识别分析 =====

  /// 分析食物图片，返回菜品名称、主配菜、辣度、食材、菜系等
  Future<ImageAnalysisResult> analyzeFoodImage(String imagePath) async {
    final b64 = await _imageToBase64(imagePath);

    final result = await _llm.callLlmWithImage(
      systemPrompt: _imageAnalysisPrompt,
      text: '请分析这张美食图片，输出识别结果。',
      imageBase64: b64,
    );

    return ImageAnalysisResult.fromJson(result);
  }

  // ===== 2. 视频分析 =====

  /// 分析美食视频，提取关键帧并识别菜品
  Future<ImageAnalysisResult> analyzeFoodVideo(String videoPath) async {
    final frames = await _extractVideoFrames(videoPath);
    if (frames.isEmpty) {
      throw LlmException('无法从视频中提取画面');
    }

    // 最多取 5 帧
    final framesToSend = frames.take(5).toList();

    final result = await _llm.callLlmWithImages(
      systemPrompt: _imageAnalysisPrompt,
      text:
          '这是从一段美食视频中提取的 ${framesToSend.length} 帧画面，请分析视频中的食物，输出识别结果。',
      imageBase64List: framesToSend,
    );

    return ImageAnalysisResult.fromJson(result);
  }

  // ===== 3. 生成美食日记 =====

  /// 基于一段时间内的用餐记录生成美食日记
  Future<FoodDiary> generateFoodDiary({
    required List<MealRecord> records,
    required String startDate,
    required String endDate,
  }) async {
    final recordsText = _formatRecordsForPrompt(records);

    final result = await _llm.callLlm(
      systemPrompt: _diaryPrompt,
      userPrompt: '''日期范围：$startDate 至 $endDate
共 ${records.length} 条记录：

$recordsText''',
      temperature: 0.8,
    );

    return FoodDiary.fromJson(result);
  }

  // ===== 4. 偏好分析 =====

  /// 分析用户饮食偏好
  Future<PreferenceAnalysis> analyzePreferences(
    List<MealRecord> records,
  ) async {
    final recordsText = _formatRecordsForPrompt(records);

    final result = await _llm.callLlm(
      systemPrompt: _preferencePrompt,
      userPrompt:
          '''以下是用户共 ${records.length} 条饮食记录，请分析其偏好特征：

$recordsText''',
    );

    return PreferenceAnalysis.fromJson(result);
  }

  // ===== 5. 营养分析 =====

  /// 分析用户的营养摄入情况
  Future<NutritionAnalysis> analyzeNutrition(List<MealRecord> records) async {
    final recordsText = _formatRecordsForPrompt(records);

    final result = await _llm.callLlm(
      systemPrompt: _nutritionPrompt,
      userPrompt:
          '''以下是用户共 ${records.length} 条饮食记录，请进行营养分析：

$recordsText''',
    );

    return NutritionAnalysis.fromJson(result);
  }

  // ===== 辅助方法 =====

  Future<String> _imageToBase64(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw LlmException('图片文件不存在: $imagePath');
    }
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<List<String>> _extractVideoFrames(String videoPath) async {
    final frames = <String>[];
    try {
      // 提取视频时长，取 5 个关键帧
      for (var i = 0; i < 5; i++) {
        final timeMs = i * 2000; // 每 2 秒取一帧
        final thumb = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          timeMs: timeMs,
          quality: 70,
        );
        if (thumb != null) {
          frames.add(base64Encode(thumb));
        }
      }
    } catch (_) {
      // 如果缩略图提取失败，返回已有的帧
    }
    return frames;
  }

  String _formatRecordsForPrompt(List<MealRecord> records) {
    return records.map((r) {
      final date =
          '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')} '
          '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
      final parts = [
        '[${r.id}] $date',
        '菜品：${r.dishName}',
        '地点：${r.location}',
        if (r.price != null) '价格：¥${r.price}',
        '评分：${r.ratingLabel}',
        if (r.mainDish != '未填写') '主菜：${r.mainDish}',
        if (r.sideDish != null) '配菜：${r.sideDish}',
        if (r.drink != null) '饮品：${r.drink}',
        if (r.snack != null) '小吃：${r.snack}',
        if (r.spiceLevel != null) '辣度：${r.spiceLevel}',
        if (r.ingredients != null) '食材：${r.ingredients}',
        if (r.cuisine != null) '菜系：${r.cuisine}',
        if (r.province != null) '省：${r.province}',
        if (r.city != null) '市：${r.city}',
      ];
      return parts.join(' | ');
    }).join('\n---\n');
  }
}

// ===== System Prompt 定义 =====

const _imageAnalysisPrompt = '''你是一个美食识别专家，擅长从图片中分析食物信息。请用中文回复。
分析图片中的食物，输出 JSON，严格按以下格式：
{
  "dish_name": "菜品名称（最可能的一道菜名）",
  "main_dish": "主菜名称",
  "side_dish": "配菜名称（没有则为 null）",
  "drink": "饮品（没有则为 null）",
  "snack": "小吃（没有则为 null）",
  "spice_level": "辣度等级（不辣/微辣/中辣/重辣/未知）",
  "ingredients": "主要食材（逗号分隔，如：牛肉,土豆,胡萝卜）",
  "cuisine": "菜系（如：川菜、粤菜、鲁菜、西餐、日料、韩餐、其他）"
}''';

const _diaryPrompt = '''你是一个温暖亲切的美食日记作者。根据用户的饮食记录，生成一篇好看的美食日记。
请用中文回复，风格轻松温暖，像朋友在分享日常。
输出 JSON，严格按以下格式：
{
  "date": "日期范围",
  "title": "吸引人的日记标题（如「周三的碳水快乐」「清淡的一天」）",
  "content": "日记正文（300-500 字，描述饮食内容、感受、回忆，段落分明，可适当加入 emoji）",
  "summary": "一句话总结",
  "mood": "整体心情/氛围（如：满足、元气、清淡、丰盛）"
}''';

const _preferencePrompt = '''你是一个饮食行为分析师。根据用户的饮食记录，分析其口味偏好和饮食习惯。
请用中文回复，输出 JSON，严格按以下格式：
{
  "favorite_cuisines": ["最爱的菜系1", "菜系2", "菜系3"],
  "favorite_ingredients": ["最喜欢的食材1", "食材2", "食材3"],
  "spice_preference": "口味偏好描述（如：清淡不辣、中等辣度、无辣不欢）",
  "favorite_dishes": ["常吃菜品1", "菜品2", "菜品3"],
  "favorite_locations": ["常去地点1", "地点2", "地点3"],
  "trends": ["趋势1（如：最近吃辣变多了）", "趋势2"],
  "summary": "整体评价（50 字以内）"
}''';

const _nutritionPrompt = '''你是一个营养健康顾问。根据用户的饮食记录，评估其营养状况。
请用中文回复，输出 JSON，严格按以下格式：
{
  "overall": "总体评价（如：较均衡、蔬菜偏少、油炸偏多、营养丰富等）",
  "vegetable_score": 蔬菜摄入评分（0-100 的整数，null 表示数据不足）,
  "protein_score": 蛋白质摄入评分（0-100 的整数，null 表示数据不足）,
  "drink_status": "饮品情况描述（如：以含糖饮料为主、饮水充足、常喝奶茶等）",
  "spicy_status": "重口味情况描述（如：清淡、适中、偏辣、非常辣）",
  "regularity": "规律程度描述（如：三餐规律、经常不吃早餐、吃饭时间不固定等）",
  "suggestions": ["建议1", "建议2", "建议3"]
}''';
