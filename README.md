# wfs_layer

[![pub package](https://img.shields.io/pub/v/wfs_layer.svg)](https://pub.dev/packages/wfs_layer)
[![pub points](https://img.shields.io/pub/points/wfs_layer)](https://pub.dev/packages/wfs_layer/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Flutter package for loading and displaying **Web Feature Service (WFS)** layers on a [`flutter_map`](https://pub.dev/packages/flutter_map) widget.

Supports **Points**, **LineStrings**, **Polygons**, **MultiLineStrings**, and **MultiPolygons** out of the box, with marker clustering, viewport-based bbox fetching, in-memory caching, automatic retries, and full customisation via override-friendly APIs.

---

## Platform Support

| Android | iOS | Web | macOS | Linux | Windows |
|:-------:|:---:|:---:|:-----:|:-----:|:-------:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Features

- 🗺 **All GeoJSON geometry types** — Point, LineString, Polygon, MultiLineString, MultiPolygon
- 📌 **Marker clustering** via `flutter_map_marker_cluster`
- ⚡ **Viewport bbox optimisation** — fetches only visible features
- 💾 **In-memory response caching** with configurable TTL and LRU eviction
- 🔁 **Automatic retries** with exponential back-off
- 🎨 **Full styling control** — colours, sizes, opacity, custom widget builders
- 🧩 **Extensible parser** — subclass `WfsFeatureParser` to override individual geometry builders
- 📦 **Typed models** — `WfsFeature` / `WfsGeometry` for type-safe property access
- 🌐 **Web-compatible** — no `dart:io` imports
- 🧪 **Unit tested** — parser and cache tested without a Flutter environment

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  flutter_map: ^7.0.2
  wfs_layer: ^0.1.0
```

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wfs_layer/wfs_layer.dart';

final mapController = MapController();

FlutterMap(
  mapController: mapController,
  options: const MapOptions(
    initialCenter: LatLng(51.5, -0.09),
    initialZoom: 12,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.myapp',
    ),
    WfsLayer(
      mapController: mapController,
      options: WfsLayerOptions(
        url: 'https://your-geoserver.com/geoserver/wfs',
        typeName: 'workspace:layername',
      ),
    ),
  ],
)
```

---

## Configuration Reference

All options are set via `WfsLayerOptions`. Every field is documented inline.

### Connection

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `url` | `String` | **required** | WFS server base URL |
| `typeName` | `String` | **required** | Layer name (e.g. `'topp:states'`) |
| `version` | `String` | `'1.1.0'` | WFS protocol version |
| `srsName` | `String?` | `'EPSG:4326'` | Spatial reference system |
| `customParams` | `Map<String,String>?` | `null` | Extra query parameters (e.g. CQL filters) |
| `maxFeatures` | `int` | `1000` | Max features per request |
| `timeout` | `Duration` | `30s` | Per-request HTTP timeout |
| `retryAttempts` | `int` | `3` | Number of retry attempts |
| `retryDelay` | `Duration` | `1s` | Base delay between retries (exponential) |

### Caching

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enableCaching` | `bool` | `true` | Cache responses in memory |
| `cacheExpiry` | `Duration` | `5 min` | Time-to-live for cached entries |

### Viewport Optimisation

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enableBboxOptimization` | `bool` | `true` | Skip reload if viewport hasn't changed |
| `bboxBuffer` | `double` | `0.001` | Extra degrees of padding around the bbox |

### Marker Styling

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `markerColor` | `Color` | `Colors.red` | Default marker icon colour |
| `markerSize` | `double` | `30.0` | Marker width & height (logical pixels) |
| `customMarkerBuilder` | `Widget Function(context, point, props)?` | `null` | Custom marker widget |

### Polyline Styling

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `polylineColor` | `Color` | `Colors.blue` | Stroke colour |
| `polylineWidth` | `double` | `2.0` | Stroke width |

### Polygon Styling

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `polygonFillColor` | `Color` | `Colors.green` | Fill colour |
| `polygonBorderColor` | `Color` | `Colors.green` | Border colour |
| `polygonBorderWidth` | `double` | `2.0` | Border stroke width |
| `polygonOpacity` | `double` | `0.3` | Fill opacity (0.0–1.0) |

### Clustering

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `useClustering` | `bool` | `false` | Enable marker clustering |
| `maxClusterRadius` | `int` | `120` | Cluster radius in pixels |
| `clusterSize` | `Size` | `Size(40,40)` | Cluster bubble size |
| `customClusterBuilder` | `Widget Function(context, markers)?` | `null` | Custom cluster widget |

### Callbacks

| Field | Signature | Description |
|-------|-----------|-------------|
| `onMarkerTap` | `(properties, position) → void` | Point marker tap |
| `onPolylineTap` | `(properties, points) → void` | Polyline tap |
| `onPolygonTap` | `(properties, points) → void` | Polygon tap |
| `onError` | `(error) → void` | Error handler |
| `onLoadStart` | `() → void` | Before each request |
| `onLoadEnd` | `() → void` | After each request |

---

## Customisation

### Custom Marker Widget

Use `customMarkerBuilder` for data-driven markers:

```dart
WfsLayerOptions(
  url: '...',
  typeName: '...',
  customMarkerBuilder: (context, point, properties) {
    final status = properties['status'] as String? ?? 'unknown';
    return Icon(
      Icons.circle,
      color: status == 'active' ? Colors.green : Colors.grey,
      size: 24,
    );
  },
)
```

### Custom Cluster Widget

```dart
WfsLayerOptions(
  url: '...',
  typeName: '...',
  useClustering: true,
  customClusterBuilder: (context, markers) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.indigo,
      ),
      child: Center(
        child: Text(
          '${markers.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  },
)
```

### CQL / Server-Side Filtering

Pass any extra WFS parameters via `customParams`:

```dart
WfsLayerOptions(
  url: '...',
  typeName: '...',
  customParams: {
    'CQL_FILTER': "status='active'",
  },
)
```

### Overriding the Parser

Subclass `WfsFeatureParser` to change how individual geometry types are built — without forking the whole widget:

```dart
class MyParser extends WfsFeatureParser {
  const MyParser(super.options);

  @override
  Marker? buildMarker(LatLng point, Map<String, dynamic> properties, BuildContext context) {
    // Completely custom marker logic using properties
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: MyCustomPin(label: properties['name'] as String?),
    );
  }

  @override
  Polyline buildPolyline(List<LatLng> points, Map<String, dynamic> properties) {
    return Polyline(
      points: points,
      color: properties['type'] == 'highway' ? Colors.red : Colors.grey,
      strokeWidth: 3,
    );
  }
}
```

Then pass it to the widget:

```dart
WfsLayer(
  mapController: mapController,
  options: options,
  parser: MyParser(options),
)
```

---

## Typed Feature Access

Use `WfsFeatureParser.parseFeatures()` to get a typed list of `WfsFeature` objects:

```dart
final parser = WfsFeatureParser(options);
final features = parser.parseFeatures(rawGeoJsonFeatures);

for (final f in features) {
  print(f.id);                        // String?
  print(f.geometry.type);             // WfsGeometryType
  print(f.geometry.points.first);     // LatLng
  print(f.properties['name']);         // dynamic
}
```

---

## Contributing

Contributions are welcome! Please open an issue or pull request on [GitHub](https://github.com/yabhishek1906/wfs_layer).

---

## License

MIT — see [LICENSE](LICENSE).