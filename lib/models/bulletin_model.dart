import 'package:flutter/material.dart';

class BulletinModel {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String semanticLabel;
  final Color? gradientStart;
  final Color? gradientEnd;

  BulletinModel({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.semanticLabel,
    this.gradientStart,
    this.gradientEnd,
  });

  factory BulletinModel.fromMap(Map<String, dynamic> map) {
    return BulletinModel(
      id: map['id'] as String,
      category: map['category'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      imageUrl: map['imageUrl'] as String,
      semanticLabel: map['semanticLabel'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'semanticLabel': semanticLabel,
  };
}
