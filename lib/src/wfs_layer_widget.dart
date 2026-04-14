/// The main [WfsLayer] widget and its internal state.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'wfs_cache.dart';
import 'wfs_feature_parser.dart';
import 'wfs_layer_options.dart';

/// A flutter_map layer that fetches and renders features from a WFS server.
///
/// Place this widget inside [FlutterMap.children]:
///
/// ```dart
/// FlutterMap(
///   mapController: mapController,
///   options: MapOptions(initialCenter: LatLng(51.5, -0.09)),
///   children: [
///     TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
///     WfsLayer(
///       mapController: mapController,
///       options: WfsLayerOptions(
///         url: 'https://demo.geoserver.org/geoserver/wfs',
///         typeName: 'topp:states',
///       ),
///     ),
///   ],
/// )
/// ```
///
/// ### Customisation
///
/// Supply a custom [WfsFeatureParser] subclass to override individual
/// geometry builders without replacing the whole widget:
///
/// ```dart
/// WfsLayer(
///   mapController: mapController,
///   options: WfsLayerOptions(url: '...', typeName: '...'),
///   parser: MyCustomParser(options),
/// )
/// ```
class WfsLayer extends StatefulWidget {
  /// Configuration for this WFS layer.
  final WfsLayerOptions options;

  /// The [MapController] of the parent [FlutterMap].
  ///
  /// Used to listen to map events and read the current viewport.
  final MapController mapController;

  /// Optional custom parser. Defaults to [WfsFeatureParser].
  ///
  /// Provide a subclass of [WfsFeatureParser] to override how individual
  /// geometry types are parsed or rendered.
  final WfsFeatureParser? parser;

  /// Creates a [WfsLayer].
  const WfsLayer({
    super.key,
    required this.options,
    required this.mapController,
    this.parser,
  });

  @override
  State<WfsLayer> createState() => _WfsLayerState();
}

