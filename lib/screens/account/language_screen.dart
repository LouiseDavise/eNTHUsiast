import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:enthusiast/screens/account/widgets/header_menu_widget.dart';
import 'package:enthusiast/widgets/button_selectable_widget.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = "English";

  final List<String> _languages = ['English', 'Traditional Chinese'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: HeaderMenuWidget(title: "Language", subTitle: "Change Language"),
      body: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        itemCount: _languages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final language = _languages[index];
          final bool isSelected = _selectedLanguage == language;

          return ButtonSelectableWidget(
            label: language,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedLanguage = language;
              });
            },
          );
        },
      ),
    );
  }
}
