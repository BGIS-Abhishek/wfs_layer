/// Typed data models for GeoJSON features returned by a WFS server.
///
/// These models give consumers of the package a typed, structured way
/// to work with WFS data in callbacks and custom builders.
library;

import 'package:latlong2/latlong.dart';

/// Supported GeoJSON geometry types.
enum WfsGeometryType {
  /// A single point.
  point,

  /// A sequence of connected line segments.
  lineString,

  /// A closed polygon (with optional holes).
  polygon,

  /// A collection of points.
  multiPoint,

  /// A collection of line strings.
  multiLineString,

  /// A collection of polygons.
  multiPolygon,

  /// An unrecognised or unsupported geometry type.
  unknown,
}

/// A single GeoJSON Feature parsed from a WFS response.
///
/// Example usage in a tap callback:
/// ```dart
/// onMarkerTap: (feature) {
///   print(feature.properties['name']);
///   print(feature.geometry.type);
/// }
/// ```
class WfsFeature {
  /// The parsed geometry of this feature.
  final WfsGeometry geometry;

  /// Arbitrary key-value properties from the WFS server.
  ///
  /// Values may be `String`, `num`, `bool`, `null`, or nested structures.
  final Map<String, dynamic> properties;

  /// Optional feature id as returned by the WFS server.
  final String? id;

  /// Creates a [WfsFeature].
  const WfsFeature({
    required this.geometry,
    required this.properties,
    this.id,
  });

  @override
  String toString() =>
      'WfsFeature(id: $id, type: ${geometry.type}, properties: $properties)';
}

/// The geometry of a [WfsFeature].
class WfsGeometry {
  /// The GeoJSON geometry type.
  final WfsGeometryType type;

  /// For [WfsGeometryType.point] and [WfsGeometryType.multiPoint]:
  /// the list of points. Single points have exactly one element.
  final List<LatLng> points;

  /// For [WfsGeometryType.lineString] and [WfsGeometryType.multiLineString]:
  /// each inner list is one line. Single LineStrings have one inner list.
  final List<List<LatLng>> lines;

  /// For [WfsGeometryType.polygon] and [WfsGeometryType.multiPolygon]:
  /// each inner list is one polygon's outer ring.
  ///
  /// Holes are not currently represented but the structure supports
  /// future extension.
  final List<List<LatLng>> polygons;

  /// Creates a [WfsGeometry].
  const WfsGeometry({
    required this.type,
    this.points = const [],
    this.lines = const [],
    this.polygons = const [],
  });

  @override
  String toString() => 'WfsGeometry(type: $type)';
}
