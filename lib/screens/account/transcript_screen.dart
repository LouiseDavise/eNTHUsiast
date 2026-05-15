import 'package:enthusiast/screens/account/widgets/header_menu_widget.dart';
import 'package:enthusiast/screens/account/widgets/transcript_card_widget.dart';
import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderMenuWidget(
        title: "Transcript",
        subTitle: "Academic Records",
      ),
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: TranscriptCardWidget(),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: TranscriptCardWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
