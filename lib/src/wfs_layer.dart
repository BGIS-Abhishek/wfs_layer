/*
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Configuration options for the WFS layer.
class WfsLayerOptions {
  final String url;
  final String typeName;
  final String? srsName;
  final String version;
  final Map<String, String>? customParams;
  final bool useClustering;

  final Widget Function(BuildContext, LatLng)? customMarkerBuilder;
  final Color? markerColor;
  final double? markerSize;
  final Color? polylineColor;
  final double? polylineWidth;
  final Color? polygonFillColor;
  final Color? polygonBorderColor;
  final double? polygonBorderWidth;
  /// Callback triggered when a marker is tapped, providing the feature's properties and coordinates.
  final Function(Map<String, dynamic> properties, LatLng position)? onMarkerTap;

  WfsLayerOptions({
    required this.url,
    required this.typeName,
    this.srsName = 'EPSG:4326',
    this.version = '1.1.0',
    this.customParams,
    this.useClustering = false,
    this.customMarkerBuilder,
    this.markerColor = Colors.red,
    this.markerSize = 20.0,
    this.polylineColor = Colors.blue,
    this.polylineWidth = 2.0,
    this.polygonFillColor = Colors.green,
    this.polygonBorderColor = Colors.green,
    this.polygonBorderWidth = 2.0,
    this.onMarkerTap,
  });
}

/// A Flutter widget to display WFS layers on a map.
class WfsLayer extends StatefulWidget {
  final WfsLayerOptions options;
  final MapController mapController;
  const WfsLayer({super.key, required this.options, required this.mapController});

  @override
  State<WfsLayer> createState() => _WfsLayerState();
}

class _WfsLayerState extends State<WfsLayer> {
  late Future<Map<String, dynamic>> _featuresFuture;
  Timer? _debounceTimer;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  bool _mapReady = false;

  /*
  @override
  void initState() {
    super.initState();
    _featuresFuture = Future.value({});
  }

   */


  @override
  void initState() {
    super.initState();
    _featuresFuture = _fetchFeatures(widget.mapController.camera.visibleBounds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMapListener();
    });
  }
  void _initializeMapListener() {
    // Check if map controller is ready
    try {
      if (widget.mapController.camera != null) {
        setState(() {
          _mapReady = true;
          _featuresFuture = _fetchFeatures(widget.mapController.camera.visibleBounds);
        });

        // Now safely add the map event listener
        _mapEventSubscription = widget.mapController.mapEventStream.listen((event) {
          if (_mapReady && mounted && event is MapEventMoveEnd) {
            _onPositionChanged();
          }
        });
      }
    } catch (e) {
      debugPrint('Map not ready yet: $e');
      // Retry after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _initializeMapListener();
      });
    }
  }




  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapEventSubscription?.cancel();
    super.dispose();
  }

  void _onPositionChanged() {
    if (!_mapReady || !mounted) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _mapReady) {
        setState(() {
          _featuresFuture = _fetchFeatures(widget.mapController.camera.visibleBounds);
        });
      }
    });
  }

  /*
  /// Debounces map position changes to avoid excessive fetching.
  void _onPositionChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _featuresFuture = _fetchFeatures(widget.mapController.camera.visibleBounds);
      });
    });
  }

   */


  /// Fetches WFS features within the given bounds.

  Future<Map<String, dynamic>> _fetchFeatures(LatLngBounds bounds) async {
    final southWest = bounds.southWest;
    final northEast = bounds.northEast;

    final params = {
      'service': 'WFS',
      'version': widget.options.version,
      'request': 'GetFeature',
      'typeName': widget.options.typeName,
      'outputFormat': 'application/json',
      'srsName': widget.options.srsName ?? 'EPSG:4326',
      'bbox': '${southWest.longitude},${southWest.latitude},${northEast.longitude},${northEast.latitude},${widget.options.srsName}',
      ...?widget.options.customParams,
    };

    final uri = Uri.parse(widget.options.url).replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load WFS data: ${response.statusCode}');
    }
  }





  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _featuresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        } else if (snapshot.hasError) {
          return const Center(child: Text("Error loading WFS data"));
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          final features = data['features'] as List<dynamic>? ?? [];

          final markers = _parsePoints(features);
          final polylines = _parseLines(features);
          final polygons = _parsePolygons(features);

          final layers = <Widget>[];

          if (widget.options.useClustering && markers.isNotEmpty) {
            layers.add(
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 120,
                  size: const Size(40, 40),
                  markers: markers,
                  onMarkerTap: (marker) {
                    if (widget.options.onMarkerTap != null) {
                      final feature = features.firstWhere(
                            (f) {
                          final coords =
                          f['geometry']['coordinates'] as List<dynamic>;
                          return LatLng(coords[1], coords[0]) == marker.point;
                        },
                        orElse: () => {},
                      );
                      final properties =
                          feature['properties'] as Map<String, dynamic>? ?? {};
                      widget.options.onMarkerTap!(properties, marker.point);
                    }
                  },
                  builder: (context, clusterMarkers) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.options.markerColor ?? Colors.blue,
                      ),
                      child: Center(
                        child: Text(
                          clusterMarkers.length.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          } else if (markers.isNotEmpty) {
            layers.add(MarkerLayer(markers: markers));
          }

          if (polylines.isNotEmpty) {
            layers.add(PolylineLayer(polylines: polylines));
          }

          if (polygons.isNotEmpty) {
            layers.add(PolygonLayer(polygons: polygons));
          }

          return Stack(children: layers);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  /// Parses GeoJSON features into Markers (Points).
  List<Marker> _parsePoints(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null && f['geometry']['type'] == 'Point')
        .map((f) {
      final coords = f['geometry']['coordinates'] as List<dynamic>;
      return Marker(
        width: widget.options.markerSize ?? 30,
        height: widget.options.markerSize ?? 30,
        point: LatLng(coords[1], coords[0]),
        child: widget.options.customMarkerBuilder != null
            ? widget.options.customMarkerBuilder!(context, LatLng(coords[1], coords[0]))
            : Icon(
          Icons.location_on,
          color: widget.options.markerColor,
          size: widget.options.markerSize,
        ),
      );
    }).toList();
  }

  /// Parses GeoJSON features into Polylines (LineStrings).
  List<Polyline> _parseLines(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null && f['geometry']['type'] == 'LineString')
        .map((f) {
      final coords = (f['geometry']['coordinates'] as List<dynamic>)
          .map((c) => c as List<dynamic>)
          .map((c) => LatLng(c[1], c[0]))
          .toList();
      return Polyline(
        points: coords,
        color: widget.options.polylineColor ?? Colors.blue,
        strokeWidth: widget.options.polylineWidth ?? 2.0,
      );
    }).toList();
  }

  /// Parses GeoJSON features into Polygons.
  List<Polygon> _parsePolygons(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null && f['geometry']['type'] == 'Polygon')
        .map((f) {
      final coords = (f['geometry']['coordinates'] as List<dynamic>)
          .map((ring) => (ring as List<dynamic>)
          .map((c) => LatLng(c[1], c[0]))
          .toList())
          .toList();
      return Polygon(
        points: coords.first,
        color: widget.options.polygonFillColor?.withOpacity(0.3) ?? Colors.green.withOpacity(0.3),
        borderColor: widget.options.polygonBorderColor ?? Colors.green,
        borderStrokeWidth: widget.options.polygonBorderWidth ?? 2.0,
      );
    }).toList();
  }

}

 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Enum for WFS request types
