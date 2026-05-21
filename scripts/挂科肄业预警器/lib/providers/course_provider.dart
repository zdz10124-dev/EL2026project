import 'package:flutter/foundation.dart';
import '../models/course_model.dart';
import '../services/storage_service.dart';

/// 课程状态管理
class CourseProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<CourseModel> _courses = [];
  final bool _isLoading = false;
  String? _errorMessage;

  CourseProvider(this._storageService) {
    _loadCourses();
  }

  // Getters
  List<CourseModel> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 获取有预警的课程
  List<CourseModel> get warningCourses =>
      _courses.where((c) => c.isSkipWarning || c.isFailWarning).toList();

  /// 获取重要课程
  List<CourseModel> get importantCourses =>
      _courses.where((c) => c.isImportant).toList();

  /// 从本地存储加载课程列表
  Future<void> _loadCourses() async {
    try {
      final coursesData = _storageService.getJsonList('courses_data');
      if (coursesData != null) {
        _courses = coursesData.map((e) => CourseModel.fromJson(e)).toList();
      } else {
        // 首次使用，加载示例数据
        _courses = _getSampleCourses();
        await _saveCourses();
      }
    } catch (e) {
      debugPrint('CourseProvider: 加载课程失败: $e');
      _courses = _getSampleCourses();
    }
    notifyListeners();
  }

  /// 保存课程列表到本地
  Future<void> _saveCourses() async {
    final data = _courses.map((c) => c.toJson()).toList();
    await _storageService.setJsonList('courses_data', data);
  }

  /// 获取示例课程数据
  List<CourseModel> _getSampleCourses() {
    return [
      CourseModel(
        id: '1',
        name: '高等数学',
        teacher: '张教授',
        classroom: '教学楼A101',
        weekday: '周一',
        startTime: '08:00',
        endTime: '09:40',
        credit: 5.0,
        category: '必修',
        isImportant: true,
        skipCount: 0,
        scoreTrackingEnabled: true,
        regularScore: 75,
        midtermScore: 68,
        finalScore: null,
        regularWeight: 0.3,
        midtermWeight: 0.3,
        finalWeight: 0.4,
      ),
      CourseModel(
        id: '2',
        name: '大学英语',
        teacher: '李教授',
        classroom: '教学楼B203',
        weekday: '周三',
        startTime: '10:00',
        endTime: '11:40',
        credit: 4.0,
        category: '必修',
        isImportant: false,
        skipCount: 1,
        scoreTrackingEnabled: true,
        regularScore: 82,
        midtermScore: null,
        finalScore: null,
        regularWeight: 0.4,
        midtermWeight: 0.3,
        finalWeight: 0.3,
      ),
      CourseModel(
        id: '3',
        name: '体育（篮球）',
        teacher: '王老师',
        classroom: '体育馆',
        weekday: '周四',
        startTime: '14:00',
        endTime: '15:40',
        credit: 1.0,
        category: '体育',
        isImportant: false,
        skipCount: 0,
      ),
      CourseModel(
        id: '4',
        name: '计算机导论',
        teacher: '赵教授',
        classroom: '实验楼C301',
        weekday: '周二',
        startTime: '08:00',
        endTime: '09:40',
        credit: 3.0,
        category: '必修',
        isImportant: true,
        skipCount: 2,
        scoreTrackingEnabled: true,
        regularScore: 55,
        midtermScore: 60,
        finalScore: null,
        regularWeight: 0.2,
        midtermWeight: 0.3,
        finalWeight: 0.5,
      ),
      CourseModel(
        id: '5',
        name: '中国近代史纲要',
        teacher: '陈教授',
        classroom: '教学楼A305',
        weekday: '周五',
        startTime: '10:00',
        endTime: '11:40',
        credit: 2.0,
        category: '通识',
        isImportant: false,
        skipCount: 0,
      ),
    ];
  }

  /// 记录翘课
  Future<void> recordSkip(String courseId) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    _courses[index] = course.copyWith(skipCount: course.skipCount + 1);
    await _saveCourses();
    notifyListeners();
  }

  /// 切换课程重要标记
  Future<void> toggleImportant(String courseId) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    _courses[index] = course.copyWith(isImportant: !course.isImportant);
    await _saveCourses();
    notifyListeners();
  }

  /// 更新课程分数
  Future<void> updateScores({
    required String courseId,
    double? regularScore,
    double? midtermScore,
    double? finalScore,
  }) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    _courses[index] = course.copyWith(
      regularScore: regularScore ?? course.regularScore,
      midtermScore: midtermScore ?? course.midtermScore,
      finalScore: finalScore ?? course.finalScore,
      scoreTrackingEnabled: true,
    );
    await _saveCourses();
    notifyListeners();
  }

  /// 更新分数权重配置
  Future<void> updateScoreWeights({
    required String courseId,
    double? regularWeight,
    double? midtermWeight,
    double? finalWeight,
    double? skipDeduction,
  }) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    _courses[index] = course.copyWith(
      regularWeight: regularWeight ?? course.regularWeight,
      midtermWeight: midtermWeight ?? course.midtermWeight,
      finalWeight: finalWeight ?? course.finalWeight,
      skipDeduction: skipDeduction ?? course.skipDeduction,
    );
    await _saveCourses();
    notifyListeners();
  }

  /// 切换分数追踪
  Future<void> toggleScoreTracking(String courseId) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    _courses[index] = course.copyWith(
      scoreTrackingEnabled: !course.scoreTrackingEnabled,
    );
    await _saveCourses();
    notifyListeners();
  }

  /// 添加课程
  Future<void> addCourse(CourseModel course) async {
    _courses.add(course);
    await _saveCourses();
    notifyListeners();
  }

  /// 删除课程
  Future<void> removeCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
    await _saveCourses();
    notifyListeners();
  }
}
