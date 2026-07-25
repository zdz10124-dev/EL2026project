enum AnalysisPeriod { sevenDays, thirtyDays }

extension AnalysisPeriodX on AnalysisPeriod {
  int get days => this == AnalysisPeriod.sevenDays ? 7 : 30;
  String get key => this == AnalysisPeriod.sevenDays ? '7d' : '30d';
  String get label => this == AnalysisPeriod.sevenDays ? '近 7 天' : '近 30 天';
}

enum RecommendationCategory { diet, exercise, rest }
enum RecommendationPriority { low, medium, high }

extension RecommendationCategoryX on RecommendationCategory {
  String get label => switch (this) {
        RecommendationCategory.diet => '饮食建议',
        RecommendationCategory.exercise => '运动建议',
        RecommendationCategory.rest => '休息建议',
      };
}

class HealthRecommendation {
  const HealthRecommendation({
    required this.category,
    required this.priority,
    required this.title,
    required this.action,
    required this.evidence,
    required this.validUntil,
  });

  final RecommendationCategory category;
  final RecommendationPriority priority;
  final String title;
  final String action;
  final List<String> evidence;
  final DateTime validUntil;

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'priority': priority.name,
        'title': title,
        'action': action,
        'evidence': evidence,
        'valid_until': validUntil.toIso8601String(),
      };
}

class IntegratedHealthAnalysis {
  const IntegratedHealthAnalysis({
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.dataFingerprint,
    required this.overview,
    required this.recommendations,
    required this.riskAlerts,
    required this.disclaimer,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final String dataFingerprint;
  final String overview;
  final List<HealthRecommendation> recommendations;
  final List<String> riskAlerts;
  final String disclaimer;

  Map<String, dynamic> toJson() => {
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'generated_at': generatedAt.toIso8601String(),
        'data_fingerprint': dataFingerprint,
        'overview': overview,
        'recommendations': recommendations.map((item) => item.toJson()).toList(),
        'risk_alerts': riskAlerts,
        'disclaimer': disclaimer,
      };

  factory IntegratedHealthAnalysis.fromJson(Map<String, dynamic> json) {
    RecommendationCategory category(String? value) =>
        RecommendationCategory.values.firstWhere(
          (item) => item.name == value,
          orElse: () => RecommendationCategory.rest,
        );
    RecommendationPriority priority(String? value) =>
        RecommendationPriority.values.firstWhere(
          (item) => item.name == value,
          orElse: () => RecommendationPriority.medium,
        );
    return IntegratedHealthAnalysis(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      generatedAt: DateTime.parse(json['generated_at'] as String),
      dataFingerprint: json['data_fingerprint'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      recommendations: (json['recommendations'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final item = raw.cast<String, dynamic>();
            return HealthRecommendation(
              category: category(item['category'] as String?),
              priority: priority(item['priority'] as String?),
              title: item['title'] as String? ?? '',
              action: item['action'] as String? ?? '',
              evidence: (item['evidence'] as List? ?? const [])
                  .map((value) => value.toString())
                  .toList(),
              validUntil: DateTime.tryParse(item['valid_until'] as String? ?? '') ??
                  DateTime.now().add(const Duration(days: 1)),
            );
          })
          .toList(),
      riskAlerts: (json['risk_alerts'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? healthDisclaimer,
    );
  }
}

const healthDisclaimer = '本建议仅供生活方式参考，不作为医疗诊断或治疗建议。如有身体不适，请及时就医。';

class HealthAnalysisCache {
  const HealthAnalysisCache({
    required this.periodKey,
    required this.dataFingerprint,
    required this.contentJson,
    required this.generatedAt,
  });
  final String periodKey;
  final String dataFingerprint;
  final String contentJson;
  final DateTime generatedAt;

  Map<String, Object?> toMap() => {
        'period_key': periodKey,
        'data_fingerprint': dataFingerprint,
        'content_json': contentJson,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory HealthAnalysisCache.fromMap(Map<String, Object?> map) =>
      HealthAnalysisCache(
        periodKey: map['period_key'] as String,
        dataFingerprint: map['data_fingerprint'] as String,
        contentJson: map['content_json'] as String,
        generatedAt: DateTime.parse(map['generated_at'] as String),
      );
}