class _WfsLayerState extends State<WfsLayer> with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _featuresFuture;
  late WfsFeatureParser _parser;

  Timer? _debounceTimer;
  StreamSubscription<MapEvent>? _mapEventSubscription;

  bool _mapReady = false;
  bool _isLoading = false;
  bool _disposed = false;

  final WfsCache _cache = WfsCache();
  LatLngBounds? _lastBounds;
  double? _lastZoom;

  late http.Client _httpClient;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _httpClient = http.Client();
    _parser = widget.parser ?? WfsFeatureParser(widget.options);
    _featuresFuture = Future.value(null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMapListener();
    });
  }

  @override
  void didUpdateWidget(WfsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-create parser if options changed and no custom parser was supplied.
    if (oldWidget.options != widget.options && widget.parser == null) {
      _parser = WfsFeatureParser(widget.options);
    }
    if (oldWidget.options != widget.options) {
      _cache.clear();
      _loadFeaturesWithDebounce();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _cache.evictExpired(widget.options.cacheExpiry);
    }
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

  // ---------------------------------------------------------------------------
  // Map listener & debounce
  // ---------------------------------------------------------------------------

  void _initializeMapListener() {
    if (_disposed) return;

    try {
      // Accessing `.camera` throws if the map is not yet ready.
      final _ = widget.mapController.camera;

      if (!mounted || _disposed) return;
      setState(() => _mapReady = true);
      _loadFeaturesWithDebounce();

      _mapEventSubscription =
          widget.mapController.mapEventStream.listen((event) {
        if (!_disposed && _mapReady && mounted) {
          if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
            _loadFeaturesWithDebounce();
          }
        }
      });
    } catch (_) {
      // Map not ready yet — retry once after a short delay.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_disposed) _initializeMapListener();
      });
    }
  }

  void _loadFeaturesWithDebounce() {
    if (!_mapReady || !mounted || _disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _mapReady && !_disposed) _loadFeatures();
    });
  }

  void _loadFeatures() {
    if (_isLoading || _disposed) return;

    final currentBounds = widget.mapController.camera.visibleBounds;
    final currentZoom = widget.mapController.camera.zoom;

    if (_shouldSkipReload(currentBounds, currentZoom)) return;

    setState(() {
      _isLoading = true;
      _featuresFuture = _fetchWithRetry(currentBounds);
      _lastBounds = currentBounds;
      _lastZoom = currentZoom;
    });

    widget.options.onLoadStart?.call();
  }

  // ---------------------------------------------------------------------------
  // Reload guard
  // ---------------------------------------------------------------------------

  bool _shouldSkipReload(LatLngBounds current, double zoom) {
    if (_lastBounds == null || _lastZoom == null) return false;
    if (!widget.options.enableBboxOptimization) return false;

    final boundsUnchanged =
        _boundsContains(_lastBounds!, current, widget.options.bboxBuffer);
    final zoomUnchanged = (zoom - _lastZoom!).abs() <= 0.5;
    return boundsUnchanged && zoomUnchanged;
  }

  /// Returns `true` if [container] (with [buffer] padding) fully contains [inner].
  bool _boundsContains(
    LatLngBounds container,
    LatLngBounds inner,
    double buffer,
  ) {
    return container.southWest.latitude - buffer <=
            inner.southWest.latitude &&
        container.southWest.longitude - buffer <=
            inner.southWest.longitude &&
        container.northEast.latitude + buffer >= inner.northEast.latitude &&
        container.northEast.longitude + buffer >= inner.northEast.longitude;
  }

  // ---------------------------------------------------------------------------
  // Networking with retry
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchWithRetry(LatLngBounds bounds) async {
    for (var attempt = 1; attempt <= widget.options.retryAttempts; attempt++) {
      try {
        final result = await _fetchFeatures(bounds);
        _isLoading = false;
        widget.options.onLoadEnd?.call();
        return result;
      } catch (e) {
        if (attempt == widget.options.retryAttempts) {
          _isLoading = false;
          widget.options.onLoadEnd?.call();
          _handleError(
            'Failed after ${widget.options.retryAttempts} attempts: $e',
          );
          return null;
        }
        debugPrint('WfsLayer: attempt $attempt failed: $e');
        await Future<void>.delayed(widget.options.retryDelay * attempt);
      }
    }
    _isLoading = false;
    widget.options.onLoadEnd?.call();
    return null;
  }

  Future<Map<String, dynamic>> _fetchFeatures(LatLngBounds bounds) async {
    final cacheKey = _cacheKey(bounds);

    final cached = widget.options.enableCaching
        ? _cache.get(cacheKey, widget.options.cacheExpiry)
        : null;
    if (cached != null) return cached;

    final expanded =
        _expandBounds(bounds, widget.options.bboxBuffer);
    final sw = expanded.southWest;
    final ne = expanded.northEast;
    final srs = widget.options.srsName ?? 'EPSG:4326';

    final params = <String, String>{
      'service': 'WFS',
      'version': widget.options.version,
      'request': 'GetFeature',
      'typeName': widget.options.typeName,
      'outputFormat': 'application/json',
      'srsName': srs,
      'maxFeatures': widget.options.maxFeatures.toString(),
      'bbox':
          '${sw.longitude},${sw.latitude},${ne.longitude},${ne.latitude},$srs',
      if (widget.options.customParams != null) ...widget.options.customParams!,
    };

    final uri =
        Uri.parse(widget.options.url).replace(queryParameters: params);

    final http.Response response;
    try {
      response =
          await _httpClient.get(uri).timeout(widget.options.timeout);
    } on TimeoutException {
      throw Exception(
        'WFS request timed out after '
        '${widget.options.timeout.inSeconds}s',
      );
    } catch (e) {
      // Covers SocketException on mobile/desktop and network errors on web.
      throw Exception('WFS network error: $e');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'WFS server returned HTTP ${response.statusCode}: '
        '${response.reasonPhrase}',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw Exception('WFS returned invalid JSON: $e');
    }

    if (!_isValidGeoJson(data)) {
      throw Exception(
        'WFS response is not a valid GeoJSON FeatureCollection',
      );
    }

    if (widget.options.enableCaching) {
      _cache.put(cacheKey, data, bounds);
      _cache.evictExpired(widget.options.cacheExpiry);
    }

    return data;
  }

  bool _isValidGeoJson(Map<String, dynamic> data) =>
      data['type'] == 'FeatureCollection' && data['features'] is List;

  LatLngBounds _expandBounds(LatLngBounds b, double buf) => LatLngBounds(
        LatLng(b.southWest.latitude - buf, b.southWest.longitude - buf),
        LatLng(b.northEast.latitude + buf, b.northEast.longitude + buf),
      );

  String _cacheKey(LatLngBounds b) {
    final sw = b.southWest;
    final ne = b.northEast;
    return '${widget.options.typeName}_'
        '${sw.latitude.toStringAsFixed(4)}_'
        '${sw.longitude.toStringAsFixed(4)}_'
        '${ne.latitude.toStringAsFixed(4)}_'
        '${ne.longitude.toStringAsFixed(4)}';
  }

  void _handleError(String error) {
    debugPrint('WfsLayer: $error');
    widget.options.onError?.call(error);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _featuresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingIndicator(options: widget.options);
        }
        if (snapshot.hasError) {
          return _ErrorIndicator(
            error: snapshot.error.toString(),
            options: widget.options,
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return _buildLayerContent(context, snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLayerContent(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    final markers = _parser.parseMarkers(features, context);
    final polylines = _parser.parsePolylines(features);
    final polygons = _parser.parsePolygons(features);

    final layers = <Widget>[];

    if (markers.isNotEmpty) {
      layers.add(_buildMarkerLayer(markers, features));
    }
    if (polylines.isNotEmpty) {
      layers.add(PolylineLayer(polylines: polylines));
    }
    if (polygons.isNotEmpty) {
      layers.add(PolygonLayer(polygons: polygons));
    }

    return Stack(children: layers);
  }

  Widget _buildMarkerLayer(List<Marker> markers, List<dynamic> features) {
    if (widget.options.useClustering) {
      return MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: widget.options.maxClusterRadius,
          size: widget.options.clusterSize,
          markers: markers,
          onMarkerTap: (marker) => _handleClusteredMarkerTap(marker, features),
          builder: widget.options.customClusterBuilder ??
              _defaultClusterBuilder,
        ),
      );
    }

    if (widget.options.enablePerformanceMode &&
        markers.length > widget.options.maxMarkersToRender) {
      final step =
          (markers.length / widget.options.maxMarkersToRender).ceil();
      return MarkerLayer(
        markers: [
          for (var i = 0; i < markers.length; i += step) markers[i],
        ],
      );
    }

    return MarkerLayer(markers: markers);
  }

  void _handleClusteredMarkerTap(Marker marker, List<dynamic> features) {
    if (widget.options.onMarkerTap == null) return;
    try {
      final feature = (features as List<Object?>).firstWhere(
        (f) {
          final map = f as Map<String, dynamic>;
          final geom = map['geometry'] as Map<String, dynamic>?;
          if (geom?['type'] != 'Point') return false;
          final c = geom!['coordinates'] as List<dynamic>;
          return (LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())
                  .latitude -
                      marker.point.latitude)
                  .abs() <
              0.0001 &&
              ((c[0] as num).toDouble() - marker.point.longitude).abs() <
                  0.0001;
        },
        orElse: () => <String, dynamic>{'properties': <String, dynamic>{}},
      ) as Map<String, dynamic>;
      final props =
          (feature['properties'] as Map<String, dynamic>?) ?? {};
      widget.options.onMarkerTap!(props, marker.point);
    } catch (e) {
      debugPrint('WfsLayer: Error handling clustered marker tap: $e');
    }
  }

  Widget _defaultClusterBuilder(
    BuildContext context,
    List<Marker> clusterMarkers,
  ) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.options.markerColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
}

// ---------------------------------------------------------------------------
// Private helper widgets — kept in this file for locality
// ---------------------------------------------------------------------------

/// A small loading indicator that overlays the map during a WFS fetch.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.options});

  final WfsLayerOptions options;

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 10,
      right: 10,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading WFS…'),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small error badge that overlays the map when a WFS fetch fails.
class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({required this.error, required this.options});

  final String error;
  final WfsLayerOptions options;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      child: Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'WFS Error',
                style: TextStyle(color: Colors.red[800]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
