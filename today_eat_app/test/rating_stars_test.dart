import 'package:flutter_test/flutter_test.dart';
import 'package:today_eat_app/widgets/rating_stars.dart';

void main() {
  test('星星左半区域仍支持半星', () {
    expect(RatingStars.resolveTapValue(22), 0.5);
    expect(RatingStars.resolveTapValue(66), 1.5);
    expect(RatingStars.resolveTapValue(110), 2.5);
  });

  test('星星之间空白区域按向下取整个星数处理', () {
    expect(RatingStars.resolveTapValue(42), 1);
    expect(RatingStars.resolveTapValue(86), 2);
    expect(RatingStars.resolveTapValue(174), 4);
  });

  test('第五颗星右侧区域可以稳定打满分', () {
    expect(RatingStars.resolveTapValue(190), 4.5);
    expect(RatingStars.resolveTapValue(200), 5);
    expect(RatingStars.resolveTapValue(214), 5);
    expect(RatingStars.resolveTapValue(219.9), 5);
  });
}
