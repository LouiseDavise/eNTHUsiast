import 'package:flutter/widgets.dart';

enum AppLanguage { en, zh }

class LanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;
  bool get isChinese => _language == AppLanguage.zh;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }
}

class LanguageProviderScope extends StatefulWidget {
  const LanguageProviderScope({super.key, required this.child});

  final Widget child;

  @override
  State<LanguageProviderScope> createState() => _LanguageProviderScopeState();
}

class _LanguageProviderScopeState extends State<LanguageProviderScope> {
  late final LanguageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LanguageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(controller: _controller, child: widget.child);
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();

    assert(
      scope != null,
      'LanguageScope not found. Wrap your app with LanguageProviderScope.',
    );

    return scope!.notifier!;
  }

  static LanguageController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<LanguageScope>();

    assert(
      element != null,
      'LanguageScope not found. Wrap your app with LanguageProviderScope.',
    );

    final scope = element!.widget as LanguageScope;
    return scope.notifier!;
  }

  static bool isChinese(BuildContext context) {
    return watch(context).isChinese;
  }

  static String text(
    BuildContext context, {
    required String en,
    required String zh,
  }) {
    return isChinese(context) ? zh : en;
  }
}
