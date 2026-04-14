/// Configuration model for [WfsLayer].
///
/// All fields are immutable. Use [copyWith] to create a modified copy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Holds all configuration options for a [WfsLayer].
///
/// Pass an instance of this class to [WfsLayer.options]:
///
/// ```dart
/// WfsLayer(
///   mapController: mapController,
///   options: WfsLayerOptions(
///     url: 'https://my-server.com/geoserver/wfs',
///     typeName: 'my:layer',
///   ),
/// )
/// ```
class WfsLayerOptions {
  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// The base URL of the WFS server endpoint.
  ///
  /// Example: `'https://demo.geoserver.org/geoserver/wfs'`
  final String url;

  /// The `typeName` (layer name) to request from the WFS server.
  ///
  /// Example: `'topp:states'`
  final String typeName;

  /// The spatial reference system to use. Defaults to `'EPSG:4326'`.
  final String? srsName;

  /// WFS protocol version. Defaults to `'1.1.0'`.
  ///
  /// Common values: `'1.0.0'`, `'1.1.0'`, `'2.0.0'`.
  final String version;

  /// Additional query parameters merged into every WFS request.
  ///
  /// Use this to pass server-specific filters, `CQL_FILTER`, etc.
  final Map<String, String>? customParams;

  // ---------------------------------------------------------------------------
  // Feature loading
  // ---------------------------------------------------------------------------

  /// Maximum number of features to fetch per request.
  ///
  /// Defaults to `1000`. Increase carefully — large values may cause
  /// slow responses or timeouts.
  final int maxFeatures;

  /// Per-request HTTP timeout. Defaults to `Duration(seconds: 30)`.
  final Duration timeout;

  /// How many times to retry a failed request. Defaults to `3`.
  ///
  /// Set to `0` to disable retries.
  final int retryAttempts;

  /// Delay between retry attempts. Defaults to `Duration(seconds: 1)`.
  ///
  /// Each retry multiplies this delay by the attempt number (exponential).
  final Duration retryDelay;

  // ---------------------------------------------------------------------------
  // Caching
  // ---------------------------------------------------------------------------

  /// Whether to cache WFS responses in memory. Defaults to `true`.
  final bool enableCaching;

  /// How long a cached response remains valid. Defaults to `5 minutes`.
  final Duration cacheExpiry;

  // ---------------------------------------------------------------------------
  // Viewport optimisation
  // ---------------------------------------------------------------------------

  /// When `true`, features are only fetched for the current map viewport,
  /// and reloads are skipped when the viewport hasn't changed meaningfully.
  ///
  /// Defaults to `true`.
  final bool enableBboxOptimization;

  /// Extra padding added around the viewport bbox when fetching features,
  /// measured in degrees. Defaults to `0.001`.
  ///
  /// Increase this to pre-load features just outside the visible area.
  final double bboxBuffer;

  // ---------------------------------------------------------------------------
  // Marker styling
  // ---------------------------------------------------------------------------

  /// A custom widget builder for point markers.
  ///
  /// Receives the [BuildContext], the marker [LatLng], and the feature
  /// [properties] map. Return a [Widget] to replace the default icon.
  ///
  /// ```dart
  /// customMarkerBuilder: (context, point, properties) {
  ///   return Icon(Icons.place, color: Colors.blue);
  /// }
  /// ```
  final Widget Function(
    BuildContext context,
    LatLng point,
    Map<String, dynamic> properties,
  )? customMarkerBuilder;

  /// Colour of the default marker icon. Defaults to [Colors.red].
  final Color markerColor;

  /// Size (width and height) of the default marker icon in logical pixels.
  /// Defaults to `30.0`.
  final double markerSize;

  // ---------------------------------------------------------------------------
  // Polyline styling
  // ---------------------------------------------------------------------------

  /// Colour of rendered polylines. Defaults to [Colors.blue].
  final Color polylineColor;

  /// Stroke width of rendered polylines in logical pixels. Defaults to `2.0`.
  final double polylineWidth;

  // ---------------------------------------------------------------------------
  // Polygon styling
  // ---------------------------------------------------------------------------

