/// Pure-Dart GeoJSON feature parser for WFS responses.
///
/// This class is decoupled from Flutter widgets so it can be:
/// - Unit tested without a Flutter test environment
/// - Subclassed to customise parsing behaviour
/// - Used in isolates for background parsing
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models/wfs_feature.dart';
import 'wfs_layer_options.dart';

/// Parses raw GeoJSON feature collections into flutter_map layer objects.
///
/// Override individual methods to customise how specific geometry types
/// are parsed or rendered without needing to fork the whole widget:
///
/// ```dart
/// class MyParser extends WfsFeatureParser {
///   MyParser(super.options);
///
///   @override
///   Marker? buildMarker(LatLng point, Map<String, dynamic> properties, BuildContext context) {
///     // Your custom marker logic here
///   }
/// }
/// ```
class WfsFeatureParser {
  /// The layer options controlling styling and behaviour.
  final WfsLayerOptions options;

  /// Creates a [WfsFeatureParser] with the given [options].
  const WfsFeatureParser(this.options);

  // ---------------------------------------------------------------------------
  // Public parse methods
  // ---------------------------------------------------------------------------

  /// Parses all features from a GeoJSON [features] list into [Marker]s.
  ///
  /// Features with geometry types other than `Point` are ignored.
  /// Features that fail to parse are skipped with a debug warning.
  List<Marker> parseMarkers(
    List<dynamic> features,
    BuildContext context,
  ) {
    final result = <Marker>[];
    for (final f in features) {
      final type = _geometryType(f);
      if (type == 'Point') {
        final marker = _parsePoint(f, context);
        if (marker != null) result.add(marker);
      }
    }
    return result;
  }

  /// Parses all features from a GeoJSON [features] list into [Polyline]s.
  ///
  /// Both `LineString` and `MultiLineString` are supported.
  /// A `MultiLineString` produces one [Polyline] per line segment.
  List<Polyline> parsePolylines(List<dynamic> features) {
    final result = <Polyline>[];
    for (final f in features) {
      final type = _geometryType(f);
      if (type == 'LineString' || type == 'MultiLineString') {
        result.addAll(_parsePolylines(f));
      }
    }
    return result;
  }

  /// Parses all features from a GeoJSON [features] list into [Polygon]s.
  ///
  /// Both `Polygon` and `MultiPolygon` are supported.
  /// A `MultiPolygon` produces one [Polygon] per polygon member.
  List<Polygon> parsePolygons(List<dynamic> features) {
    final result = <Polygon>[];
    for (final f in features) {
      final type = _geometryType(f);
      if (type == 'Polygon' || type == 'MultiPolygon') {
        result.addAll(_parsePolygons(f));
      }
    }
    return result;
  }

