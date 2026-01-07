import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

/// Provider for managing tags
class TagProvider extends ChangeNotifier {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  List<Tag> _tags = [];

  TagProvider(this._storageService) {
    _loadTags();
  }

  /// All available tags
  List<Tag> get tags => List.unmodifiable(_tags);

  /// Default tags only
  List<Tag> get defaultTags => _tags.where((t) => t.isDefault).toList();

  /// Custom (user-created) tags only
  List<Tag> get customTags => _tags.where((t) => !t.isDefault).toList();

  /// Load tags from storage
  Future<void> _loadTags() async {
    _tags = _storageService.getAllTags();

    // Initialize default tags if they don't exist
    if (!_storageService.hasDefaultTags()) {
      await _storageService.initializeDefaultTags();
      _tags = _storageService.getAllTags();
    }

    notifyListeners();
  }

  /// Refresh tags from storage
  Future<void> refresh() async {
    await _loadTags();
  }

  /// Get a tag by ID
  Tag? getTag(String id) {
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get multiple tags by IDs
  List<Tag> getTagsByIds(List<String> ids) {
    return ids.map((id) => getTag(id)).whereType<Tag>().toList();
  }

  /// Create a new tag
  Future<Tag> createTag({
    required String name,
    required String colorHex,
  }) async {
    final tag = Tag(
      id: _uuid.v4(),
      name: name.trim(),
      colorHex: colorHex,
      isDefault: false,
      createdAt: DateTime.now(),
    );

    await _storageService.addTag(tag);
    _tags.add(tag);
    notifyListeners();

    return tag;
  }

  /// Update an existing tag
  Future<void> updateTag(Tag tag) async {
    await _storageService.updateTag(tag);

    final index = _tags.indexWhere((t) => t.id == tag.id);
    if (index != -1) {
      _tags[index] = tag;
      notifyListeners();
    }
  }

  /// Delete a tag (only non-default tags can be deleted)
  Future<bool> deleteTag(String id) async {
    final tag = getTag(id);
    if (tag == null || tag.isDefault) {
      return false; // Can't delete default tags
    }

    await _storageService.deleteTag(id);
    _tags.removeWhere((t) => t.id == id);
    notifyListeners();

    return true;
  }

  /// Check if a tag name already exists
  bool tagNameExists(String name) {
    final normalizedName = name.trim().toLowerCase();
    return _tags.any((t) => t.name.toLowerCase() == normalizedName);
  }

  /// Get the next suggested color (one not currently in use)
  String getNextAvailableColor() {
    final usedColors = _tags.map((t) => t.colorHex.toUpperCase()).toSet();

    for (final color in Tag.colorOptions) {
      if (!usedColors.contains(color.toUpperCase())) {
        return color;
      }
    }

    // All colors used, return the first one
    return Tag.colorOptions.first;
  }

  /// Search tags by name
  List<Tag> searchTags(String query) {
    if (query.isEmpty) return _tags;

    final normalizedQuery = query.toLowerCase();
    return _tags
        .where((t) => t.name.toLowerCase().contains(normalizedQuery))
        .toList();
  }
}
