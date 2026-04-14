import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wfs_layer/wfs_layer.dart';

void main() {
  // ---------------------------------------------------------------------------
  // WfsLayerOptions
  // ---------------------------------------------------------------------------
  group('WfsLayerOptions', () {
    test('has correct defaults', () {
      const opts = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'ns:layer',
      );

      expect(opts.url, 'https://example.com/wfs');
      expect(opts.typeName, 'ns:layer');
      expect(opts.version, '1.1.0');
      expect(opts.srsName, 'EPSG:4326');
      expect(opts.maxFeatures, 1000);
      expect(opts.useClustering, isFalse);
      expect(opts.enableCaching, isTrue);
      expect(opts.retryAttempts, 3);
      expect(opts.polygonOpacity, 0.3);
      expect(opts.markerSize, 30.0);
    });

    test('copyWith overrides individual fields', () {
      const base = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'ns:layer',
      );

      final copy = base.copyWith(
        typeName: 'ns:other',
        useClustering: true,
        maxFeatures: 250,
        version: '2.0.0',
      );

      expect(copy.url, base.url); // unchanged
      expect(copy.typeName, 'ns:other');
      expect(copy.useClustering, isTrue);
      expect(copy.maxFeatures, 250);
      expect(copy.version, '2.0.0');
    });

    test('equality is field-based', () {
      const a = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'ns:layer',
      );
      const b = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'ns:layer',
      );
      const c = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'ns:other',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // WfsFeatureParser
  // ---------------------------------------------------------------------------
  group('WfsFeatureParser', () {
    late WfsFeatureParser parser;

    setUp(() {
      parser = const WfsFeatureParser(
        WfsLayerOptions(
          url: 'https://example.com/wfs',
          typeName: 'ns:layer',
        ),
      );
    });

    // Shared test data
    final sampleFeatures = <dynamic>[
      {
        'type': 'Feature',
        'id': 'f1',
        'geometry': {
          'type': 'Point',
          'coordinates': [75.3433, 19.8762],
        },
        'properties': {'name': 'Test Marker'},
      },
      {
        'type': 'Feature',
        'id': 'f2',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [75.3430, 19.8760],
            [75.3440, 19.8770],
            [75.3450, 19.8780],
          ],
        },
        'properties': {'name': 'Test Road'},
      },
      {
        'type': 'Feature',
        'id': 'f3',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [75.3430, 19.8760],
              [75.3440, 19.8760],
              [75.3440, 19.8770],
              [75.3430, 19.8770],
              [75.3430, 19.8760],
            ],
          ],
        },
        'properties': {'name': 'Test Parcel'},
      },
      {
        'type': 'Feature',
        'id': 'f4',
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [75.3430, 19.8760],
              [75.3440, 19.8770],
            ],
            [
              [75.3450, 19.8780],
              [75.3460, 19.8790],
            ],
          ],
        },
        'properties': <String, dynamic>{},
      },
      {
        'type': 'Feature',
        'id': 'f5',
        'geometry': {
          'type': 'MultiPolygon',
          'coordinates': [
            [
              [
                [75.31, 19.81],
                [75.32, 19.81],
                [75.32, 19.82],
                [75.31, 19.82],
                [75.31, 19.81],
              ],
            ],
            [
              [
                [75.41, 19.91],
                [75.42, 19.91],
                [75.42, 19.92],
                [75.41, 19.92],
                [75.41, 19.91],
              ],
            ],
          ],
        },
        'properties': <String, dynamic>{},
      },
    ];

    // --- Polylines ---

    test('parsePolylines returns correct count from LineString', () {
      final lines = parser.parsePolylines(sampleFeatures);
      // 1 LineString + 2 lines from MultiLineString = 3 total
      expect(lines, hasLength(3));
    });

    test('parsePolylines LineString has correct point count', () {
      final lines = parser.parsePolylines(sampleFeatures);
      final lineString = lines.first;
      expect(lineString.points, hasLength(3));
    });

    test('parsePolylines MultiLineString emits ALL lines (no data loss)', () {
      final multiLines = parser.parsePolylines(sampleFeatures)
          .skip(1) // skip the single LineString
          .toList();
      expect(multiLines, hasLength(2));
    });

    // --- Polygons ---

    test('parsePolygons returns correct count from MultiPolygon', () {
      final polys = parser.parsePolygons(sampleFeatures);
      // 1 Polygon + 2 polygons from MultiPolygon = 3 total
      expect(polys, hasLength(3));
    });

    test('parsePolygons MultiPolygon emits ALL polygons (no data loss)', () {
      final multiPolys = parser.parsePolygons(sampleFeatures)
          .skip(1)
          .toList();
      expect(multiPolys, hasLength(2));
    });

    // --- WfsFeature typed parsing ---

    test('parseFeatures returns typed WfsFeature objects', () {
      final features = parser.parseFeatures(sampleFeatures);
      expect(features, hasLength(sampleFeatures.length));
    });

    test('parseFeatures Point has correct LatLng', () {
      final features = parser.parseFeatures(sampleFeatures);
      final point = features.first;
      expect(point.geometry.type, WfsGeometryType.point);
      expect(point.geometry.points, hasLength(1));
      expect(point.geometry.points.first,
          const LatLng(19.8762, 75.3433));
    });

    test('parseFeatures LineString has correct geometry', () {
      final features = parser.parseFeatures(sampleFeatures);
      final line = features[1];
      expect(line.geometry.type, WfsGeometryType.lineString);
      expect(line.geometry.lines, hasLength(1));
      expect(line.geometry.lines.first, hasLength(3));
    });

    test('parseFeatures MultiLineString has all lines', () {
      final features = parser.parseFeatures(sampleFeatures);
      final ml = features[3];
      expect(ml.geometry.type, WfsGeometryType.multiLineString);
      expect(ml.geometry.lines, hasLength(2));
    });

    test('parseFeatures MultiPolygon has all polygons', () {
      final features = parser.parseFeatures(sampleFeatures);
      final mp = features[4];
      expect(mp.geometry.type, WfsGeometryType.multiPolygon);
      expect(mp.geometry.polygons, hasLength(2));
    });

    test('parseFeatures preserves properties', () {
      final features = parser.parseFeatures(sampleFeatures);
      expect(features.first.properties['name'], 'Test Marker');
      expect(features.first.id, 'f1');
    });

    test('parseFeatures skips malformed features gracefully', () {
      final bad = <Map<String, dynamic>>[
        <String, dynamic>{'type': 'Feature', 'geometry': null, 'properties': <String, dynamic>{}},
        <String, dynamic>{'type': 'Feature', 'geometry': <String, dynamic>{'type': 'Point', 'coordinates': <dynamic>[]}, 'properties': <String, dynamic>{}},
        ...sampleFeatures.cast<Map<String, dynamic>>(),
      ];
      // Should not throw — malformed ones are skipped.
      final features = parser.parseFeatures(bad);
      expect(features.length, lessThanOrEqualTo(bad.length));
    });
  });

  // ---------------------------------------------------------------------------
  // WfsCache
  // ---------------------------------------------------------------------------
  group('WfsCache', () {
    test('stores and retrieves data', () {
      final cache = WfsCache();
      final bounds = LatLngBounds(
        const LatLng(19.0, 75.0),
        const LatLng(20.0, 76.0),
      );
      final data = <String, dynamic>{'type': 'FeatureCollection', 'features': <Object?>[]};

      cache.put('key1', data, bounds);
      expect(cache.has('key1', const Duration(minutes: 5)), isTrue);
      expect(cache.get('key1', const Duration(minutes: 5)), data);
    });

    test('returns null for expired entries', () {
      final cache = WfsCache();
      final bounds = LatLngBounds(
        const LatLng(19.0, 75.0),
        const LatLng(20.0, 76.0),
      );
      cache.put('key1', <String, dynamic>{}, bounds);
      // Expired immediately with a zero duration.
      expect(cache.get('key1', Duration.zero), isNull);
    });

    test('clear empties the cache', () {
      final cache = WfsCache();
      final bounds = LatLngBounds(
        const LatLng(0, 0),
        const LatLng(1, 1),
      );
      cache.put('a', <String, dynamic>{}, bounds);
      cache.put('b', <String, dynamic>{}, bounds);
      cache.clear();
      expect(cache.length, 0);
    });

    test('evicts oldest entries when maxEntries exceeded', () {
      final cache = WfsCache(maxEntries: 3, retainCount: 2);
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
      cache.put('a', <String, dynamic>{}, bounds);
      cache.put('b', <String, dynamic>{}, bounds);
      cache.put('c', <String, dynamic>{}, bounds);
      cache.put('d', <String, dynamic>{}, bounds); // triggers eviction
      expect(cache.length, lessThanOrEqualTo(3));
    });
  });
}