enum WfsRequestType { getFeature, getCapabilities, describeFeatureType }

/// Enum for geometry types
enum GeometryType { point, lineString, polygon, multiPoint, multiLineString, multiPolygon }

/// Configuration options for the WFS layer.
class WfsLayerOptions {
  final String url;
  final String typeName;
  final String? srsName;
  final String version;
  final Map<String, String>? customParams;
  final bool useClustering;
  final int maxFeatures;
  final Duration timeout;
  final int retryAttempts;
  final Duration retryDelay;
  final bool enableCaching;
  final Duration cacheExpiry;
  final bool enableBboxOptimization;
  final double bboxBuffer; // Buffer around viewport in degrees

  // Styling options
  final Widget Function(BuildContext, LatLng, Map<String, dynamic>)? customMarkerBuilder;
  final Color? markerColor;
  final double? markerSize;
  final Color? polylineColor;
  final double? polylineWidth;
  final Color? polygonFillColor;
  final Color? polygonBorderColor;
  final double? polygonBorderWidth;
  final double polygonOpacity;

  // Clustering options
  final int maxClusterRadius;
  final Size clusterSize;
  final Widget Function(BuildContext, List<Marker>)? customClusterBuilder;

  // Event callbacks
  final Function(Map<String, dynamic> properties, LatLng position)? onMarkerTap;
  final Function(Map<String, dynamic> properties, List<LatLng> points)? onPolylineTap;
  final Function(Map<String, dynamic> properties, List<LatLng> points)? onPolygonTap;
  final Function(String error)? onError;
  final Function()? onLoadStart;
  final Function()? onLoadEnd;

