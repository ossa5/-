import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/quran_page.dart';
import 'pages/saved_page.dart';
import 'pages/settings_page.dart';
import 'services/storage_service.dart';
import 'services/quran_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => QuranAppState();
}

class QuranAppState extends State<QuranApp> {
  late ThemeMode themeMode;
  late double quranFontSize;

  @override
  void initState() {
    super.initState();
    themeMode = StorageService.getThemeMode();
    quranFontSize = StorageService.getQuranFontSize();
  }

  void toggleTheme() {
    final nextMode =
        themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => themeMode = nextMode);
    StorageService.setThemeMode(nextMode);
  }

  void setQuranFontSize(double size) {
    final safeSize = size.clamp(16.0, 44.0).toDouble();
    setState(() => quranFontSize = safeSize);
    StorageService.setQuranFontSize(safeSize);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رَاء | RAA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const SplashDownloadPage(),
    );
  }
}

// شاشة البداية وتجهيز المصحف
class SplashDownloadPage extends StatefulWidget {
  const SplashDownloadPage({super.key});

  @override
  State<SplashDownloadPage> createState() => _SplashDownloadPageState();
}

class _SplashDownloadPageState extends State<SplashDownloadPage> {
  bool _checking = true;
  bool _downloading = false;
  bool _error = false;
  int _current = 0;
  int _total = 114;
  String _surahName = '';

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
      _downloading = false;
      _error = false;
      _current = 0;
      _surahName = '';
    });

    try {
      if (StorageService.isFullQuranReady()) {
        if (mounted) _goToApp();
        return;
      }

      if (!mounted) return;
      setState(() {
        _checking = false;
        _downloading = true;
      });

      await _downloadQuran();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _downloading = false;
        _error = true;
      });
    }
  }

  Future<void> _downloadQuran() async {
    try {
      final fullQuran = await QuranApi.fetchFullQuran(
        onProgress: (current, total, surahName) {
          if (!mounted) return;
          setState(() {
            _current = current;
            _total = total > 0 ? total : 114;
            _surahName = surahName
                .replaceAll('سُورَةُ ', '')
                .replaceAll('سورة ', '')
                .trim();
          });
        },
      );

      // حفظ الفهرس اختياري؛ فشل الفهرس لا ينبغي أن يمنع حفظ المصحف.
      try {
        final surahs = await QuranApi.fetchSurahs();
        await StorageService.saveSurahsCache(surahs);
      } catch (_) {
        // سيُعاد جلب الفهرس عند الحاجة إذا لم يكن محفوظًا.
      }

      await StorageService.saveFullQuran(fullQuran);

      if (!mounted) return;
      _goToApp();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = true;
      });
    }
  }

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShellPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _total > 0
        ? (_current / _total).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withOpacity(.10),
              scheme.surface,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withOpacity(.72),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(.22),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 58,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'رَاء',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'رفيقك اليومي مع كتاب الله',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 42),
                    if (_checking) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('جارٍ التحقق من بيانات المصحف...'),
                    ] else if (_downloading) ...[
                      Text(
                        'جارٍ تجهيز المصحف',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _surahName.isNotEmpty
                            ? 'سورة $_surahName'
                            : 'يرجى إبقاء الاتصال بالإنترنت حتى يكتمل التحميل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 9,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_current من $_total سورة  •  ${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withOpacity(.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 21,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'يُحفظ المصحف على جهازك بعد اكتمال التحميل، لتتمكن من القراءة دون إنترنت.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_error) ...[
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 58,
                        color: scheme.error,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'تعذّر تجهيز المصحف',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تحقّق من اتصال الإنترنت ثم حاول مرة أخرى. إذا استمرت المشكلة، فقد يكون مصدر البيانات غير متاح.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _checkAndDownload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// الواجهة الرئيسية والتنقل بين أقسام التطبيق
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;
  late ThemeMode _themeMode;
  late double _quranFontSize;

  @override
  void initState() {
    super.initState();
    _themeMode = StorageService.getThemeMode();
    _quranFontSize = StorageService.getQuranFontSize();
  }

  QuranAppState? get _appState =>
      context.findAncestorStateOfType<QuranAppState>();

  void _toggleTheme() {
    final appState = _appState;
    if (appState == null) return;
    appState.toggleTheme();
    setState(() => _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  void _setQuranFontSize(double size) {
    final safeSize = size.clamp(16.0, 44.0).toDouble();
    _appState?.setQuranFontSize(safeSize);
    setState(() => _quranFontSize = safeSize);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(onGoToQuran: () => setState(() => _index = 1)),
            QuranPage(quranFontSize: _quranFontSize),
            const SavedPage(),
            SettingsPage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeChanged: _toggleTheme,
              quranFontSize: _quranFontSize,
              onQuranFontSizeChanged: _setQuranFontSize,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'المصحف',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'المحفوظات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}