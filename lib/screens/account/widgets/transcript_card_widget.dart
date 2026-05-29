import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TranscriptCardWidget extends StatelessWidget {
  const TranscriptCardWidget({super.key, required this.record});
  final List<dynamic> record;

  @override
  Widget build(BuildContext context) {
    final year = record[0]['year'].substring(0, 3);
    final semester = (record[0]['year'][3] == '1') ? "Fall" : "Spring";
    var receivedCreds = 0;
    var totalCreds = 0;
    var value = 0.0;
    final Map<String, double> gpaMap = {
      'A+': 4.3,
      'A': 4.0,
      'A-': 3.7,
      'B+': 3.3,
      'B': 3.0,
      'B-': 2.7,
      'C+': 2.3,
      'C': 2.0,
      'C-': 1.7,
      '': 0.0, // Represents failed/empty grades with no specific letters
    };
    for (int i = 0; i < record.length; i++) {
      var cred = record[i]['credits'] as int;
      totalCreds += cred;
      if (record[i]['grade'] == "") continue;
      value += gpaMap[record[i]['grade']]! * cred;
      receivedCreds += cred;
    }
    final gpa = ((value / totalCreds) * 100).round() / 100;

    return Container(
      margin: EdgeInsets.only(bottom: 30),
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFFBF8FD), // Light lavender tint
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$year - $semester Semester',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF1A233A),
                      ),
                    ),
                    Text(
                      '$receivedCreds TOTAL CREDITS',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GPA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A56AC),
                      ),
                    ),
                    Text(
                      gpa.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8A56AC),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Course List Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                ...record.map((course) {
                  return _buildCourseRow(
                    course['title'].toString(),
                    course['credits'].toString(),
                    course['grade'].toString(),
                  );
                }),
              ],
            ),
          ),

          // Footer Section
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Colors.blueGrey.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  'OFFICIAL ACADEMIC RECORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.blueGrey.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseRow(String title, String credits, String grade) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  // maxLines: 10,
                  // overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A233A),
                  ),
                ),

                Text(
                  credits,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            height: 30,

            child: Container(
              // padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
              ),
              child: Center(
                child: Text(
                  (grade == "") ? "F" : grade,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A233A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
