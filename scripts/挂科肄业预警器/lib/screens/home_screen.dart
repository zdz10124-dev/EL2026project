import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../providers/graduation_provider.dart';
import '../routes/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_card.dart';
import '../widgets/course_card.dart';
import '../widgets/warning_banner.dart';

/// 主页 - 包含底部导航栏
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _DashboardPage(),
    _CoursesPage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: '总览',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_rounded),
            label: '课程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 总览页面
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学业总览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRouter.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎语
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '你好，${auth.user.name}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),

            // 预警横幅
            Consumer<CourseProvider>(
              builder: (context, courseProvider, _) {
                final warnings = courseProvider.warningCourses;
                if (warnings.isNotEmpty) {
                  return WarningBanner(
                    warningCount: warnings.length,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRouter.courseDetail,
                      arguments: warnings.first.id,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),

            // 毕业进度卡片
            Consumer<GraduationProvider>(
              builder: (context, graduation, _) {
                return ProgressCard(
                  title: '毕业进度',
                  progress: graduation.overview.totalProgress,
                  progressText: '${graduation.overview.totalCompletedCredits.toStringAsFixed(0)} / ${graduation.overview.totalRequiredCredits.toStringAsFixed(0)} 学分',
                  subtitle: '当前平均分: ${graduation.overview.currentSemesterAverage.toStringAsFixed(1)}',
                  onTap: () => Navigator.pushNamed(context, AppRouter.graduationProgress),
                );
              },
            ),
            const SizedBox(height: 16),

            // 快捷功能
            const Text(
              '快捷功能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.warning_amber_rounded,
                    label: '预警课程',
                    color: AppTheme.dangerColor,
                    onTap: () {
                      final warnings = context.read<CourseProvider>().warningCourses;
                      if (warnings.isNotEmpty) {
                        Navigator.pushNamed(
                          context,
                          AppRouter.courseDetail,
                          arguments: warnings.first.id,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('暂无预警课程')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.flag_rounded,
                    label: '重要课程',
                    color: AppTheme.accentColor,
                    onTap: () {
                      final important = context.read<CourseProvider>().importantCourses;
                      if (important.isNotEmpty) {
                        Navigator.pushNamed(
                          context,
                          AppRouter.courseDetail,
                          arguments: important.first.id,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('暂无标记的重要课程')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.auto_graph_rounded,
                    label: '毕业进度',
                    color: AppTheme.successColor,
                    onTap: () => Navigator.pushNamed(context, AppRouter.graduationProgress),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 课程列表标题
            const Text(
              '我的课程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 课程列表
            Consumer<CourseProvider>(
              builder: (context, courseProvider, _) {
                final courses = courseProvider.courses;
                if (courses.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无课程数据'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    return CourseCard(
                      course: courses[index],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.courseDetail,
                        arguments: courses[index].id,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷操作卡片
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 课程列表页面
class _CoursesPage extends StatelessWidget {
  const _CoursesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程列表'),
      ),
      body: Consumer<CourseProvider>(
        builder: (context, courseProvider, _) {
          final courses = courseProvider.courses;
          if (courses.isEmpty) {
            return const Center(child: Text('暂无课程'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              return CourseCard(
                course: courses[index],
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.courseDetail,
                  arguments: courses[index].id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 个人中心页面
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 用户信息卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          auth.user.name.isNotEmpty
                              ? auth.user.name[0]
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '学号: ${auth.user.studentId}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${auth.user.department ?? "未知学院"} · ${auth.user.grade ?? "未知年级"}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 设置选项
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: '通知设置',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.security_outlined,
                title: '隐私与安全',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                title: '关于应用',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // 退出登录按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认退出'),
                        content: const Text('确定要退出登录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed(AppRouter.login);
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerColor,
                    side: const BorderSide(color: AppTheme.dangerColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('退出登录'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 设置项组件
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
