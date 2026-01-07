import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'tag.g.dart';

/// A tag for categorizing Signal tasks (e.g., School, Work, Personal)
/// Supports multiple tags per task with customizable colors
@HiveType(typeId: 10)
class Tag extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String colorHex; // e.g., "#FF5733"

  @HiveField(3)
  bool isDefault; // Personal, School, Work - can't be deleted

  @HiveField(4)
  DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    required this.colorHex,
    this.isDefault = false,
    required this.createdAt,
  });

  /// Get the color as a Flutter Color object
  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Set color from a Flutter Color object
  set color(Color color) {
    // Convert ARGB color to hex string (ignoring alpha)
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    colorHex = '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// Create a copy with optional overrides
  Tag copyWith({
    String? id,
    String? name,
    String? colorHex,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Default tags that come with the app
  static List<Tag> get defaultTags => [
    Tag(
      id: 'default-personal',
      name: 'Personal',
      colorHex: '#10B981', // Green
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    Tag(
      id: 'default-school',
      name: 'School',
      colorHex: '#3B82F6', // Blue
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    Tag(
      id: 'default-work',
      name: 'Work',
      colorHex: '#8B5CF6', // Purple
      isDefault: true,
      createdAt: DateTime.now(),
    ),
  ];

  /// Predefined color options for new tags (Notion-style palette)
  static List<String> get colorOptions => [
    '#EF4444', // Red
    '#F97316', // Orange
    '#F59E0B', // Amber
    '#EAB308', // Yellow
    '#84CC16', // Lime
    '#22C55E', // Green
    '#10B981', // Emerald
    '#14B8A6', // Teal
    '#06B6D4', // Cyan
    '#0EA5E9', // Sky
    '#3B82F6', // Blue
    '#6366F1', // Indigo
    '#8B5CF6', // Violet
    '#A855F7', // Purple
    '#D946EF', // Fuchsia
    '#EC4899', // Pink
    '#F43F5E', // Rose
    '#78716C', // Stone
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
