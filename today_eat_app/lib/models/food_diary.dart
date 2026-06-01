/// 美食日记
class FoodDiary {
  FoodDiary({
    required this.date,
    required this.title,
    required this.content,
    this.summary,
    this.mood,
  });

  final String date;
  final String title;
  final String content;
  final String? summary;
  final String? mood;

  factory FoodDiary.fromJson(Map<String, dynamic> json) {
    return FoodDiary(
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      summary: json['summary'] as String?,
      mood: json['mood'] as String?,
    );
  }
}
