import 'package:flutter/foundation.dart';

class CcxpDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _graduationData;
  dynamic _scheduleData;

  Map<String, dynamic>? get graduationData => _graduationData;
  dynamic get scheduleData => _scheduleData;

  bool get hasData => _graduationData != null || _scheduleData != null;

  void setGraduationData(Map<String, dynamic> data) {
    _graduationData = data;
    notifyListeners();
  }

  void setScheduleData(dynamic data) {
    _scheduleData = data;
    notifyListeners();
  }

  void setData({Map<String, dynamic>? graduationData, dynamic scheduleData}) {
    if (graduationData != null) {
      _graduationData = graduationData;
    }
    if (scheduleData != null) {
      _scheduleData = scheduleData;
    }
    notifyListeners();
  }

  void clear() {
    _graduationData = null;
    _scheduleData = null;
    notifyListeners();
  }
}
