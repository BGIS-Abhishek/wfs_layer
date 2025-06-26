import 'package:flutter/material.dart';
import 'package:wfs_layer/wfs_layer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('WFS Layer Example')),
        body: WfsLayer(
          options: WfsLayerOptions(
            url: 'http://10.202.100.7:9005/geoserver/nmscdcl/ows',
            typeName: 'nmscdcl:individual_household_building_survey',
            version: '1.0.0',
            customParams: {
              'maxFeatures': '50',
            },
            useClustering: true,
            customMarkerBuilder: (context, point) => const Icon(
              Icons.camera_alt,
              color: Colors.red,
              size: 30,
            ),
            markerColor: Colors.red,
            markerSize: 30.0,
            polylineColor: Colors.orange,
            polylineWidth: 3.0,
            polygonFillColor: Colors.yellow,
            polygonBorderColor: Colors.black,
            polygonBorderWidth: 3.0,
            onMarkerTap: (properties, position) {
              if (properties.isNotEmpty) {
                debugPrint(properties.toString());
              } else {
                debugPrint('No attributes available for this marker');
              }
            },
          ),
        ),
      ),
    );
  }
}