  /// Fill colour of rendered polygons. Defaults to [Colors.green].
  final Color polygonFillColor;

  /// Border colour of rendered polygons. Defaults to [Colors.green].
  final Color polygonBorderColor;

  /// Border stroke width of rendered polygons. Defaults to `2.0`.
  final double polygonBorderWidth;

  /// Fill opacity for polygons, between `0.0` (transparent) and `1.0` (opaque).
  /// Defaults to `0.3`.
  final double polygonOpacity;

  // ---------------------------------------------------------------------------
  // Clustering
  // ---------------------------------------------------------------------------

  /// Whether to cluster nearby point markers. Defaults to `false`.
  ///
  /// Requires `flutter_map_marker_cluster` to be in your dependencies.
  final bool useClustering;

  /// Maximum pixel radius for grouping markers into a cluster.
  /// Defaults to `120`.
  final int maxClusterRadius;

  /// Display size of the cluster widget in logical pixels.
  /// Defaults to `Size(40, 40)`.
  final Size clusterSize;

  /// A custom builder for the cluster bubble widget.
  ///
  /// Receives the [BuildContext] and the list of [Marker]s in the cluster.
  /// Return a [Widget] to replace the default count badge.
  final Widget Function(BuildContext context, List<Marker> markers)?
      customClusterBuilder;

  // ---------------------------------------------------------------------------
  // Event callbacks
  // ---------------------------------------------------------------------------

  /// Called when the user taps a point marker.
  ///
  /// Receives the feature [properties] and the [LatLng] of the marker.
  final void Function(Map<String, dynamic> properties, LatLng position)?
      onMarkerTap;

  /// Called when the user taps a polyline.
  ///
  /// Receives the feature [properties] and the list of [LatLng] points.
  final void Function(Map<String, dynamic> properties, List<LatLng> points)?
      onPolylineTap;

  /// Called when the user taps a polygon.
  ///
  /// Receives the feature [properties] and the polygon's outer ring points.
  final void Function(Map<String, dynamic> properties, List<LatLng> points)?
      onPolygonTap;

  /// Called whenever the WFS layer encounters an error.
  ///
  /// The [error] string contains a human-readable description. Use this
  /// to display a toast or log the error in your own system.
  final void Function(String error)? onError;

  /// Called just before a WFS request is sent.
  final void Function()? onLoadStart;

  /// Called after a WFS request completes (whether successful or not).
  final void Function()? onLoadEnd;

  // ---------------------------------------------------------------------------
  // Performance
  // ---------------------------------------------------------------------------

  /// When `true` and [maxMarkersToRender] is exceeded, the layer renders
  /// only a evenly-spaced subset of markers to maintain frame rate.
  ///
  /// Prefer enabling [useClustering] instead for a better UX.
  /// Defaults to `false`.
  final bool enablePerformanceMode;

  /// Maximum number of markers to render simultaneously when
  /// [enablePerformanceMode] is `true`. Defaults to `500`.
  final int maxMarkersToRender;

  /// Creates a [WfsLayerOptions].
  const WfsLayerOptions({
    required this.url,
    required this.typeName,
    this.srsName = 'EPSG:4326',
    this.version = '1.1.0',
    this.customParams,
    this.maxFeatures = 1000,
    this.timeout = const Duration(seconds: 30),
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCaching = true,
    this.cacheExpiry = const Duration(minutes: 5),
    this.enableBboxOptimization = true,
    this.bboxBuffer = 0.001,
    this.customMarkerBuilder,
    this.markerColor = Colors.red,
    this.markerSize = 30.0,
    this.polylineColor = Colors.blue,
    this.polylineWidth = 2.0,
    this.polygonFillColor = Colors.green,
    this.polygonBorderColor = Colors.green,
    this.polygonBorderWidth = 2.0,
    this.polygonOpacity = 0.3,
    this.useClustering = false,
    this.maxClusterRadius = 120,
    this.clusterSize = const Size(40, 40),
    this.customClusterBuilder,
    this.onMarkerTap,
    this.onPolylineTap,
    this.onPolygonTap,
    this.onError,
    this.onLoadStart,
    this.onLoadEnd,
    this.enablePerformanceMode = false,
    this.maxMarkersToRender = 500,
  });

