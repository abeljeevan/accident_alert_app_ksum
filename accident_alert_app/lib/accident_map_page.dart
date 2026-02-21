import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'osrm_routing_service.dart';

class AccidentMapPage extends StatefulWidget {
  final double accidentLat;
  final double accidentLon;
  final String? hospitalName;
  final double? hospitalLat;
  final double? hospitalLon;
  final String address;
  final String severity;
  final bool isDarkMode;

  const AccidentMapPage({
    super.key,
    required this.accidentLat,
    required this.accidentLon,
    this.hospitalName,
    this.hospitalLat,
    this.hospitalLon,
    required this.address,
    required this.severity,
    required this.isDarkMode,
  });

  @override
  State<AccidentMapPage> createState() => _AccidentMapPageState();
}

class _AccidentMapPageState extends State<AccidentMapPage> {
  List<LatLng> routePoints = [];
  double? routeDistance;
  double? routeDuration;
  bool isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    if (widget.hospitalLat != null && widget.hospitalLon != null) {
      _calculateRoute();
    }
  }

  Future<void> _calculateRoute() async {
    setState(() {
      isLoadingRoute = true;
    });

    final route = await OSRMRoutingService.calculateRoute(
      startLat: widget.accidentLat,
      startLon: widget.accidentLon,
      endLat: widget.hospitalLat!,
      endLon: widget.hospitalLon!,
    );

    if (route != null && mounted) {
      setState(() {
        routePoints = route['routePoints'];
        routeDistance = route['distance'];
        routeDuration = route['duration'];
        isLoadingRoute = false;
      });
    } else {
      setState(() {
        isLoadingRoute = false;
      });
    }
  }

  Color _getSeverityColor() {
    switch (widget.severity) {
      case 'Critical':
        return Colors.red.shade700;
      case 'Severe':
        return Colors.red.shade500;
      case 'Moderate':
        return Colors.orange;
      case 'Minor':
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accidentPoint = LatLng(widget.accidentLat, widget.accidentLon);
    final hospitalPoint = widget.hospitalLat != null && widget.hospitalLon != null
        ? LatLng(widget.hospitalLat!, widget.hospitalLon!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accident Location Map'),
        centerTitle: true,
        backgroundColor: widget.isDarkMode ? Colors.black : null,
      ),
      body: Column(
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.severity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.hospitalName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        size: 16,
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.hospitalName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (routeDistance != null && routeDuration != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${OSRMRoutingService.formatDistance(routeDistance!)} • ${OSRMRoutingService.formatDuration(routeDuration!)} ETA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ],
                if (isLoadingRoute)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Calculating route...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: accidentPoint,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.accident_alert_app',
                ),
                // Route polyline
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Accident marker
                    Marker(
                      point: accidentPoint,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        color: _getSeverityColor(),
                        size: 40,
                      ),
                    ),
                    // Hospital marker
                    if (hospitalPoint != null)
                      Marker(
                        point: hospitalPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            child: Row(
              children: [
                if (hospitalPoint != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Open in OSM'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final url = OSRMRoutingService.generateOSMRouteLink(
                          startLat: widget.accidentLat,
                          startLon: widget.accidentLon,
                          endLat: widget.hospitalLat!,
                          endLon: widget.hospitalLon!,
                        );
                        // You can use url_launcher package to open this
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('OSM Route: $url')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Location'),
                    onPressed: () {
                      final maps = 'https://maps.google.com/?q=${widget.accidentLat},${widget.accidentLon}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Location: $maps')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
