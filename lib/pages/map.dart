import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/widgets/chat_bot_widget.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;
import 'package:pulchowkx_app/widgets/location_details_sheet.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  bool _isSatellite = false; // Default to map view
  List<Map<String, dynamic>> _locations = [];
  final Map<String, Uint8List> _iconCache = {}; // Cache for icon images
  final Set<String> _failedIcons = {}; // Track icons that failed to load

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  // Navigation state
  bool _isNavigating = false;
  Map<String, dynamic>? _startPoint; // {coords: [lng, lat], name: String}
  Map<String, dynamic>? _endPoint;
  List<LatLng>? _routeCoordinates;
  String _routeDistance = '';
  String _routeDuration = '';
  bool _isCalculatingRoute = false;
  // ignore: unused_field
  LatLng? _userLocation;
  bool _isLocating = false;
  bool _isNavigationPanelExpanded = true;
  bool _isTogglingMapType = false; // Guard for map type toggle

  // Pulchowk Campus center and bounds
  static const LatLng _pulchowkCenter = LatLng(
    27.68222689200303,
    85.32121137093469,
  );
  static const double _initialZoom = 17.0;

  // Camera bounds to restrict map view to campus area (tightened to actual campus extent)
  static final LatLngBounds _campusBounds = LatLngBounds(
    southwest: const LatLng(27.6792, 85.3165),
    northeast: const LatLng(27.6848, 85.3262),
  );

  // Satellite style (ArcGIS World Imagery)
  static const String _satelliteStyle = '''
{
  "version": 8,
  "glyphs": "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf",
  "sources": {
    "arcgis-world-imagery": {
      "type": "raster",
      "tiles": [
        "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      ],
      "tileSize": 256
    }
  },
  "layers": [
    {
      "id": "satellite",
      "type": "raster",
      "source": "arcgis-world-imagery",
      "minzoom": 0,
      "maxzoom": 22
    }
  ]
}
''';

  // Map style (CartoDB Voyager - street map)
  static const String _mapStyle =
      'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';

  String get _currentStyle => _isSatellite ? _satelliteStyle : _mapStyle;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Load GeoJSON data from assets
  Future<void> _loadGeoJSON() async {
    try {
      // Only parse GeoJSON if not already loaded
      if (_locations.isEmpty) {
        final String jsonString = await rootBundle.loadString(
          'assets/geojson/pulchowk.json',
        );
        final Map<String, dynamic> geojson = json.decode(jsonString);
        final List<dynamic> features = geojson['features'] ?? [];

        // Extract location data (skip first feature which is boundary mask)
        final locations = <Map<String, dynamic>>[];
        for (int i = 1; i < features.length; i++) {
          final feature = features[i];
          final props = feature['properties'] ?? {};
          final geometry = feature['geometry'] ?? {};

          if (props['description'] != null) {
            // Calculate center for polygons, use coordinates for points
            List<double> coords;
            if (geometry['type'] == 'Point') {
              coords = List<double>.from(geometry['coordinates']);
            } else if (geometry['type'] == 'Polygon') {
              coords = _getPolygonCentroid(geometry['coordinates'][0]);
            } else {
              continue;
            }

            locations.add({
              'title': props['description'] ?? props['title'] ?? 'Unknown',
              'description': props['about'] ?? '',
              'images': props['image'],
              'coordinates': coords,
              'icon': _getIconForDescription(props['description'] ?? ''),
            });
          }
        }

        if (mounted) {
          setState(() {
            _locations = locations;
          });
        }
      }

      // Always re-add campus mask and markers when style loads
      // (MapLibre clears all images/layers when style changes)
      if (_mapController != null && _isStyleLoaded) {
        debugPrint(
          '🎯 Re-adding campus mask and markers (isSatellite: $_isSatellite)',
        );
        // Add layers in parallel where possible, but mask must be below markers
        await _addCampusMask();
        // Small delay to ensure mask layer is fully added before adding markers on top
        // await Future.delayed(const Duration(milliseconds: 50)); // Reduced delay
        await _addMarkersToMap();
        debugPrint('✅ Finished re-adding markers');
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
    }
  }

  List<double> _getPolygonCentroid(List<dynamic> coordinates) {
    double sumLng = 0;
    double sumLat = 0;
    for (var coord in coordinates) {
      sumLng += coord[0];
      sumLat += coord[1];
    }
    return [sumLng / coordinates.length, sumLat / coordinates.length];
  }

  /// Get icon type based on description (matching web logic)
  String _getIconForDescription(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('bank') || d.contains('atm')) return 'bank';
    if (d.contains('mess') || d.contains('canteen') || d.contains('food')) {
      return 'food';
    }
    if (d.contains('library')) return 'library';
    if (d.contains('department')) return 'department';
    if (d.contains('mandir')) return 'temple';
    if (d.contains('gym') || d.contains('sport')) return 'gym';
    if (d.contains('football')) return 'football';
    if (d.contains('cricket')) return 'cricket';
    if (d.contains('basketball') || d.contains('volleyball')) return 'sports';
    if (d.contains('hostel')) return 'hostel';
    if (d.contains('lab')) return 'lab';
    if (d.contains('helicopter')) return 'helipad';
    if (d.contains('parking')) return 'parking';
    if (d.contains('electrical club')) return 'electrical';
    if (d.contains('music club')) return 'music';
    if (d.contains('center for energy studies')) return 'energy';
    if (d.contains('the helm of ioe pulchowk')) return 'helm';
    if (d.contains('pi chautari') ||
        d.contains('park') ||
        d.contains('garden')) {
      return 'garden';
    }
    if (d.contains('store') || d.contains('bookshop')) return 'store';
    if (d.contains('quarter')) return 'quarter';
    if (d.contains('robotics club')) return 'robotics';
    if (d.contains('clinic') || d.contains('health')) return 'clinic';
    if (d.contains('badminton')) return 'badminton';
    if (d.contains('entrance')) return 'entrance';
    if (d.contains('office') ||
        d.contains('ntbns') ||
        d.contains('seds') ||
        d.contains('cids')) {
      return 'office';
    }
    if (d.contains('building')) return 'building';
    if (d.contains('block') || d.contains('embark')) return 'block';
    if (d.contains('cave')) return 'cave';
    if (d.contains('fountain')) return 'fountain';
    if (d.contains('water vending machine') || d.contains('water')) {
      return 'water';
    }
    if (d.contains('workshop')) return 'workshop';
    if (d.contains('toilet') || d.contains('washroom')) return 'toilet';
    if (d.contains('bridge')) return 'bridge';
    return 'marker';
  }

  /// Get marker color based on icon type
  Color _getMarkerColor(String iconType) {
    switch (iconType) {
      case 'food':
        return Colors.orange;
      case 'library':
        return Colors.purple;
      case 'department':
        return Colors.blue;
      case 'hostel':
        return Colors.teal;
      case 'lab':
        return Colors.indigo;
      case 'office':
        return Colors.blueGrey;
      case 'gym':
      case 'football':
      case 'cricket':
      case 'sports':
      case 'badminton':
        return Colors.green;
      case 'parking':
        return Colors.grey;
      case 'clinic':
        return Colors.red;
      case 'garden':
        return Colors.lightGreen;
      case 'store':
        return Colors.amber;
      case 'bank':
        return Colors.blue;
      case 'temple':
        return Colors.deepOrange;
      case 'water':
      case 'fountain':
        return Colors.cyan;
      case 'toilet':
        return Colors.brown;
      case 'entrance':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  /// Add campus boundary mask as a fill layer
  Future<void> _addCampusMask() async {
    if (_mapController == null) return;

    try {
      // Load full pulchowk.json to get the proper polygon-with-hole mask
      final String jsonString = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final Map<String, dynamic> geojson = json.decode(jsonString);

      // Check if mask source/layer already exists and remove if so
      try {
        await _mapController!.removeLayer('campus-mask');
        await _mapController!.removeSource('campus-mask-source');
      } catch (e) {
        // Ignore if not present
      }

      // Add GeoJSON source with full feature collection
      await _mapController!.addGeoJsonSource('campus-mask-source', geojson);

      // Add fill layer with filter for only the mask feature (has no description)
      // The first feature is a polygon-with-hole: outer ring covers world, inner ring is campus
      // For satellite view, add the mask right above the satellite layer
      await _mapController!.addFillLayer(
        'campus-mask-source',
        'campus-mask',
        FillLayerProperties(
          fillColor: '#FFFFFF',
          fillOpacity: 0.98,
          fillOutlineColor: '#4A5568',
        ),
        filter: [
          'all',
          [
            '==',
            ['geometry-type'],
            'Polygon',
          ],
          [
            '!',
            ['has', 'description'],
          ],
        ],
      );

      debugPrint('Campus mask added successfully');
    } catch (e) {
      debugPrint('Error adding campus mask: $e');
    }
  }

  /// Create a fallback colored circle marker when icon fails to load
  Future<Uint8List> _createFallbackMarker(String iconType) async {
    final color = _getMarkerColor(iconType);
    final size = 280; // Increased from 40

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw filled circle
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, fillPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Load icon images for markers (parallel loading with fallback)
  Future<void> _loadIconImages() async {
    if (_mapController == null) return;

    // Map of icon types to their network image URLs (matching website)
    final iconUrls = {
      'bank': 'https://cdn-icons-png.flaticon.com/512/6395/6395444.png',
      'food': 'https://cdn-icons-png.freepik.com/512/11167/11167112.png',
      'library': 'https://cdn-icons-png.freepik.com/512/7985/7985904.png',
      'department': 'https://cdn-icons-png.flaticon.com/512/7906/7906888.png',
      'temple': 'https://cdn-icons-png.flaticon.com/512/1183/1183391.png',
      'gym': 'https://cdn-icons-png.flaticon.com/512/11020/11020519.png',
      'football': 'https://cdn-icons-png.freepik.com/512/8893/8893610.png',
      'cricket': 'https://i.postimg.cc/cLb6QFC1/download.png',
      'sports': 'https://i.postimg.cc/mDW05pSw-/volleyball.png',
      'hostel': 'https://cdn-icons-png.flaticon.com/512/7804/7804352.png',
      'lab': 'https://cdn-icons-png.flaticon.com/256/12348/12348567.png',
      'helipad': 'https://cdn-icons-png.flaticon.com/512/5695/5695654.png',
      'parking':
          'https://cdn.iconscout.com/icon/premium/png-256-thumb/parking-place-icon-svg-download-png-897308.png',
      'electrical': 'https://cdn-icons-png.flaticon.com/512/9922/9922144.png',
      'music': 'https://cdn-icons-png.flaticon.com/512/5905/5905923.png',
      'energy': 'https://cdn-icons-png.flaticon.com/512/10053/10053795.png',
      'helm':
          'https://png.pngtree.com/png-vector/20221130/ourmid/pngtree-airport-location-pin-in-light-blue-color-png-image_6485369.png',
      'garden': 'https://cdn-icons-png.flaticon.com/512/15359/15359437.png',
      'store': 'https://cdn-icons-png.flaticon.com/512/3448/3448673.png',
      'quarter': 'https://static.thenounproject.com/png/331579-200.png',
      'robotics': 'https://cdn-icons-png.flaticon.com/512/10681/10681183.png',
      'clinic': 'https://cdn-icons-png.flaticon.com/512/10714/10714002.png',
      'badminton': 'https://static.thenounproject.com/png/198230-200.png',
      'entrance': 'https://i.postimg.cc/jjLDcb6p/image-removebg-preview.png',
      'office': 'https://cdn-icons-png.flaticon.com/512/3846/3846807.png',
      'building': 'https://cdn-icons-png.flaticon.com/512/5193/5193760.png',
      'block': 'https://cdn-icons-png.flaticon.com/512/3311/3311565.png',
      'cave': 'https://cdn-icons-png.flaticon.com/512/210/210567.png',
      'fountain':
          'https://cdn.iconscout.com/icon/free/png-256/free-fountain-icon-svg-download-png-449881.png',
      'water':
          'https://static.vecteezy.com/system/resources/thumbnails/044/570/540/small_2x/single-water-drop-on-transparent-background-free-png.png',
      'workshop': 'https://cdn-icons-png.flaticon.com/512/10747/10747285.png',
      'toilet': 'https://cdn-icons-png.flaticon.com/512/5326/5326954.png',
      'bridge': 'https://cdn-icons-png.flaticon.com/512/2917/2917995.png',
      'marker':
          'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-blue.png',
    };

    debugPrint('Starting to load ${iconUrls.length} icons in parallel...');
    final startTime = DateTime.now();

    // Load all icons in parallel using Future.wait
    final results = await Future.wait(
      iconUrls.entries.map((entry) async {
        try {
          final iconName = '${entry.key}-icon';

          // Check if already in cache
          if (_iconCache.containsKey(entry.key)) {
            await _mapController!.addImage(iconName, _iconCache[entry.key]!);
            return {'status': 'cached', 'icon': entry.key};
          }

          // Download icon with timeout
          final response = await http
              .get(Uri.parse(entry.value))
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            _iconCache[entry.key] = bytes;
            await _mapController!.addImage(iconName, bytes);
            return {'status': 'loaded', 'icon': entry.key};
          } else {
            throw Exception('HTTP ${response.statusCode}');
          }
        } catch (e) {
          // Create fallback marker on error
          debugPrint('⚠️  Failed to load ${entry.key}, using fallback: $e');
          _failedIcons.add(entry.key);

          try {
            final fallbackBytes = await _createFallbackMarker(entry.key);
            final iconName = '${entry.key}-icon';
            await _mapController!.addImage(iconName, fallbackBytes);
            return {'status': 'fallback', 'icon': entry.key};
          } catch (fallbackError) {
            debugPrint('✗ Fallback failed for ${entry.key}: $fallbackError');
            return {'status': 'failed', 'icon': entry.key};
          }
        }
      }),
    );

    // Count results
    final loadedCount = results.where((r) => r['status'] == 'loaded').length;
    final cachedCount = results.where((r) => r['status'] == 'cached').length;
    final fallbackCount = results
        .where((r) => r['status'] == 'fallback')
        .length;
    final failedCount = results.where((r) => r['status'] == 'failed').length;

    final duration = DateTime.now().difference(startTime);
    debugPrint(
      '✓ Icons loaded in ${duration.inMilliseconds}ms: $loadedCount new, $cachedCount cached, $fallbackCount fallback, $failedCount failed',
    );
  }

  /// Add markers to the map using symbol layer with icons
  Future<void> _addMarkersToMap() async {
    if (_mapController == null || _locations.isEmpty) return;

    try {
      debugPrint('📍 Adding markers for ${_locations.length} locations...');

      // Check if markers already exist (to avoid duplicate source error)
      // If they exist, remove them first before re-adding
      try {
        // Try to remove existing source and layer if they exist
        await _mapController!.removeLayer('markers-layer');
        await _mapController!.removeSource('markers-source');
        debugPrint('🗑️  Removed existing markers layer and source');
      } catch (e) {
        // If removal fails, it means they don't exist yet (first time)
        debugPrint('ℹ️  No existing markers to remove (first time): $e');
      }

      // Load icon images first
      debugPrint('🖼️  Loading icon images...');
      await _loadIconImages();

      // Create GeoJSON for all markers
      final features = _locations.map((location) {
        final coords = location['coordinates'] as List<double>;
        final iconType = location['icon'] as String;

        return {
          'type': 'Feature',
          'properties': {'icon': '$iconType-icon', 'title': location['title']},
          'geometry': {'type': 'Point', 'coordinates': coords},
        };
      }).toList();

      final geojson = {'type': 'FeatureCollection', 'features': features};

      // Add GeoJSON source for markers
      await _mapController!.addGeoJsonSource('markers-source', geojson);

      // Add symbol layer for markers with labels (above the mask)
      await _mapController!.addSymbolLayer(
        'markers-source',
        'markers-layer',
        SymbolLayerProperties(
          // Icon settings
          iconImage: ['get', 'icon'],
          iconSize: [
            'match',
            ['get', 'icon'],
            'cricket-icon', 0.1,
            'sports-icon', 0.11,
            'marker-icon', 0.08,
            'parking-icon', 0.3,
            'badminton-icon', 0.3,
            'lab-icon', 0.24,
            'quarter-icon', 0.3,
            'fountain-icon', 0.3,
            0.12, // default size
          ],
          iconAnchor: 'bottom', // Anchor icons at bottom so tap area aligns
          iconAllowOverlap: false, // Hide icons when overlapping
          iconOptional: true, // Make icon optional when it would overlap
          // Text label settings
          textField: ['get', 'title'],
          textSize: 10,
          textAnchor: 'top',
          textOffset: [0, 0.75],
          textAllowOverlap: false, // Prevent label collision
          textOptional: true, // Hide text if it collides
          textColor: _isSatellite ? '#FFFFFF' : '#000000',
          textHaloColor: _isSatellite ? '#000000' : '#FFFFFF',
          textHaloWidth: 1.5,
          textMaxWidth: 8,
        ),
      );

      debugPrint('✓ Successfully added ${_locations.length} icon markers');
    } catch (e) {
      debugPrint('✗ Error adding markers: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    debugPrint('🗺️  onStyleLoaded called - isSatellite: $_isSatellite');
    setState(() {
      _isStyleLoaded = true;
      _isTogglingMapType = false;
    });
    _loadGeoJSON();
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    if (_mapController == null) return;

    // Unfocus search bar and hide suggestions on map tap
    if (_searchFocusNode.hasFocus || _showSuggestions) {
      FocusScope.of(context).unfocus();
      setState(() {
        _showSuggestions = false;
      });
    }

    try {
      // Create a generous rect for hit detection to make it easier to tap icons
      // Icons typically have iconAnchor: 'bottom' and labels have textAnchor: 'top'
      final tapRect = Rect.fromLTRB(
        point.x - 60, // left
        point.y - 80, // top
        point.x + 60, // right
        point.y + 40, // bottom (for labels below)
      );

      // Query rendered features in the rect area - only the markers-layer
      final features = await _mapController!.queryRenderedFeaturesInRect(
        tapRect,
        ['markers-layer'],
        null,
      );

      if (features.isNotEmpty) {
        final feature = features.first;

        // Extract title from the feature
        String? title;

        if (feature is Map) {
          // Try nested properties first (GeoJSON format)
          final props = feature['properties'];
          if (props is Map) {
            title = props['title']?.toString();
          }
          // Fall back to root level
          title ??= feature['title']?.toString();
        }

        if (title != null && title.isNotEmpty) {
          final location = _locations.firstWhere(
            (loc) => loc['title'] == title,
            orElse: () => <String, dynamic>{},
          );

          if (location.isNotEmpty) {
            _showLocationDetails(location);
            return;
          }
        }
      }

      // No popup shown if the tap was not on an icon or label
      debugPrint('📍 No marker found at tap point - popup not shown');
    } catch (e) {
      debugPrint('Error querying features: $e');
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LocationDetailsSheet(
        title: location['title'] ?? 'Unknown Location',
        description: location['description'],
        images: location['images'],
        onNavigate: () {
          Navigator.pop(context); // Close the sheet
          _startNavigation(location); // Start navigation
        },
      ),
    );
  }

  /// Fly to a location on the map
  void _flyToLocation(Map<String, dynamic> location, {bool showPopup = true}) {
    if (_mapController == null) return;

    final coords = location['coordinates'] as List<double>;

    // Use addPostFrameCallback to avoid setState during build phase or concurrent focus changes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Unfocus first within the callback
      _searchFocusNode.unfocus();

      setState(() {
        _showSuggestions = false;
        _searchQuery = '';
        _searchController.clear(); // Clear the search box
      });

      // Wait for keyboard to dismiss before animating
      await Future.delayed(const Duration(milliseconds: 300));

      // Now animate camera after UI has settled
      if (_mapController != null && mounted) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(coords[1], coords[0]), 19),
        );
      }

      // Show location details after animation completes (only if requested)
      if (showPopup && mounted) {
        _showLocationDetails(location);
      }
    });
  }

  /// Get filtered suggestions based on search query
  List<Map<String, dynamic>> get _filteredSuggestions {
    if (_searchQuery.trim().isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return _locations
        .where((loc) => (loc['title'] as String).toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  /// Handle locations returned from chatbot
  void _handleChatBotLocations(List<ChatBotLocation> locations, String action) {
    if (locations.isEmpty || _mapController == null) return;

    debugPrint('Chatbot action: $action at ${locations.length} locations');

    // Use addPostFrameCallback to avoid setState during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (action == 'show_route' && locations.length >= 2) {
        // Find start and end locations based on role
        ChatBotLocation? startLoc;
        ChatBotLocation? endLoc;

        for (final loc in locations) {
          if (loc.role == 'start') {
            startLoc = loc;
          } else if (loc.role == 'end' || loc.role == 'destination') {
            endLoc = loc;
          }
        }

        // If roles not specified, use first as start and last as end
        startLoc ??= locations.first;
        endLoc ??= locations.last;

        // Start navigation mode with the route
        setState(() {
          _isNavigating = true;
          _isNavigationPanelExpanded = true;
          _startPoint = {
            'coords': [startLoc!.lng, startLoc.lat],
            'name': startLoc.buildingName,
          };
          _endPoint = {
            'coords': [endLoc!.lng, endLoc.lat],
            'name': endLoc.buildingName,
          };
          _routeCoordinates = null;
          _routeDistance = '';
          _routeDuration = '';
        });

        // Get directions and draw route
        _getDirections();

        // Zoom to show both points
        final bounds = LatLngBounds(
          southwest: LatLng(
            min(startLoc.lat, endLoc.lat) - 0.001,
            min(startLoc.lng, endLoc.lng) - 0.001,
          ),
          northeast: LatLng(
            max(startLoc.lat, endLoc.lat) + 0.001,
            max(startLoc.lng, endLoc.lng) + 0.001,
          ),
        );
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50,
            top: 150,
            right: 50,
            bottom: 50,
          ),
        );
      } else {
        // For show_location or show_multiple_locations, just fly to first location
        final first = locations.first;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(first.lat, first.lng), 19),
        );
      }
    });
  }

  /// Check if a location is within campus bounds
  bool _isWithinCampus(LatLng location) {
    return location.latitude >= _campusBounds.southwest.latitude &&
        location.latitude <= _campusBounds.northeast.latitude &&
        location.longitude >= _campusBounds.southwest.longitude &&
        location.longitude <= _campusBounds.northeast.longitude;
  }

  /// Get current location and animate camera to it
  Future<void> _goToCurrentLocation() async {
    if (_mapController == null) return;
    // Prevent multiple concurrent location requests
    if (_isLocating) {
      debugPrint('📍 Already locating, ignoring request');
      return;
    }

    setState(() => _isLocating = true);

    try {
      // Check and request location permission
      var status = await Permission.location.status;

      if (status.isDenied) {
        status = await Permission.location.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission denied. Please enable it in settings.',
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission required'),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Check if location services are enabled
      final serviceStatus = await Permission.location.serviceStatus;
      if (!serviceStatus.isEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services'),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Use MapLibre's built-in location tracking with timeout
      // On first launch, GPS may need time to acquire a fix, so we retry
      LatLng? latLng;
      for (int attempt = 0; attempt < 2; attempt++) {
        latLng = await _mapController!.requestMyLocationLatLng().timeout(
          Duration(
            seconds: attempt == 0 ? 15 : 10,
          ), // Longer timeout for first attempt
          onTimeout: () => null,
        );
        if (latLng != null) break;
        if (attempt == 0) {
          debugPrint('📍 First location attempt failed, retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (latLng != null) {
        _userLocation = latLng;

        // Check if within campus bounds
        if (_isWithinCampus(latLng)) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 19));
        } else {
          // Show message if outside campus
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('You are outside the campus area'),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } else {
        // Location request returned null or timed out
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not determine your location. Please try again.',
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to get your location'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Start navigation mode with a destination
  void _startNavigation(Map<String, dynamic> destination) {
    // Show dialog to choose start point
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Choose Starting Point',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Navigate to: ${destination['title']}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // Use Current Location option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.my_location, color: Colors.blue[600]),
              ),
              title: const Text(
                'Use My Location',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Get directions from your current position'),
              onTap: () {
                Navigator.pop(context);
                _startNavigationWithLocation(destination);
              },
            ),
            const Divider(),
            // Choose from map option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.place, color: Colors.green[600]),
              ),
              title: const Text(
                'Choose Another Place',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Select a location from the map as start'),
              onTap: () {
                Navigator.pop(context);
                _showStartPointPicker(destination);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Start navigation using user's current location
  void _startNavigationWithLocation(Map<String, dynamic> destination) async {
    final coords = destination['coordinates'] as List<double>;

    setState(() {
      _isNavigating = true;
      _isNavigationPanelExpanded = true;
      _endPoint = {
        'coords': coords,
        'name': destination['title'] ?? 'Destination',
      };
      _startPoint = null;
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });

    // Try to get user location as start point
    try {
      final latLng = await _mapController?.requestMyLocationLatLng();
      if (latLng != null && _isWithinCampus(latLng)) {
        _userLocation = latLng;
        setState(() {
          _startPoint = {
            'coords': [latLng.longitude, latLng.latitude],
            'name': 'Your Location',
          };
        });
        _getDirections();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                latLng == null
                    ? 'Unable to get your location'
                    : 'You are outside the campus area',
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isNavigating = false);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to get your location'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isNavigating = false);
    }
  }

  /// Show picker to select start point from available locations
  void _showStartPointPicker(Map<String, dynamic> destination) async {
    final destTitle = destination['title']?.toString() ?? '';
    // Initial list of locations excluding the destination
    final allLocations = _locations
        .where((loc) => loc['title'] != destTitle)
        .toList();

    // Sort locations alphabetically
    allLocations.sort(
      (a, b) => (a['title'] as String).compareTo(b['title'] as String),
    );

    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Filter locations based on search query
          final query = searchController.text.toLowerCase();
          final filteredLocations = allLocations.where((loc) {
            final title = (loc['title'] as String).toLowerCase();
            return title.contains(query);
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search start location...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Location list
                  Expanded(
                    child: filteredLocations.isEmpty
                        ? Center(
                            child: Text(
                              'No locations found',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filteredLocations.length,
                            itemBuilder: (context, index) {
                              final location = filteredLocations[index];
                              final iconType =
                                  location['icon'] as String? ?? 'marker';
                              final color = _getMarkerColor(iconType);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withAlpha(50),
                                  child: Icon(
                                    Icons.place,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  location['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _startNavigationFromPlace(
                                    location,
                                    destination,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Dispose resources after sheet closes
    searchController.dispose();
  }

  /// Start navigation from a selected place
  void _startNavigationFromPlace(
    Map<String, dynamic> startLocation,
    Map<String, dynamic> destination,
  ) {
    final startCoords = startLocation['coordinates'] as List<double>;
    final endCoords = destination['coordinates'] as List<double>;

    setState(() {
      _isNavigating = true;
      _isNavigationPanelExpanded = true;
      _startPoint = {
        'coords': startCoords,
        'name': startLocation['title'] ?? 'Start',
      };
      _endPoint = {
        'coords': endCoords,
        'name': destination['title'] ?? 'Destination',
      };
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });

    _getDirections();
  }

  /// Calculate Haversine distance in meters
  double _getHaversineDistance(List<double> coord1, List<double> coord2) {
    const R = 6371e3; // Earth's radius in meters
    final phi1 = coord1[1] * pi / 180;
    final phi2 = coord2[1] * pi / 180;
    final deltaPhi = (coord2[1] - coord1[1]) * pi / 180;
    final deltaLambda = (coord2[0] - coord1[0]) * pi / 180;

    final a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  /// Get walking directions using OSRM
  Future<void> _getDirections() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() => _isCalculatingRoute = true);

    final startCoords = _startPoint!['coords'] as List<double>;
    final endCoords = _endPoint!['coords'] as List<double>;
    final straightDistance = _getHaversineDistance(startCoords, endCoords);

    // If very close, just show straight line
    if (straightDistance < 20) {
      _createStraightLineRoute(startCoords, endCoords, straightDistance);
      setState(() => _isCalculatingRoute = false);
      return;
    }

    final query =
        '${startCoords[0]},${startCoords[1]};${endCoords[0]},${endCoords[1]}';
    final url =
        'https://router.project-osrm.org/route/v1/foot/$query?overview=full&geometries=geojson&radiuses=200;200';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final coordinates = (geometry['coordinates'] as List)
              .map<LatLng>((c) => LatLng(c[1], c[0]))
              .toList();

          final distance = route['distance'] as num;

          // Check if route is too long (likely goes outside campus)
          if (distance > 2000 || distance > straightDistance * 3) {
            _createStraightLineRoute(startCoords, endCoords, straightDistance);
          } else {
            setState(() {
              _routeCoordinates = coordinates;
              _routeDistance = distance < 1000
                  ? '${distance.round()} m'
                  : '${(distance / 1000).toStringAsFixed(1)} km';
              final totalSeconds = distance / 1.2; // Walking speed
              _routeDuration = totalSeconds < 60
                  ? '${totalSeconds.round()} sec'
                  : '${(totalSeconds / 60).round()} min';
            });
            _drawRouteOnMap();
          }
        } else {
          _createStraightLineRoute(startCoords, endCoords, straightDistance);
        }
      } else {
        _createStraightLineRoute(startCoords, endCoords, straightDistance);
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
      _createStraightLineRoute(startCoords, endCoords, straightDistance);
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  /// Create a straight-line route as fallback
  void _createStraightLineRoute(
    List<double> start,
    List<double> end,
    double distance,
  ) {
    setState(() {
      _routeCoordinates = [LatLng(start[1], start[0]), LatLng(end[1], end[0])];
      _routeDistance = distance < 1000
          ? '${distance.round()} m'
          : '${(distance / 1000).toStringAsFixed(1)} km';
      final totalSeconds = distance / 1.2;
      _routeDuration = totalSeconds < 60
          ? '${totalSeconds.round()} sec'
          : '${(totalSeconds / 60).round()} min';
    });
    _drawRouteOnMap();
  }

  /// Draw route line on the map
  Future<void> _drawRouteOnMap() async {
    if (_mapController == null || _routeCoordinates == null) return;

    // Remove existing route if any
    try {
      await _mapController!.removeLayer('route-layer');
      await _mapController!.removeSource('route-source');
    } catch (e) {
      // Layer doesn't exist yet
    }

    // Create GeoJSON for route
    final routeGeoJSON = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': _routeCoordinates!
                .map((c) => [c.longitude, c.latitude])
                .toList(),
          },
        },
      ],
    };

    await _mapController!.addGeoJsonSource('route-source', routeGeoJSON);
    await _mapController!.addLineLayer(
      'route-source',
      'route-layer',
      LineLayerProperties(
        lineColor: '#2563eb',
        lineWidth: 5,
        lineOpacity: 0.8,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    // Fit camera to show full route
    if (_routeCoordinates!.length >= 2) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _routeCoordinates!.map((c) => c.latitude).reduce(min),
          _routeCoordinates!.map((c) => c.longitude).reduce(min),
        ),
        northeast: LatLng(
          _routeCoordinates!.map((c) => c.latitude).reduce(max),
          _routeCoordinates!.map((c) => c.longitude).reduce(max),
        ),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50,
          top: 150,
          right: 50,
          bottom: 100,
        ),
      );
    }
  }

  /// Exit navigation mode
  void _exitNavigation() async {
    // Remove route layer
    try {
      await _mapController?.removeLayer('route-layer');
      await _mapController?.removeSource('route-source');
    } catch (e) {
      // Ignore
    }

    setState(() {
      _isNavigating = false;
      _startPoint = null;
      _endPoint = null;
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });
  }

  /// Toggle between map and satellite view
  void _toggleMapType() {
    // Guard against rapid toggling and toggling while loading
    if (_isTogglingMapType || !_isStyleLoaded) {
      debugPrint('🚫 Toggle ignored - map is loading or already toggling');
      return;
    }

    debugPrint(
      '🔄 Toggling map type from ${_isSatellite ? "satellite" : "map"} to ${!_isSatellite ? "satellite" : "map"}',
    );
    setState(() {
      _isTogglingMapType = true;
      _isSatellite = !_isSatellite;
      _isStyleLoaded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: const CustomAppBar(currentPage: AppPage.map),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // MapLibre Map
            MapLibreMap(
              key: const ValueKey('map_libre_main'),
              styleString: _currentStyle,
              initialCameraPosition: const CameraPosition(
                target: _pulchowkCenter,
                zoom: _initialZoom,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onMapClick: _onMapClick,
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              myLocationRenderMode: MyLocationRenderMode.compass,
              trackCameraPosition: true,
              compassEnabled: true,
              cameraTargetBounds: CameraTargetBounds(_campusBounds),
              minMaxZoomPreference: MinMaxZoomPreference(
                16,
                _isSatellite
                    ? 18.45
                    : 20, // Restrict satellite to 18.5, map can go to 20
              ),
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: true,
              doubleClickZoomEnabled: true,
              attributionButtonMargins: const Point(8, 92),
            ),

            // Loading indicator
            if (!_isStyleLoaded)
              Container(
                color: AppColors.background,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BoxShimmer(width: 40, height: 40, borderRadius: 20),
                      SizedBox(height: 16),
                      Text(
                        'Loading map...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Search bar
            // Map/Satellite Toggle
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      Theme.of(
                        context,
                      ).cardTheme.color?.withValues(alpha: 0.95) ??
                      Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapTypeButton(
                      label: 'Map',
                      isActive: !_isSatellite,
                      onTap: () {
                        if (_isSatellite) {
                          HapticFeedback.selectionClick();
                          _toggleMapType();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildMapTypeButton(
                      label: 'Satellite',
                      isActive: _isSatellite,
                      onTap: () {
                        if (!_isSatellite) {
                          HapticFeedback.selectionClick();
                          _toggleMapType();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Current Location Button
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (!_isLocating) {
                    _goToCurrentLocation();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(
                          context,
                        ).cardTheme.color?.withValues(alpha: 0.95) ??
                        Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLocating
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                ),
              ),
            ),

            // Navigation Panel (when navigating)
            if (_isNavigating)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(
                          context,
                        ).cardTheme.color?.withValues(alpha: 0.98) ??
                        Colors.white.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with back button and collapsible toggle
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _exitNavigation();
                            },
                            icon: const Icon(Icons.close_rounded),
                            color: Theme.of(context).colorScheme.onSurface,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Close Navigation',
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Directions',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _isNavigationPanelExpanded =
                                    !_isNavigationPanelExpanded,
                              );
                            },
                            icon: Icon(
                              _isNavigationPanelExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (_isNavigationPanelExpanded) ...[
                        const SizedBox(height: 16),
                        // Start point
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _startPoint?['name'] ??
                                    'Getting your location...',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _startPoint != null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            if (_isNavigating)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                onPressed: () => _exitNavigation(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Dotted line connector
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Column(
                            children: List.generate(
                              3,
                              (i) => Container(
                                width: 2,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 1),
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // End point
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _endPoint?['name'] ?? 'Destination',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_isNavigating)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                onPressed: () => _exitNavigation(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),

                        // Route info
                        if (_routeDistance.isNotEmpty &&
                            _routeDuration.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_routeDuration • $_routeDistance',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Loading indicator
                        if (_isCalculatingRoute)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Calculating route...',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

            // Chatbot Widget Overlay
            ChatBotWidget(onLocationsReturned: _handleChatBotLocations),

            // Search bar (Moved to bottom of stack to appear on top)
            if (!_isNavigating)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: TapRegion(
                  onTapOutside: (event) {
                    if (_searchFocusNode.hasFocus || _showSuggestions) {
                      _searchFocusNode.unfocus();
                      setState(() {
                        _showSuggestions = false;
                      });
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).cardTheme.color?.withValues(alpha: 0.95) ??
                              Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: Theme.of(context).textTheme.bodyLarge,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _showSuggestions = value.isNotEmpty;
                            });
                          },
                          onTap: () {
                            setState(() {
                              _showSuggestions = _searchQuery.isNotEmpty;
                            });
                          },
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            if (value.isEmpty) return;

                            setState(() {
                              _searchQuery = value;
                              _showSuggestions = value.isNotEmpty;
                            });

                            if (_filteredSuggestions.isNotEmpty) {
                              _flyToLocation(_filteredSuggestions.first);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search classrooms, departments...',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _showSuggestions = false;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      // Suggestions dropdown
                      if (_showSuggestions && _filteredSuggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).cardTheme.color?.withValues(alpha: 0.98) ??
                                  Colors.white.withValues(alpha: 0.98),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _filteredSuggestions.map((
                                    location,
                                  ) {
                                    final iconType = location['icon'] as String;
                                    final color = _getMarkerColor(iconType);
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: color,
                                        ),
                                      ),
                                      title: Text(
                                        location['title'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      subtitle: Text(
                                        'Pulchowk Campus',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _flyToLocation(location);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // No results message
                      if (_showSuggestions &&
                          _searchQuery.isNotEmpty &&
                          _filteredSuggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).cardTheme.color?.withValues(alpha: 0.98) ??
                                  Colors.white.withValues(alpha: 0.98),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No locations found',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try a different search term',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
