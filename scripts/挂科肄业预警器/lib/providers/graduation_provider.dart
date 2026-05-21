import 'package:flutter/foundation.dart';
import '../models/graduation_model.dart';
import '../services/storage_service.dart';

/// 毕业进度状态管理
class GraduationProvider extends ChangeNotifier {
  final StorageService _storageService;

  GraduationOverview _overview = GraduationOverview();
  bool _isLoading = false;
  String? _errorMessage;

  GraduationProvider(this._storageService) {
    _loadGraduationData();
  }

  // Getters
  GraduationOverview get overview => _overview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 从本地存储加载毕业进度数据
  Future<void> _loadGraduationData() async {
    try {
      final data = _storageService.getJson('graduation_data');
      if (data != null) {
        _overview = GraduationOverview.fromJson(data);
      } else {
        // 首次使用，加载示例数据
        _overview = _getSampleOverview();
        await _saveGraduationData();
      }
    } catch (e) {
      debugPrint('GraduationProvider: 加载毕业数据失败: $e');
      _overview = _getSampleOverview();
    }
    notifyListeners();
  }

  /// 保存毕业进度数据到本地
  Future<void> _saveGraduationData() async {
    await _storageService.setJson('graduation_data', _overview.toJson());
  }

  /// 获取示例毕业进度数据
  GraduationOverview _getSampleOverview() {
    return GraduationOverview(
      totalRequiredCredits: 160,
      totalCompletedCredits: 45,
      currentSemesterAverage: 72.5,
      idealAverageScore: 80,
      requirements: [
        GraduationRequirement(
          id: '1',
          name: '总学分',
          category: '总学分',
          requiredAmount: 160,
          completedAmount: 45,
          unit: '学分',
        ),
        GraduationRequirement(
          id: '2',
          name: '体育课学分',
          category: '体育',
          requiredAmount: 4,
          completedAmount: 1,
          unit: '学分',
        ),
        GraduationRequirement(
          id: '3',
          name: '通识选修学分',
          category: '通识',
          requiredAmount: 12,
          completedAmount: 4,
          unit: '学分',
        ),
        GraduationRequirement(
          id: '4',
          name: '专业必修学分',
          category: '必修',
          requiredAmount: 80,
          completedAmount: 25,
          unit: '学分',
        ),
        GraduationRequirement(
          id: '5',
          name: '专业选修学分',
          category: '选修',
          requiredAmount: 30,
          completedAmount: 8,
          unit: '学分',
        ),
        GraduationRequirement(
          id: '6',
          name: '志愿时长',
          category: '志愿时长',
          requiredAmount: 40,
          completedAmount: 12,
          unit: '小时',
        ),
      ],
    );
  }

  /// 更新已完成学分
  Future<void> updateCompletedCredits(double credits) async {
    _overview = GraduationOverview(
      totalRequiredCredits: _overview.totalRequiredCredits,
      totalCompletedCredits: credits,
      currentSemesterAverage: _overview.currentSemesterAverage,
      idealAverageScore: _overview.idealAverageScore,
      requirements: _overview.requirements,
    );
    await _saveGraduationData();
    notifyListeners();
  }

  /// 更新当前学期平均分
  Future<void> updateSemesterAverage(double average) async {
    _overview = GraduationOverview(
      totalRequiredCredits: _overview.totalRequiredCredits,
      totalCompletedCredits: _overview.totalCompletedCredits,
      currentSemesterAverage: average,
      idealAverageScore: _overview.idealAverageScore,
      requirements: _overview.requirements,
    );
    await _saveGraduationData();
    notifyListeners();
  }

  /// 更新理想平均分
  Future<void> updateIdealAverage(double average) async {
    _overview = GraduationOverview(
      totalRequiredCredits: _overview.totalRequiredCredits,
      totalCompletedCredits: _overview.totalCompletedCredits,
      currentSemesterAverage: _overview.currentSemesterAverage,
      idealAverageScore: average,
      requirements: _overview.requirements,
    );
    await _saveGraduationData();
    notifyListeners();
  }

  /// 更新单项要求进度
  Future<void> updateRequirementProgress(String requirementId, double completedAmount) async {
    final updatedRequirements = _overview.requirements.map((req) {
      if (req.id == requirementId) {
        return req.copyWith(completedAmount: completedAmount);
      }
      return req;
    }).toList();

    _overview = GraduationOverview(
      totalRequiredCredits: _overview.totalRequiredCredits,
      totalCompletedCredits: _overview.totalCompletedCredits,
      currentSemesterAverage: _overview.currentSemesterAverage,
      idealAverageScore: _overview.idealAverageScore,
      requirements: updatedRequirements,
    );
    await _saveGraduationData();
    notifyListeners();
  }
}
