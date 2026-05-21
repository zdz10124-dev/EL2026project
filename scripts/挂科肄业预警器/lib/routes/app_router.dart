import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/graduation_progress_screen.dart';
import '../screens/settings_screen.dart';

/// 应用路由配置
class AppRouter {
  // 路由名称常量
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String courseDetail = '/course-detail';
  static const String graduationProgress = '/graduation-progress';
  static const String settings = '/settings';

  /// 获取初始路由
  static String get initialRoute {
    // 默认从闪屏页开始，由 SplashScreen 决定跳转到登录页还是主页
    return splash;
  }

  /// 生成路由
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // 使用 if-else 而非 switch，避免常量模式问题
    final routeName = settings.name;
    if (routeName == splash) {
      return MaterialPageRoute(builder: (_) => const SplashScreen());
    } else if (routeName == login) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    } else if (routeName == home) {
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    } else if (routeName == courseDetail) {
      final courseId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (_) => CourseDetailScreen(courseId: courseId ?? ''),
      );
    } else if (routeName == graduationProgress) {
      return MaterialPageRoute(
        builder: (_) => const GraduationProgressScreen(),
      );
    } else if (routeName == AppRouter.settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    } else {
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('页面不存在')),
        ),
      );
    }
  }
}
