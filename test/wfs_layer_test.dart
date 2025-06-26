import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfs_layer/wfs_layer.dart';

void main() {
  test('WfsLayerOptions initialization', () {
    final options = WfsLayerOptions(
      url: 'https://example.com/wfs',
      typeName: 'roads',
      useClustering: true,
      markerColor: Colors.green,
      version: '1.0.0',
    );
    expect(options.url, 'https://example.com/wfs');
    expect(options.typeName, 'roads');
    expect(options.useClustering, true);
    expect(options.markerColor, Colors.green);
    expect(options.version, '1.0.0');
  });

  // Add mock tests for parsing when integrating with a mock HTTP response
}