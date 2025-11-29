import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wfs_layer/wfs_layer.dart';

void main()  {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //TODO :

  @override
  Widget build(BuildContext context) {
    final mapController = MapController();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('WFS Layer Example')),
        body: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: LatLng(15.391, 74.122), // Rennes coordinates
            // initialZoom: 12.0,// Example center
          ),
          children: [

            TileLayer(
              tileProvider: NetworkTileProvider(
                headers: {
                  'User-Agent': 'TreelovApp/1.0 (https://yourapp.com)',
                },
              ),
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            WfsLayer(
              mapController: mapController,
              options: WfsLayerOptions(
                url: 'https://stable.demo.geonode.org/geoserver/geonode/wms',
                typeName: 'geonode:110kv_ponda_towers',
                // url: 'https://nashikgeoportal.com/nmscdcl/ows',
                // typeName: 'nmscdcl:individual_household_building_survey',
                version: '1.0.0',
                // customParams: {
                //   'maxFeatures': '50',
                // },
                useClustering: true,
                // Updated customMarkerBuilder signature (now includes properties)
                customMarkerBuilder: (context, point, properties) => const Icon(
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
          ],
        ),
      ),
    );
  }
}