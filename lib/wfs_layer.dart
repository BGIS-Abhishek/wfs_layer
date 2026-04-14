/// WFS Layer — A Flutter package for displaying Web Feature Service (WFS)
/// layers on a `flutter_map` map widget.
///
/// ## Quick start
///
/// ```dart
/// import 'package:wfs_layer/wfs_layer.dart';
///
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
/// ## Customisation
///
/// - Style with [WfsLayerOptions] fields like [WfsLayerOptions.customMarkerBuilder].
/// - Override individual geometry builders by subclassing [WfsFeatureParser].
/// - Work with typed GeoJSON data using [WfsFeature] and [WfsGeometry].
library;

export 'src/models/wfs_feature.dart';
export 'src/wfs_cache.dart' show WfsCache;
export 'src/wfs_feature_parser.dart';
export 'src/wfs_layer_options.dart';
export 'src/wfs_layer_widget.dart';