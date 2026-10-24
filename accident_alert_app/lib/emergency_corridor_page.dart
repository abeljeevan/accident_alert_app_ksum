import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'emergency_corridor_service.dart';
import 'hospital_service.dart';
import 'osrm_routing_service.dart';

class EmergencyCorridorPage extends StatefulWidget {
  const EmergencyCorridorPage({super.key, required this.latitude, required this.longitude, required this.isDarkMode});
  final double latitude, longitude;
  final bool isDarkMode;

  @override
  State<EmergencyCorridorPage> createState() => _EmergencyCorridorPageState();
}

class _EmergencyCorridorPageState extends State<EmergencyCorridorPage> {
  Map<String, dynamic> _dispatch = const {'simulated': true, 'message': 'Preparing incident…'};
  Map<String, dynamic>? _hospital;
  List<LatLng> _route = [];
  double? _distanceKm, _durationMin;
  Timer? _progressTimer;
  double _progress = 0;
  bool _pickedUp = false;

  LatLng get _incident => LatLng(widget.latitude, widget.longitude);
  bool get _simulated => _dispatch['simulated'] != false;

  @override
  void initState() {
    super.initState();
    _prepareCorridor();
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _route.isEmpty) return;
      setState(() {
        if (!_pickedUp) {
          _progress += .025;
          if (_progress >= .5) _pickedUp = true;
        } else {
          _progress = (_progress + .025).clamp(.5, .98).toDouble();
        }
      });
    });
  }

  Future<void> _prepareCorridor() async {
    final result = await EmergencyCorridorService.createIncident(
      latitude: widget.latitude,
      longitude: widget.longitude,
      occurredAt: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _dispatch = result);

    try {
      final hospitals = await HospitalService.fetchNearbyHospitals(widget.latitude, widget.longitude, radius: 15000);
      hospitals.sort((a, b) => Geolocator.distanceBetween(widget.latitude, widget.longitude, (a['lat'] as num).toDouble(), (a['lon'] as num).toDouble()).compareTo(Geolocator.distanceBetween(widget.latitude, widget.longitude, (b['lat'] as num).toDouble(), (b['lon'] as num).toDouble())));
      if (!mounted || hospitals.isEmpty) return;
      final selected = hospitals.first;
      final hospitalPoint = LatLng((selected['lat'] as num).toDouble(), (selected['lon'] as num).toDouble());
      setState(() => _hospital = selected);
      final route = await OSRMRoutingService.calculateRoute(
        startLat: widget.latitude,
        startLon: widget.longitude,
        endLat: hospitalPoint.latitude,
        endLon: hospitalPoint.longitude,
        timeoutPerEndpoint: const Duration(seconds: 8),
      );
      if (!mounted || route == null) return;
      setState(() {
        _route = (route['routePoints'] as List<LatLng>);
        _distanceKm = (route['distance'] as num).toDouble();
        _durationMin = (route['duration'] as num).toDouble();
      });
    } catch (_) {
      // Keep the incident dashboard visible when map services are unavailable.
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalPoint = _hospital == null ? null : LatLng((_hospital!['lat'] as num).toDouble(), (_hospital!['lon'] as num).toDouble());
    final ambulancePoint = _route.isEmpty ? _incident : _route[(((_route.length - 1) * _progress).round().clamp(0, _route.length - 1)).toInt()];
    final ambulance = (_dispatch['ambulance_name'] ?? _dispatch['ambulance_id'] ?? 'Ambulance A-01').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Corridor'), actions: [IconButton(tooltip: 'Refresh corridor', onPressed: _prepareCorridor, icon: const Icon(Icons.refresh_rounded))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.warning_rounded, color: Color(0xFFFF3347)), const SizedBox(width: 9), const Expanded(child: Text('SOS incident dashboard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), _StatusPill(label: _simulated ? 'SIMULATED' : 'DISPATCHED', color: _simulated ? Colors.orange : Colors.green)]),
          const SizedBox(height: 8), Text('Location: ${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}'),
          const SizedBox(height: 5), Text((_dispatch['message'] ?? (_simulated ? 'Ambulance assignment and tracking are simulated.' : 'Dispatch received from backend.')).toString(), style: Theme.of(context).textTheme.bodySmall),
        ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.local_shipping_rounded, color: Color(0xFFFF3347)), const SizedBox(width: 9), Expanded(child: Text(ambulance, style: const TextStyle(fontWeight: FontWeight.w800))), Text(_pickedUp ? 'Picked up' : 'En route', style: const TextStyle(color: Color(0xFF2588F5), fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10), LinearProgressIndicator(value: _route.isEmpty ? null : _progress, color: const Color(0xFFFF3347), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest),
          const SizedBox(height: 8), Text(_durationMin == null ? 'ETA calculating from OSRM…' : '${OSRMRoutingService.formatDuration(_durationMin! * (1 - _progress))} ETA • ${OSRMRoutingService.formatDistance((_distanceKm ?? 0) * (1 - _progress))} remaining'),
          if (_simulated) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Ambulance movement and route progress are simulated.', style: TextStyle(fontSize: 12, color: Colors.orange))),
        ]))),
        const SizedBox(height: 10),
        SizedBox(height: 310, child: Card(clipBehavior: Clip.antiAlias, child: FlutterMap(options: MapOptions(initialCenter: _incident, initialZoom: 13), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.accident_alert_app'),
          if (_route.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _route, strokeWidth: 5, color: const Color(0xFFFF3347))]),
          MarkerLayer(markers: [Marker(point: _incident, width: 42, height: 42, child: const Icon(Icons.warning_rounded, color: Color(0xFFFF3347), size: 34)), Marker(point: ambulancePoint, width: 44, height: 44, child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2588F5), size: 36)), if (hospitalPoint != null) Marker(point: hospitalPoint, width: 42, height: 42, child: const Icon(Icons.local_hospital_rounded, color: Colors.green, size: 34))]),
        ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Corridor intersections', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 5), const Text('Signal priority is simulated for this demo. No traffic signals are controlled.', style: TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.traffic_rounded, color: Color(0xFF2588F5)), const SizedBox(width: 10), Expanded(child: Text('Intersection ${i + 1}')), const _StatusPill(label: 'Priority simulated', color: Colors.orange)])),
        ]))),
        Card(child: ListTile(leading: const Icon(Icons.local_hospital_rounded, color: Colors.green), title: Text(_hospital?['name']?.toString() ?? 'Nearby hospital not available'), subtitle: Text(_durationMin == null ? 'Hospital route unavailable; retry when online.' : 'Hospital route: ${OSRMRoutingService.formatDistance(_distanceKm ?? 0)} • ${OSRMRoutingService.formatDuration(_durationMin!)} ETA'), trailing: const Icon(Icons.route_rounded))),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)));
}