  /// Parses a full GeoJSON feature collection into typed [WfsFeature] objects.
  ///
  /// This is useful when you need access to the raw geometry coordinates
  /// and properties without going through flutter_map primitives.
  List<WfsFeature> parseFeatures(List<dynamic> rawFeatures) {
    final result = <WfsFeature>[];
    for (final f in rawFeatures) {
      try {
        final feature = _parseWfsFeature(f);
        if (feature != null) result.add(feature);
      } catch (e) {
        debugPrint('WfsFeatureParser: Failed to parse feature: $e');
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Overridable builder methods
  // ---------------------------------------------------------------------------

  /// Builds a [Marker] for a parsed point feature.
  ///
  /// Override to change the default marker widget without changing
  /// [WfsLayerOptions.customMarkerBuilder].
  Marker? buildMarker(
    LatLng point,
    Map<String, dynamic> properties,
    BuildContext context,
  ) {
    return Marker(
      width: options.markerSize,
      height: options.markerSize,
      point: point,
      child: GestureDetector(
        onTap: () => options.onMarkerTap?.call(properties, point),
        child: options.customMarkerBuilder?.call(context, point, properties) ??
            Icon(
              Icons.location_on,
              color: options.markerColor,
              size: options.markerSize,
            ),
      ),
    );
  }

  /// Builds a [Polyline] for a parsed line feature.
  ///
  /// Override to customise stroke, patterns, gradients etc.
  Polyline buildPolyline(
    List<LatLng> points,
    Map<String, dynamic> properties,
  ) {
    return Polyline(
      points: points,
      color: options.polylineColor,
      strokeWidth: options.polylineWidth,
    );
  }

  /// Builds a [Polygon] for a parsed polygon feature.
  ///
  /// Override to customise fill, border, hit-testing etc.
  Polygon buildPolygon(
    List<LatLng> points,
    Map<String, dynamic> properties,
  ) {
    return Polygon(
      points: points,
      color: options.polygonFillColor
          .withValues(alpha: options.polygonOpacity),
      borderColor: options.polygonBorderColor,
      borderStrokeWidth: options.polygonBorderWidth,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String? _geometryType(Object? feature) {
    try {
      final f = feature as Map<String, dynamic>;
      final geom = f['geometry'] as Map<String, dynamic>?;
      return geom?['type'] as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _properties(Object? feature) {
    try {
      final f = feature as Map<String, dynamic>;
      return (f['properties'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  LatLng _coordToLatLng(Object? coord) {
    final c = coord as List<dynamic>;
    return LatLng(
      (c[1] as num).toDouble(),
      (c[0] as num).toDouble(),
    );
  }

  List<LatLng> _coordListToLatLngs(List<dynamic> coords) =>
      coords.map(_coordToLatLng).toList();

  // --------------- Points ---------------------------------------------------

  Marker? _parsePoint(Object? feature, BuildContext context) {
    try {
      final f = feature as Map<String, dynamic>;
      final geom = f['geometry'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>;
      final point = _coordToLatLng(coords);
      final properties = _properties(f);
      return buildMarker(point, properties, context);
    } catch (e) {
      debugPrint('WfsFeatureParser: Error parsing Point: $e');
      return null;
    }
  }

  // --------------- Lines ----------------------------------------------------

  List<Polyline> _parsePolylines(Object? feature) {
    try {
      final f = feature as Map<String, dynamic>;
      final properties = _properties(f);
      final geom = f['geometry'] as Map<String, dynamic>;
      final geomType = geom['type'] as String;

      if (geomType == 'LineString') {
        final coords = geom['coordinates'] as List<dynamic>;
        final points = _coordListToLatLngs(coords);
        if (points.length < 2) return [];
        return [buildPolyline(points, properties)];
      } else {
        // MultiLineString — emit one Polyline per line (no silent data loss)
        final lines = geom['coordinates'] as List<dynamic>;
        return lines
            .map((line) => _coordListToLatLngs(line as List<dynamic>))
            .where((pts) => pts.length >= 2)
            .map((pts) => buildPolyline(pts, properties))
            .toList();
      }
    } catch (e) {
      debugPrint('WfsFeatureParser: Error parsing LineString: $e');
      return [];
    }
  }

  // --------------- Polygons -------------------------------------------------

  List<Polygon> _parsePolygons(Object? feature) {
    try {
      final f = feature as Map<String, dynamic>;
      final properties = _properties(f);
      final geom = f['geometry'] as Map<String, dynamic>;
      final geomType = geom['type'] as String;

      if (geomType == 'Polygon') {
        final coords = geom['coordinates'] as List<dynamic>;
        // coords[0] is the outer ring; additional rings are holes (future work)
        final points = _coordListToLatLngs(coords[0] as List<dynamic>);
        if (points.length < 3) return [];
        return [buildPolygon(points, properties)];
      } else {
        // MultiPolygon — emit one Polygon per member (no silent data loss)
        final polygons = geom['coordinates'] as List<dynamic>;
        return polygons
            .map((poly) {
              final rings = poly as List<dynamic>;
              return _coordListToLatLngs(rings[0] as List<dynamic>);
            })
            .where((pts) => pts.length >= 3)
            .map((pts) => buildPolygon(pts, properties))
            .toList();
      }
    } catch (e) {
      debugPrint('WfsFeatureParser: Error parsing Polygon: $e');
      return [];
    }
  }

  // --------------- WfsFeature -----------------------------------------------

  WfsFeature? _parseWfsFeature(Object? feature) {
    final geomType = _geometryType(feature);
    if (geomType == null) return null;

    final f = feature as Map<String, dynamic>;
    final properties = _properties(f);
    final id = f['id'] as String?;
    final geom = f['geometry'] as Map<String, dynamic>;
    WfsGeometry geometry;

    switch (geomType) {
      case 'Point':
        final coords = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.point,
          points: [_coordToLatLng(coords)],
        );
      case 'MultiPoint':
        final coords = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.multiPoint,
          points: _coordListToLatLngs(coords),
        );
      case 'LineString':
        final coords = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.lineString,
          lines: [_coordListToLatLngs(coords)],
        );
      case 'MultiLineString':
        final lines = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.multiLineString,
          lines: lines
              .map((l) => _coordListToLatLngs(l as List<dynamic>))
              .toList(),
        );
      case 'Polygon':
        final coords = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.polygon,
          polygons: [_coordListToLatLngs(coords[0] as List<dynamic>)],
        );
      case 'MultiPolygon':
        final polys = geom['coordinates'] as List<dynamic>;
        geometry = WfsGeometry(
          type: WfsGeometryType.multiPolygon,
          polygons: polys
              .map((p) {
                final rings = p as List<dynamic>;
                return _coordListToLatLngs(rings[0] as List<dynamic>);
              })
              .toList(),
        );
      default:
        geometry = const WfsGeometry(type: WfsGeometryType.unknown);
    }

    return WfsFeature(geometry: geometry, properties: properties, id: id);
  }
}
