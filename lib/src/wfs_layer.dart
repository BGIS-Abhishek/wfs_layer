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

  const WfsLayer({Key? key, required this.options}) : super(key: key);

  @override
  State<WfsLayer> createState() => _WfsLayerState();
}

class _WfsLayerState extends State<WfsLayer> {
  final MapController _mapController = MapController();
  late Future<Map<String, dynamic>> _featuresFuture;
  Timer? _debounceTimer;

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

  @override
  void initState() {
    super.initState();
    _featuresFuture = Future.value({}); // Initial empty future
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Debounces map position changes to avoid excessive fetching.
  void _onPositionChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _featuresFuture = _fetchFeatures(_mapController.camera.visibleBounds);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(19.9975, 73.7898),
        initialZoom: 10,
        onMapReady: () {
          setState(() {
            _featuresFuture = _fetchFeatures(_mapController.camera.visibleBounds);
          });
        },
        onPositionChanged: (position, hasGesture) {
          // if (hasGesture) {
          //   _onPositionChanged();
          // }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _featuresFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _featuresFuture = _fetchFeatures(_mapController.camera.visibleBounds);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasData) {
              final data = snapshot.data!;
              final features = data['features'] as List<dynamic>? ?? [];
              final markers = _parsePoints(features);
              final polylines = _parseLines(features);
              final polygons = _parsePolygons(features);

              List<Widget> layers = [];

              if (widget.options.useClustering && markers.isNotEmpty) {
                layers.add(
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 120,
                      size: const Size(40, 40),
                      markers: markers,
                      onMarkerTap: (marker) {
                        if (widget.options.onMarkerTap != null) {
                          // Find the marker's feature by matching its position
                          final feature = features.firstWhere(
                                (f) {
                              final coords = f['geometry']['coordinates'] as List<dynamic>;
                              return LatLng(coords[1], coords[0]) == marker.point;
                            },
                            orElse: () => null,
                          );
                          if (feature != null) {
                            final properties = feature['properties'] as Map<String, dynamic>? ?? {};
                            widget.options.onMarkerTap!(properties, marker.point);
                          }
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
                layers.add(
                  MarkerLayer(markers: markers),
                );
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
        ),
      ],
    );
  }
}