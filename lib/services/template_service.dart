import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 话术模板存储服务
class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  static const String _templatesKey = 'reminderTemplates';
  static const String _fuzzyAmountKey = 'useFuzzyAmount';
  static const int _maxTemplates = 5;

  /// 默认模板内容
  static const List<String> defaultTemplates = [
    '嘿，{对方}，上次{事件}你给了{金额}，这次我家{我的事件}记得来哦～哈哈',
    '老朋友，上次{事件}{金额}，这次轮到我啦，期待你的心意！',
    '{对方}，上次{事件}{金额}，最近有空聚聚？顺便...',
  ];

  /// 初始化默认模板（首次运行）
  Future<void> initDefaultTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_templatesKey)) {
      await prefs.setString(_templatesKey, jsonEncode(defaultTemplates));
    }
  }

  /// 获取所有模板
  Future<List<String>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_templatesKey);
    if (json == null) {
      // 如果没有模板，初始化默认模板
      await initDefaultTemplates();
      return List<String>.from(defaultTemplates);
    }
    final list = jsonDecode(json) as List<dynamic>;
    return list.cast<String>();
  }

  /// 保存模板列表（限制5个）
  Future<void> saveTemplates(List<String> templates) async {
    final prefs = await SharedPreferences.getInstance();
    // 限制最多5个模板
    final limited = templates.take(_maxTemplates).toList();
    await prefs.setString(_templatesKey, jsonEncode(limited));
  }

  /// 添加新模板
  Future<bool> addTemplate(String template) async {
    final templates = await getTemplates();
    if (templates.length >= _maxTemplates) {
      return false; // 已达到最大数量
    }
    templates.add(template);
    await saveTemplates(templates);
    return true;
  }

  /// 更新模板
  Future<void> updateTemplate(int index, String template) async {
    final templates = await getTemplates();
    if (index >= 0 && index < templates.length) {
      templates[index] = template;
      await saveTemplates(templates);
    }
  }

  /// 删除模板
  Future<void> deleteTemplate(int index) async {
    final templates = await getTemplates();
    if (index >= 0 && index < templates.length) {
      templates.removeAt(index);
      await saveTemplates(templates);
    }
  }

  /// 重置为默认模板
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templatesKey, jsonEncode(defaultTemplates));
  }

  /// 获取模糊金额设置
  Future<bool> getUseFuzzyAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fuzzyAmountKey) ?? false;
  }

  /// 设置模糊金额开关
  Future<void> setUseFuzzyAmount(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fuzzyAmountKey, value);
  }
}
