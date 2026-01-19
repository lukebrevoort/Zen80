import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/services/sync_service.dart';

void main() {
  group('Color Mapping Tests', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('All 18 Tag.colorOptions map to valid Google Calendar ColorIDs', () {
      final tagColors = [
        '#EF4444',
        '#F97316',
        '#F59E0B',
        '#EAB308',
        '#84CC16',
        '#22C55E',
        '#10B981',
        '#14B8A6',
        '#06B6D4',
        '#0EA5E9',
        '#3B82F6',
        '#6366F1',
        '#8B5CF6',
        '#A855F7',
        '#D946EF',
        '#EC4899',
        '#F43F5E',
        '#78716C',
      ];

      for (final hex in tagColors) {
        final colorId = syncService.hexToGoogleColorId(hex);
        expect(colorId, isNotNull);
        expect(
          colorId,
          isIn(['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']),
        );
      }
    });

    test('Default tags map correctly', () {
      expect(
        syncService.hexToGoogleColorId('#10B981'),
        '10',
      ); // Personal → Basil
      expect(
        syncService.hexToGoogleColorId('#3B82F6'),
        '9',
      ); // School → Blueberry
      expect(syncService.hexToGoogleColorId('#8B5CF6'), '3'); // Work → Grape
    });

    test('Null hex returns default Blueberry (9)', () {
      expect(syncService.hexToGoogleColorId(null), '9');
    });

    test('Color categories map to appropriate Google Calendar colors', () {
      // Reds → Tomato (11)
      expect(syncService.hexToGoogleColorId('#EF4444'), '11');

      // Oranges → Tangerine (6)
      expect(syncService.hexToGoogleColorId('#F97316'), '6');

      // Yellows → Banana (5)
      expect(syncService.hexToGoogleColorId('#F59E0B'), '5');
      expect(syncService.hexToGoogleColorId('#EAB308'), '5');

      // Greens → Basil (10)
      expect(syncService.hexToGoogleColorId('#84CC16'), '10');
      expect(syncService.hexToGoogleColorId('#22C55E'), '10');

      // Teals/Cyans → Peacock (7)
      expect(syncService.hexToGoogleColorId('#14B8A6'), '7');
      expect(syncService.hexToGoogleColorId('#06B6D4'), '7');

      // Blues → Blueberry (9)
      expect(syncService.hexToGoogleColorId('#0EA5E9'), '9');

      // Purples → Grape (3)
      expect(syncService.hexToGoogleColorId('#6366F1'), '3');
      expect(syncService.hexToGoogleColorId('#A855F7'), '3');

      // Pinks → Flamingo (4)
      expect(syncService.hexToGoogleColorId('#D946EF'), '4');
      expect(syncService.hexToGoogleColorId('#EC4899'), '4');

      // Gray → Graphite (8)
      expect(syncService.hexToGoogleColorId('#78716C'), '8');
    });

    test('Legacy color mappings still work', () {
      expect(syncService.hexToGoogleColorId('#4285F4'), '9');
      expect(syncService.hexToGoogleColorId('#34A853'), '10');
      expect(syncService.hexToGoogleColorId('#FBBC04'), '5');
      expect(syncService.hexToGoogleColorId('#EA4335'), '11');
    });

    test('Case insensitivity', () {
      expect(syncService.hexToGoogleColorId('#ef4444'), '11');
      expect(syncService.hexToGoogleColorId('#EF4444'), '11');
    });

    test('With or without hash prefix', () {
      expect(syncService.hexToGoogleColorId('EF4444'), '11');
      expect(syncService.hexToGoogleColorId('#EF4444'), '11');
    });
  });
}