  // Performance options
  final bool enablePerformanceMode;
  final int maxMarkersToRender;

  const WfsLayerOptions({
    required this.url,
    required this.typeName,
    this.srsName = 'EPSG:4326',
    this.version = '1.1.0',
    this.customParams,
    this.useClustering = false,
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
    this.markerSize = 20.0,
    this.polylineColor = Colors.blue,
    this.polylineWidth = 2.0,
    this.polygonFillColor = Colors.green,
    this.polygonBorderColor = Colors.green,
    this.polygonBorderWidth = 2.0,
    this.polygonOpacity = 0.3,
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

  WfsLayerOptions copyWith({
    String? url,
    String? typeName,
    String? srsName,
    String? version,
    Map<String, String>? customParams,
    bool? useClustering,
    int? maxFeatures,
    Duration? timeout,
    int? retryAttempts,
    Duration? retryDelay,
    bool? enableCaching,
    Duration? cacheExpiry,
    bool? enableBboxOptimization,
    double? bboxBuffer,
    Widget Function(BuildContext, LatLng, Map<String, dynamic>)? customMarkerBuilder,
    Color? markerColor,
    double? markerSize,
    Color? polylineColor,
    double? polylineWidth,
    Color? polygonFillColor,
    Color? polygonBorderColor,
    double? polygonBorderWidth,
    double? polygonOpacity,
    int? maxClusterRadius,
    Size? clusterSize,
    Widget Function(BuildContext, List<Marker>)? customClusterBuilder,
    Function(Map<String, dynamic>, LatLng)? onMarkerTap,
    Function(Map<String, dynamic>, List<LatLng>)? onPolylineTap,
    Function(Map<String, dynamic>, List<LatLng>)? onPolygonTap,
    Function(String)? onError,
    Function()? onLoadStart,
    Function()? onLoadEnd,
    bool? enablePerformanceMode,
    int? maxMarkersToRender,
  }) {
    return WfsLayerOptions(
      url: url ?? this.url,
      typeName: typeName ?? this.typeName,
      srsName: srsName ?? this.srsName,
      version: version ?? this.version,
      customParams: customParams ?? this.customParams,
      useClustering: useClustering ?? this.useClustering,
      maxFeatures: maxFeatures ?? this.maxFeatures,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      enableCaching: enableCaching ?? this.enableCaching,
      cacheExpiry: cacheExpiry ?? this.cacheExpiry,
      enableBboxOptimization: enableBboxOptimization ?? this.enableBboxOptimization,
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
      maxClusterRadius: maxClusterRadius ?? this.maxClusterRadius,
      clusterSize: clusterSize ?? this.clusterSize,
      customClusterBuilder: customClusterBuilder ?? this.customClusterBuilder,
      onMarkerTap: onMarkerTap ?? this.onMarkerTap,
      onPolylineTap: onPolylineTap ?? this.onPolylineTap,
      onPolygonTap: onPolygonTap ?? this.onPolygonTap,
      onError: onError ?? this.onError,
      onLoadStart: onLoadStart ?? this.onLoadStart,
      onLoadEnd: onLoadEnd ?? this.onLoadEnd,
      enablePerformanceMode: enablePerformanceMode ?? this.enablePerformanceMode,
      maxMarkersToRender: maxMarkersToRender ?? this.maxMarkersToRender,
    );
  }
}

/// Cache entry for WFS responses
class WfsCacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final LatLngBounds bounds;

  WfsCacheEntry({
    required this.data,
    required this.timestamp,
    required this.bounds,
  });

  bool isExpired(Duration expiry) {
    return DateTime.now().difference(timestamp) > expiry;
  }
}

/// A Flutter widget to display WFS layers on a map.
class WfsLayer extends StatefulWidget {
  final WfsLayerOptions options;
  final MapController mapController;

  const WfsLayer({
    super.key,
    required this.options,
    required this.mapController,
  });

  @override
  State<WfsLayer> createState() => _WfsLayerState();
}

class _WfsLayerState extends State<WfsLayer> with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _featuresFuture;
  Timer? _debounceTimer;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  bool _mapReady = false;
  bool _isLoading = false;
  bool _disposed = false;

