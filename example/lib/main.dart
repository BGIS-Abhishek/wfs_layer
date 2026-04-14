import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wfs_layer/wfs_layer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WfsExampleApp());
}

/// Example application demonstrating the wfs_layer package.
class WfsExampleApp extends StatelessWidget {
  /// Creates the example app.
  const WfsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFS Layer Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WfsExamplePage(),
    );
  }
}

/// A page that demonstrates all major WFS layer features.
class WfsExamplePage extends StatefulWidget {
  /// Creates the example page.
  const WfsExamplePage({super.key});

  @override
  State<WfsExamplePage> createState() => _WfsExamplePageState();
}

class _WfsExamplePageState extends State<WfsExamplePage> {
  final MapController _mapController = MapController();
  String? _lastTappedFeature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WFS Layer Example'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(15.391, 74.122),
              initialZoom: 10,
            ),
            children: [
              // Base tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.wfs_layer_example',
              ),

              // WFS layer — replace url/typeName with your own server.
              WfsLayer(
                mapController: _mapController,
                options: WfsLayerOptions(
                  url: 'https://stable.demo.geonode.org/geoserver/geonode/wfs',
                  typeName: 'geonode:110kv_ponda_towers',
                  version: '1.0.0',

                  // ── Marker styling ────────────────────────────────────
                  markerColor: Colors.deepPurple,
                  markerSize: 32,

                  // Custom marker widget (receives properties for data-driven styling)
                  customMarkerBuilder: (context, point, properties) {
                    return const Icon(
                      Icons.electrical_services,
                      color: Colors.deepPurple,
                      size: 32,
                    );
                  },

                  // ── Polyline styling ──────────────────────────────────
                  polylineColor: Colors.orange,
                  polylineWidth: 3,

                  // ── Polygon styling ───────────────────────────────────
                  polygonFillColor: Colors.yellow,
                  polygonBorderColor: Colors.black,
                  polygonBorderWidth: 2,
                  polygonOpacity: 0.4,

                  // ── Clustering ────────────────────────────────────────
                  useClustering: true,
                  maxClusterRadius: 80,
                  clusterSize: const Size(44, 44),

                  // ── Performance ───────────────────────────────────────
                  maxFeatures: 500,
                  enableBboxOptimization: true,
                  bboxBuffer: 0.005,

                  // ── Caching ───────────────────────────────────────────
                  enableCaching: true,
                  cacheExpiry: const Duration(minutes: 10),

                  // ── Callbacks ─────────────────────────────────────────
                  onMarkerTap: (properties, position) {
                    setState(() {
                      _lastTappedFeature = properties.isNotEmpty
                          ? properties.toString()
                          : 'No properties';
                    });
                  },
                  onError: (error) {
                    // Handle errors — show a snack bar, log, etc.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('WFS Error: $error')),
                    );
                  },
                ),
              ),
            ],
          ),

          // Show tapped feature properties at the bottom.
          if (_lastTappedFeature != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Feature Properties',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastTappedFeature!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}