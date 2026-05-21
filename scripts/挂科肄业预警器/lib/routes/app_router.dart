import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case courseDetail:
        final courseId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => CourseDetailScreen(courseId: courseId ?? ''),
        );

      case graduationProgress:
        return MaterialPageRoute(
          builder: (_) => const GraduationProgressScreen(),
        );

      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('页面不存在')),
          ),
        );
    }
  }
}
