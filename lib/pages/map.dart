import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  String? _styleString;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await rootBundle.loadString(
        'assets/style/pulchowk_style.json',
      );
      setState(() {
        _styleString = style;
      });
    } catch (e) {
      debugPrint("Failed to load map style: $e");
    }
  }

  Future<void> _onStyleLoaded() async {
    if (_controller == null) return;

    try {
      final pulchowkData = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final maskData = await rootBundle.loadString(
        'assets/geojson/pulchowk_mask.json',
      );

      await _controller!.addSource(
        "pulchowk",
        GeojsonSourceProperties(data: pulchowkData),
      );

      await _controller!.addSource(
        "mask",
        GeojsonSourceProperties(data: maskData),
      );

      await _controller!.addFillLayer(
        "mask",
        "mask-layer",
        const FillLayerProperties(fillColor: "#000000", fillOpacity: 0.6),
      );

      await _controller!.addFillLayer(
        "pulchowk",
        "pulchowk-fill",
        const FillLayerProperties(fillColor: "#4CAF50", fillOpacity: 0.25),
      );

      await _controller!.addLineLayer(
        "pulchowk",
        "pulchowk-outline",
        const LineLayerProperties(lineColor: "#2E7D32", lineWidth: 3.0),
      );
    } catch (e) {
      debugPrint("Error adding sources/layers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_styleString == null) {
      return Scaffold(
        appBar: const CustomAppBar(currentPage: AppPage.map),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.map),
      body: MapLibreMap(
        styleString: _styleString!,
        initialCameraPosition: const CameraPosition(
          target: LatLng(27.6816, 85.3180),
          zoom: 17.5,
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(16, 19.5),
        onMapCreated: (controller) {
          _controller = controller;
        },
        onStyleLoadedCallback: _onStyleLoaded,
      ),
    );
  }
}