  // Cache management
  final Map<String, WfsCacheEntry> _cache = {};
  LatLngBounds? _lastBounds;
  double? _lastZoom;

  // Performance tracking
  int _currentMarkerCount = 0;

  // HTTP client with connection pooling
  late http.Client _httpClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _httpClient = http.Client();
    _featuresFuture = Future.value(null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMapListener();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _cleanupCache();
    }
  }

  void _initializeMapListener() {
    if (_disposed) return;

    try {
      if (widget.mapController.camera != null) {
        setState(() {
          _mapReady = true;
        });

        // Initial load
        _loadFeaturesWithDebounce();

        // Listen to map events
        _mapEventSubscription = widget.mapController.mapEventStream.listen((event) {
          if (!_disposed && _mapReady && mounted) {
            if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
              _loadFeaturesWithDebounce();
            }
          }
        });
      }
    } catch (e) {
      _handleError('Map initialization error: $e');
      // Retry after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_disposed) _initializeMapListener();
      });
    }
  }

  void _loadFeaturesWithDebounce() {
    if (!_mapReady || !mounted || _disposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _mapReady && !_disposed) {
        _loadFeatures();
      }
    });
  }

  void _loadFeatures() {
    if (_isLoading || _disposed) return;

    final currentBounds = widget.mapController.camera.visibleBounds;
    final currentZoom = widget.mapController.camera.zoom;

    // Check if we need to reload based on bounds change
    if (_shouldSkipReload(currentBounds, currentZoom)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _featuresFuture = _fetchFeaturesWithRetry(currentBounds);
      _lastBounds = currentBounds;
      _lastZoom = currentZoom;
    });

    widget.options.onLoadStart?.call();
  }

  bool _shouldSkipReload(LatLngBounds currentBounds, double currentZoom) {
    if (_lastBounds == null || _lastZoom == null) return false;

    // Skip if bounds haven't changed significantly
    if (widget.options.enableBboxOptimization) {
      final boundsChanged = !_boundsContain(_lastBounds!, currentBounds, widget.options.bboxBuffer);
      final zoomChanged = (currentZoom - _lastZoom!).abs() > 0.5;

      return !boundsChanged && !zoomChanged;
    }

    return false;
  }

  bool _boundsContain(LatLngBounds container, LatLngBounds contained, double buffer) {
    return container.southWest.latitude - buffer <= contained.southWest.latitude &&
        container.southWest.longitude - buffer <= contained.southWest.longitude &&
        container.northEast.latitude + buffer >= contained.northEast.latitude &&
        container.northEast.longitude + buffer >= contained.northEast.longitude;
  }

  Future<Map<String, dynamic>?> _fetchFeaturesWithRetry(LatLngBounds bounds) async {
    for (int attempt = 1; attempt <= widget.options.retryAttempts; attempt++) {
      try {
        final result = await _fetchFeatures(bounds);
        _isLoading = false;
        widget.options.onLoadEnd?.call();
        return result;
      } catch (e) {
        if (attempt == widget.options.retryAttempts) {
          _isLoading = false;
          widget.options.onLoadEnd?.call();
          _handleError('Failed to fetch WFS data after $attempt attempts: $e');
          return null;
        }

        debugPrint('WFS fetch attempt $attempt failed: $e');
        await Future.delayed(widget.options.retryDelay * attempt);
      }
    }

    _isLoading = false;
    widget.options.onLoadEnd?.call();
    return null;
  }

  Future<Map<String, dynamic>> _fetchFeatures(LatLngBounds bounds) async {
    final cacheKey = _generateCacheKey(bounds);

    // Check cache first
    if (widget.options.enableCaching && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired(widget.options.cacheExpiry)) {
        return entry.data;
      } else {
        _cache.remove(cacheKey);
      }
    }

    final expandedBounds = _expandBounds(bounds, widget.options.bboxBuffer);
    final southWest = expandedBounds.southWest;
    final northEast = expandedBounds.northEast;

    final params = <String, String>{
      'service': 'WFS',
      'version': widget.options.version,
      'request': 'GetFeature',
      'typeName': widget.options.typeName,
      'outputFormat': 'application/json',
      'srsName': widget.options.srsName ?? 'EPSG:4326',
      'maxFeatures': widget.options.maxFeatures.toString(),
      'bbox': '${southWest.longitude},${southWest.latitude},${northEast.longitude},${northEast.latitude},${widget.options.srsName}',
      if (widget.options.customParams != null) ...widget.options.customParams!,
    };

    final uri = Uri.parse(widget.options.url).replace(queryParameters: params);

    try {
      final response = await _httpClient.get(uri).timeout(widget.options.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Validate response structure
        if (!_isValidGeoJsonResponse(data)) {
          throw Exception('Invalid GeoJSON response structure');
        }

        // Cache the result
        if (widget.options.enableCaching) {
          _cache[cacheKey] = WfsCacheEntry(
            data: data,
            timestamp: DateTime.now(),
            bounds: bounds,
          );
          _cleanupCache();
        }

        return data;
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      throw Exception('Request timeout after ${widget.options.timeout.inSeconds} seconds');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response: ${e.message}');
    }
  }

  bool _isValidGeoJsonResponse(Map<String, dynamic> data) {
    return data.containsKey('type') &&
        data['type'] == 'FeatureCollection' &&
        data.containsKey('features') &&
        data['features'] is List;
  }

  LatLngBounds _expandBounds(LatLngBounds bounds, double buffer) {
    return LatLngBounds(
      LatLng(bounds.southWest.latitude - buffer, bounds.southWest.longitude - buffer),
      LatLng(bounds.northEast.latitude + buffer, bounds.northEast.longitude + buffer),
    );
  }

  String _generateCacheKey(LatLngBounds bounds) {
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    return '${widget.options.typeName}_${sw.latitude}_${sw.longitude}_${ne.latitude}_${ne.longitude}';
  }

  void _cleanupCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => entry.isExpired(widget.options.cacheExpiry));

    // Limit cache size
    if (_cache.length > 50) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      for (int i = 0; i < _cache.length - 30; i++) {
        _cache.remove(sortedEntries[i].key);
      }
    }
  }

  void _handleError(String error) {
    debugPrint('WFS Layer Error: $error');
    widget.options.onError?.call(error);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _mapEventSubscription?.cancel();
    _httpClient.close();
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _featuresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        } else if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        } else if (snapshot.hasData && snapshot.data != null) {
          return _buildLayerContent(snapshot.data!);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Positioned(
      top: 10,
      right: 10,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading WFS...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Positioned(
      top: 10,
      right: 10,
      child: Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text('WFS Error', style: TextStyle(color: Colors.red[800])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerContent(Map<String, dynamic> data) {
    final features = data['features'] as List<dynamic>? ?? [];

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    final markers = _parsePoints(features);
    final polylines = _parseLines(features);
    final polygons = _parsePolygons(features);

    _currentMarkerCount = markers.length;

    final layers = <Widget>[];

    // Add markers with clustering or performance optimization
    if (markers.isNotEmpty) {
      if (widget.options.useClustering) {
        layers.add(_buildClusteredMarkers(markers, features));
      } else if (widget.options.enablePerformanceMode &&
          markers.length > widget.options.maxMarkersToRender) {
        // Render only a subset of markers for performance
        final step = (markers.length / widget.options.maxMarkersToRender).ceil();
        final filteredMarkers = <Marker>[];
        for (int i = 0; i < markers.length; i += step) {
          filteredMarkers.add(markers[i]);
        }
        layers.add(MarkerLayer(markers: filteredMarkers));
      } else {
        layers.add(MarkerLayer(markers: markers));
      }
    }

    if (polylines.isNotEmpty) {
      layers.add(PolylineLayer(polylines: polylines));
    }

    if (polygons.isNotEmpty) {
      layers.add(PolygonLayer(polygons: polygons));
    }

    return Stack(children: layers);
  }

  Widget _buildClusteredMarkers(List<Marker> markers, List<dynamic> features) {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: widget.options.maxClusterRadius,
        size: widget.options.clusterSize,
        markers: markers,
        onMarkerTap: (marker) => _handleMarkerTap(marker, features),
        builder: widget.options.customClusterBuilder ?? _defaultClusterBuilder,
      ),
    );
  }

  Widget _defaultClusterBuilder(BuildContext context, List<Marker> clusterMarkers) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.options.markerColor ?? Colors.blue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          clusterMarkers.length.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _handleMarkerTap(Marker marker, List<dynamic> features) {
    if (widget.options.onMarkerTap != null) {
      try {
        final feature = features.firstWhere(
              (f) {
            if (f['geometry'] == null || f['geometry']['type'] != 'Point') return false;
            final coords = f['geometry']['coordinates'] as List<dynamic>;
            final featurePoint = LatLng(coords[1], coords[0]);
            return (featurePoint.latitude - marker.point.latitude).abs() < 0.0001 &&
                (featurePoint.longitude - marker.point.longitude).abs() < 0.0001;
          },
          orElse: () => {'properties': {}},
        );
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        widget.options.onMarkerTap!(properties, marker.point);
      } catch (e) {
        debugPrint('Error handling marker tap: $e');
      }
    }
  }

  List<Marker> _parsePoints(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null && f['geometry']['type'] == 'Point')
        .map((f) {
      try {
        final coords = f['geometry']['coordinates'] as List<dynamic>;
        final properties = f['properties'] as Map<String, dynamic>? ?? {};
        final point = LatLng(coords[1], coords[0]);

        return Marker(
          width: widget.options.markerSize ?? 30,
          height: widget.options.markerSize ?? 30,
          point: point,
          child: GestureDetector(
            onTap: () => widget.options.onMarkerTap?.call(properties, point),
            child: widget.options.customMarkerBuilder?.call(context, point, properties) ??
                Icon(
                  Icons.location_on,
                  color: widget.options.markerColor,
                  size: widget.options.markerSize,
                ),
          ),
        );
      } catch (e) {
        debugPrint('Error parsing point feature: $e');
        return null;
      }
    })
        .whereType<Marker>()
        .toList();
  }

  List<Polyline> _parseLines(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null &&
        (f['geometry']['type'] == 'LineString' ||
            f['geometry']['type'] == 'MultiLineString'))
        .map((f) {
      try {
        final properties = f['properties'] as Map<String, dynamic>? ?? {};
        final geomType = f['geometry']['type'] as String;
        List<LatLng> points;

        if (geomType == 'LineString') {
          points = (f['geometry']['coordinates'] as List<dynamic>)
              .map((c) => c as List<dynamic>)
              .map((c) => LatLng(c[1], c[0]))
              .toList();
        } else {
          // MultiLineString - take the first line
          final lines = f['geometry']['coordinates'] as List<dynamic>;
          if (lines.isNotEmpty) {
            points = (lines[0] as List<dynamic>)
                .map((c) => c as List<dynamic>)
                .map((c) => LatLng(c[1], c[0]))
                .toList();
          } else {
            return null;
          }
        }

        return Polyline(
          points: points,
          color: widget.options.polylineColor ?? Colors.blue,
          strokeWidth: widget.options.polylineWidth ?? 2.0,
          // onTap: (tapPosition, point) => widget.options.onPolylineTap?.call(properties, points),
        );
      } catch (e) {
        debugPrint('Error parsing line feature: $e');
        return null;
      }
    })
        .whereType<Polyline>()
        .toList();
  }

  List<Polygon> _parsePolygons(List<dynamic> features) {
    return features
        .where((f) => f['geometry'] != null &&
        (f['geometry']['type'] == 'Polygon' ||
            f['geometry']['type'] == 'MultiPolygon'))
        .map((f) {
      try {
        final properties = f['properties'] as Map<String, dynamic>? ?? {};
        final geomType = f['geometry']['type'] as String;
        List<LatLng> points;

        if (geomType == 'Polygon') {
          final coords = f['geometry']['coordinates'] as List<dynamic>;
          points = (coords[0] as List<dynamic>)
              .map((c) => c as List<dynamic>)
              .map((c) => LatLng(c[1], c[0]))
              .toList();
        } else {
          // MultiPolygon - take the first polygon
          final polygons = f['geometry']['coordinates'] as List<dynamic>;
          if (polygons.isNotEmpty) {
            final coords = polygons[0] as List<dynamic>;
            points = (coords[0] as List<dynamic>)
                .map((c) => c as List<dynamic>)
                .map((c) => LatLng(c[1], c[0]))
                .toList();
          } else {
            return null;
          }
        }

        return Polygon(
          points: points,
          color: (widget.options.polygonFillColor ?? Colors.green)
              .withOpacity(widget.options.polygonOpacity),
          borderColor: widget.options.polygonBorderColor ?? Colors.green,
          borderStrokeWidth: widget.options.polygonBorderWidth ?? 2.0,
          // onTap: (tapPosition, point) => widget.options.onPolygonTap?.call(properties, points),
        );
      } catch (e) {
        debugPrint('Error parsing polygon feature: $e');
        return null;
      }
    })
        .whereType<Polygon>()
        .toList();
  }
}
