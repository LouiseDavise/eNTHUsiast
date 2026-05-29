import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/screens/account/widgets/header_menu_widget.dart';
import 'package:enthusiast/screens/account/widgets/transcript_card_widget.dart';
import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key});

  List<List<dynamic>> _buildTranscript(List<dynamic> records) {
    final List<dynamic> sorted = List.from(records);
    sorted.sort((a, b) => a['year'].toString().compareTo(b['year'].toString()));

    final List<List<dynamic>> res = [];
    int i = 0;
    while (i < sorted.length) {
      final curr = sorted[i]['year'].toString();
      List<dynamic> temp = [];
      while (i < sorted.length && sorted[i]['year'].toString() == curr) {
        temp.add(sorted[i]);
        i++;
      }
      res.add(temp);
    }

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final graduationData = context.watch<CcxpDataProvider>().graduationData;
    final records = graduationData!['allRecords'];
    print(records);
    final transcriptEntries = _buildTranscript(records);

    return Scaffold(
      appBar: HeaderMenuWidget(
        title: "Transcript",
        subTitle: "Academic Records",
      ),
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transcriptEntries.length - 1,
          itemBuilder: (context, index) {
            return TranscriptCardWidget(record: transcriptEntries[index]);
          },
          separatorBuilder: (context, index) {
            return const SizedBox(height: 20);
            // or: return Container(height: 20);
          },
        ),
      ),
    );
  }
}
