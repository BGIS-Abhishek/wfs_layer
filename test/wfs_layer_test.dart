import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfs_layer/wfs_layer.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('WfsLayerOptions', () {
    test('Initialization works correctly', () {
      final options = WfsLayerOptions(
        url: 'https://example.com/wfs',
        typeName: 'roads',
        useClustering: true,
        markerColor: Colors.green,
        version: '1.0.0',
      );

      expect(options.url, 'https://example.com/wfs');
      expect(options.typeName, 'roads');
      expect(options.useClustering, isTrue);
      expect(options.markerColor, Colors.green);
      expect(options.version, '1.0.0');
    });
  });

  group('WfsLayer parsing methods', () {
    final testState = _WfsLayerTestState();

    final sampleGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [75.3433, 19.8762]
          },
          "properties": {"name": "Test Marker"}
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [75.3430, 19.8760],
              [75.3440, 19.8770]
            ]
          },
          "properties": {}
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [75.3430, 19.8760],
                [75.3440, 19.8760],
                [75.3440, 19.8770],
                [75.3430, 19.8770],
                [75.3430, 19.8760]
              ]
            ]
          },
          "properties": {}
        }
      ]
    };

    List<dynamic> getFeatures(Map<String, dynamic> geoJson) =>
        geoJson['features'] as List<dynamic>;


    test('Parse Point', () {
      final points = testState.parsePoints(getFeatures(sampleGeoJson));
      expect(points, isNotEmpty);
      expect(points.first.point, const LatLng(19.8762, 75.3433));
    });

    test('Parse LineString', () {
      final lines = testState.parseLines(getFeatures(sampleGeoJson));
      expect(lines, isNotEmpty);
      expect(lines.first.points.length, 2);
    });

    test('Parse Polygon', () {
      final polygons = testState.parsePolygons(getFeatures(sampleGeoJson));
      expect(polygons, isNotEmpty);
      expect(polygons.first.points.length, greaterThan(3));
    });
  });

  // Future: Mock the WFS HTTP response using `http/testing.dart`
}

/// Minimal mock class to test parsing logic
class _WfsLayerTestState {
  List<Marker> parsePoints(List<dynamic> features) {
    return features
        .where((f) => f['geometry']?['type'] == 'Point')
        .map((f) {
      final coords = f['geometry']['coordinates'] as List<dynamic>;
      return Marker(
        point: LatLng(coords[1], coords[0]),
        width: 30,
        height: 30,
        child: const Icon(Icons.location_on),
      );
    })
        .toList();
  }

  List<Polyline> parseLines(List<dynamic> features) {
    return features
        .where((f) => f['geometry']?['type'] == 'LineString')
        .map((f) {
      final coords = (f['geometry']['coordinates'] as List)
          .map((c) => LatLng(c[1], c[0]))
          .toList();
      return Polyline(points: coords);
    })
        .toList();
  }

  List<Polygon> parsePolygons(List<dynamic> features) {
    return features
        .where((f) => f['geometry']?['type'] == 'Polygon')
        .map((f) {
      final coords = (f['geometry']['coordinates'] as List)
          .first
          .map((c) => LatLng(c[1], c[0]))
          .toList();
      return Polygon(points: coords);
    })
        .toList();
  }
}