  /// Creates a copy of this options object with the specified fields replaced.
  WfsLayerOptions copyWith({
    String? url,
    String? typeName,
    String? srsName,
    String? version,
    Map<String, String>? customParams,
    int? maxFeatures,
    Duration? timeout,
    int? retryAttempts,
    Duration? retryDelay,
    bool? enableCaching,
    Duration? cacheExpiry,
    bool? enableBboxOptimization,
    double? bboxBuffer,
    Widget Function(BuildContext, LatLng, Map<String, dynamic>)?
        customMarkerBuilder,
    Color? markerColor,
    double? markerSize,
    Color? polylineColor,
    double? polylineWidth,
    Color? polygonFillColor,
    Color? polygonBorderColor,
    double? polygonBorderWidth,
    double? polygonOpacity,
    bool? useClustering,
    int? maxClusterRadius,
    Size? clusterSize,
    Widget Function(BuildContext, List<Marker>)? customClusterBuilder,
    void Function(Map<String, dynamic>, LatLng)? onMarkerTap,
    void Function(Map<String, dynamic>, List<LatLng>)? onPolylineTap,
    void Function(Map<String, dynamic>, List<LatLng>)? onPolygonTap,
    void Function(String)? onError,
    void Function()? onLoadStart,
    void Function()? onLoadEnd,
    bool? enablePerformanceMode,
    int? maxMarkersToRender,
  }) {
    return WfsLayerOptions(
      url: url ?? this.url,
      typeName: typeName ?? this.typeName,
      srsName: srsName ?? this.srsName,
      version: version ?? this.version,
      customParams: customParams ?? this.customParams,
      maxFeatures: maxFeatures ?? this.maxFeatures,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      enableCaching: enableCaching ?? this.enableCaching,
      cacheExpiry: cacheExpiry ?? this.cacheExpiry,
      enableBboxOptimization:
          enableBboxOptimization ?? this.enableBboxOptimization,
      bboxBuffer: bboxBuffer ?? this.bboxBuffer,
      customMarkerBuilder: customMarkerBuilder ?? this.customMarkerBuilder,
      markerColor: markerColor ?? this.markerColor,
      markerSize: markerSize ?? this.markerSize,
      polylineColor: polylineColor ?? this.polylineColor,
      polylineWidth: polylineWidth ?? this.polylineWidth,
      polygonFillColor: polygonFillColor ?? this.polygonFillColor,
      polygonBorderColor: polygonBorderColor ?? this.polygonBorderColor,
      polygonBorderWidth: polygonBorderWidth ?? this.polygonBorderWidth,
      polygonOpacity: polygonOpacity ?? this.polygonOpacity,
      useClustering: useClustering ?? this.useClustering,
      maxClusterRadius: maxClusterRadius ?? this.maxClusterRadius,
      clusterSize: clusterSize ?? this.clusterSize,
      customClusterBuilder: customClusterBuilder ?? this.customClusterBuilder,
      onMarkerTap: onMarkerTap ?? this.onMarkerTap,
      onPolylineTap: onPolylineTap ?? this.onPolylineTap,
      onPolygonTap: onPolygonTap ?? this.onPolygonTap,
      onError: onError ?? this.onError,
      onLoadStart: onLoadStart ?? this.onLoadStart,
      onLoadEnd: onLoadEnd ?? this.onLoadEnd,
      enablePerformanceMode:
          enablePerformanceMode ?? this.enablePerformanceMode,
      maxMarkersToRender: maxMarkersToRender ?? this.maxMarkersToRender,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WfsLayerOptions &&
        other.url == url &&
        other.typeName == typeName &&
        other.srsName == srsName &&
        other.version == version &&
        other.maxFeatures == maxFeatures &&
        other.useClustering == useClustering &&
        other.enableCaching == enableCaching;
  }

  @override
  int get hashCode => Object.hash(
        url,
        typeName,
        srsName,
        version,
        maxFeatures,
        useClustering,
        enableCaching,
      );
}
