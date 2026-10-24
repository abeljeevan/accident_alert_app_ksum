import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'accident_map_page.dart';
import 'emergency_corridor_service.dart';
import 'hospital_service.dart';
import 'osrm_routing_service.dart';

const _coral = Color(0xFFFF263F);
const _navy = Color(0xFF10194D);
const _blue = Color(0xFF1687F8);
const _paleBlue = Color(0xFFEAF5FF);
const _green = Color(0xFF12A875);

class EmergencyCorridorPage extends StatefulWidget {
  const EmergencyCorridorPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isDarkMode,
    this.onBack,
  });
  final double latitude, longitude;
  final bool isDarkMode;
  final VoidCallback? onBack;

  @override
  State<EmergencyCorridorPage> createState() => _EmergencyCorridorPageState();
}

class _EmergencyCorridorPageState extends State<EmergencyCorridorPage> {
  final MapController _mapController = MapController();
  Map<String, dynamic> _dispatch = const {
    'simulated': true,
    'message': 'Preparing incident…',
  };
  Map<String, dynamic>? _hospital;
  List<LatLng> _route = [];
  double? _distanceKm, _durationMin;
  Timer? _progressTimer;
  double _progress = 0;
  bool _toAccident = true;
  bool _showSignals = true;
  bool _loading = true;

  LatLng get _incident => LatLng(widget.latitude, widget.longitude);
  bool get _simulated => _dispatch['simulated'] != false;
  bool get _dark => widget.isDarkMode;
  Color get _card => _dark ? const Color(0xFF14254A) : Colors.white;

  @override
  void initState() {
    super.initState();
    _prepareCorridor();
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _route.isEmpty) return;
      setState(() => _progress = (_progress + .01).clamp(0, .99).toDouble());
    });
  }

  Future<void> _prepareCorridor() async {
    setState(() => _loading = true);
    final result = await EmergencyCorridorService.createIncident(
      latitude: widget.latitude,
      longitude: widget.longitude,
      occurredAt: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _dispatch = result);
    try {
      final hospitals = await HospitalService.fetchNearbyHospitals(
        widget.latitude,
        widget.longitude,
        radius: 15000,
      );
      hospitals.sort(
        (a, b) =>
            Geolocator.distanceBetween(
              widget.latitude,
              widget.longitude,
              (a['lat'] as num).toDouble(),
              (a['lon'] as num).toDouble(),
            ).compareTo(
              Geolocator.distanceBetween(
                widget.latitude,
                widget.longitude,
                (b['lat'] as num).toDouble(),
                (b['lon'] as num).toDouble(),
              ),
            ),
      );
      if (!mounted || hospitals.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final selected = hospitals.first;
      final destination = LatLng(
        (selected['lat'] as num).toDouble(),
        (selected['lon'] as num).toDouble(),
      );
      setState(() => _hospital = selected);
      final route = await OSRMRoutingService.calculateRoute(
        startLat: widget.latitude,
        startLon: widget.longitude,
        endLat: destination.latitude,
        endLon: destination.longitude,
        timeoutPerEndpoint: const Duration(seconds: 8),
      );
      if (!mounted) return;
      if (route != null) {
        setState(() {
          _route = route['routePoints'] as List<LatLng>;
          _distanceKm = (route['distance'] as num).toDouble();
          _durationMin = (route['duration'] as num).toDouble();
        });
      }
    } catch (_) {
      // A missing map service must not hide the SOS incident dashboard.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _navigateToHospital() async {
    final hospital = _hospital;
    if (hospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nearby hospital route is not available yet.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccidentMapPage(
          accidentLat: widget.latitude,
          accidentLon: widget.longitude,
          hospitalName: hospital['name']?.toString(),
          hospitalLat: (hospital['lat'] as num).toDouble(),
          hospitalLon: (hospital['lon'] as num).toDouble(),
          address: 'Accident location',
          severity: 'Critical',
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  List<LatLng> get _activeRoute =>
      _toAccident ? _route.reversed.toList(growable: false) : _route;
  LatLng get _ambulancePoint => _activeRoute.isEmpty
      ? _incident
      : _activeRoute[(((_activeRoute.length - 1) * _progress).round().clamp(
          0,
          _activeRoute.length - 1,
        )).toInt()];

  int get _journeyStage {
    if (_progress < .18) return 1;
    if (_progress < .34) return 2;
    if (_progress < .78) return 3;
    return 4;
  }

  List<LatLng> _signalPoints() {
    if (_activeRoute.length < 4) return const [];
    return [.2, .43, .68, .86]
        .map(
          (fraction) =>
              _activeRoute[(((_activeRoute.length - 1) * fraction)
                      .round()
                      .clamp(0, _activeRoute.length - 1))
                  .toInt()],
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalPoint = _hospital == null
        ? null
        : LatLng(
            (_hospital!['lat'] as num).toDouble(),
            (_hospital!['lon'] as num).toDouble(),
          );
    final ambulance =
        (_dispatch['ambulance_name'] ??
                _dispatch['ambulance_id'] ??
                'Ambulance A-01')
            .toString();
    final remainingDistance = (_distanceKm ?? 0) * (1 - _progress);
    final remainingEta = (_durationMin ?? 0) * (1 - _progress);
    return Scaffold(
      backgroundColor: _dark ? const Color(0xFF08142F) : _paleBlue,
      body: SafeArea(
        child: Column(
          children: [
            _CorridorHeader(
              onBack: _back,
              onRefresh: _prepareCorridor,
              dark: _dark,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  _AmbulanceStatusCard(
                    ambulance: ambulance,
                    speed: _simulated ? '42' : 'Live',
                    eta: _durationMin == null
                        ? '…'
                        : OSRMRoutingService.formatDuration(remainingEta),
                    distance: _distanceKm == null
                        ? '…'
                        : OSRMRoutingService.formatDistance(remainingDistance),
                    stage: _journeyStage,
                    simulated: _simulated,
                    dark: _dark,
                  ),
                  const SizedBox(height: 13),
                  _mapCard(hospitalPoint),
                  const SizedBox(height: 13),
                  _IntersectionsCard(routeDistanceKm: _distanceKm, dark: _dark),
                  const SizedBox(height: 13),
                  _HospitalCard(
                    name: _hospital?['name']?.toString() ?? 'Nearby hospital',
                    distance: _distanceKm == null
                        ? 'Route distance unavailable'
                        : '${OSRMRoutingService.formatDistance(_distanceKm!)} • ${OSRMRoutingService.formatDuration(_durationMin ?? 0)} ETA',
                    dark: _dark,
                    onNavigate: _navigateToHospital,
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                        child: CircularProgressIndicator(color: _coral),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapCard(LatLng? hospitalPoint) {
    final activeRoute = _activeRoute;
    final points = <Marker>[
      Marker(
        point: _incident,
        width: 48,
        height: 58,
        child: const Icon(Icons.location_on_rounded, color: _coral, size: 48),
      ),
      Marker(
        point: _ambulancePoint,
        width: 48,
        height: 48,
        child: const _MapMarker(
          icon: Icons.local_shipping_rounded,
          color: _blue,
        ),
      ),
      if (hospitalPoint != null)
        Marker(
          point: hospitalPoint,
          width: 48,
          height: 48,
          child: const _MapMarker(
            icon: Icons.local_hospital_rounded,
            color: _green,
          ),
        ),
      if (_showSignals)
        ..._signalPoints().map(
          (point) => Marker(
            point: point,
            width: 30,
            height: 34,
            child: const _TrafficSignalMarker(),
          ),
        ),
    ];
    return Container(
      height: 420,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [_cardShadow],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _incident,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.accident_alert_app',
              ),
              if (activeRoute.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: activeRoute,
                      strokeWidth: 6,
                      color: _toAccident ? _blue : const Color(0xFF08BCA6),
                    ),
                  ],
                ),
              MarkerLayer(markers: points),
            ],
          ),
          Positioned(
            top: 13,
            left: 13,
            child: _RouteTabs(
              toAccident: _toAccident,
              dark: _dark,
              onSelect: (value) => setState(() => _toAccident = value),
            ),
          ),
          Positioned(
            top: 13,
            right: 13,
            child: _LiveTrackingPill(simulated: _simulated),
          ),
          Positioned(
            right: 13,
            top: 69,
            child: Column(
              children: [
                _MapControl(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Center accident',
                  onTap: () => _mapController.move(_incident, 14),
                ),
                const SizedBox(height: 8),
                _MapControl(
                  icon: _showSignals
                      ? Icons.traffic_rounded
                      : Icons.layers_rounded,
                  tooltip: 'Toggle simulated traffic signals',
                  onTap: () => setState(() => _showSignals = !_showSignals),
                ),
              ],
            ),
          ),
          if (_hospital == null && !_loading)
            Positioned(
              left: 12,
              right: 74,
              bottom: 12,
              child: _MapMessage(
                text: 'Hospital route unavailable. Tap refresh to try again.',
                dark: _dark,
              ),
            ),
          Positioned(left: 12, bottom: 12, child: _MapLegend(dark: _dark)),
        ],
      ),
    );
  }
}

const _cardShadow = BoxShadow(
  color: Color(0x142456A6),
  blurRadius: 15,
  offset: Offset(0, 5),
);

class _CorridorHeader extends StatelessWidget {
  const _CorridorHeader({
    required this.onBack,
    required this.onRefresh,
    required this.dark,
  });
  final VoidCallback onBack, onRefresh;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(17, 7, 17, 9),
    child: Row(
      children: [
        _RoundHeaderButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
          dark: dark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : _navy,
                  ),
                  children: const [
                    TextSpan(text: 'Emergency '),
                    TextSpan(
                      text: 'Corridor',
                      style: TextStyle(
                        color: _coral,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Faster Routes  •  Safer Roads  •  Save Lives',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFB6C5DF)
                      : const Color(0xFF64799D),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        _RoundHeaderButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh,
          dark: dark,
        ),
      ],
    ),
  );
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.icon,
    required this.onTap,
    required this.dark,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => Material(
    color: dark ? const Color(0xFF182C55) : Colors.white,
    shape: const CircleBorder(),
    elevation: 2,
    shadowColor: const Color(0x202456A6),
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: dark ? Colors.white : _navy, size: 24),
      tooltip: icon == Icons.refresh_rounded ? 'Refresh corridor' : 'Back',
    ),
  );
}

class _AmbulanceStatusCard extends StatelessWidget {
  const _AmbulanceStatusCard({
    required this.ambulance,
    required this.speed,
    required this.eta,
    required this.distance,
    required this.stage,
    required this.simulated,
    required this.dark,
  });
  final String ambulance, speed, eta, distance;
  final int stage;
  final bool simulated, dark;
  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : _navy;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF14254A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_cardShadow],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF1F4), Color(0xFFEAF5FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ambulance,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDF7EC),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 8, color: _green),
                                SizedBox(width: 5),
                                Text(
                                  'En Route',
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        simulated
                            ? 'Advanced Life Support • Demo tracking'
                            : 'Advanced Life Support',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? const Color(0xFFB6C5DF)
                              : const Color(0xFF64799D),
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              icon: Icons.speed_rounded,
                              value: '$speed km/h',
                              label: simulated ? 'Speed • demo' : 'Speed',
                              tint: _blue,
                              dark: dark,
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              icon: Icons.access_time_filled_rounded,
                              value: eta,
                              label: 'ETA',
                              tint: _coral,
                              dark: dark,
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              icon: Icons.location_on_rounded,
                              value: distance,
                              label: 'Remaining',
                              tint: _coral,
                              dark: dark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 4, 13, 12),
            child: _JourneyProgress(stage: stage, dark: dark),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    required this.dark,
  });
  final IconData icon;
  final String value, label;
  final Color tint;
  final bool dark;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: tint, size: 17),
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? Colors.white : _navy,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? const Color(0xFFB6C5DF) : const Color(0xFF64799D),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _JourneyProgress extends StatelessWidget {
  const _JourneyProgress({required this.stage, required this.dark});
  final int stage;
  final bool dark;
  static const _labels = [
    'Dispatched',
    'En Route',
    'Arrived at Scene',
    'Transporting',
    'At Hospital',
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: List.generate(
          _labels.length,
          (index) => Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: index <= stage
                        ? _coral
                        : (dark
                              ? const Color(0xFF405273)
                              : const Color(0xFFE3EAF4)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    index < stage
                        ? Icons.check_rounded
                        : (index == stage ? Icons.circle : Icons.circle),
                    color: Colors.white,
                    size: index == stage ? 9 : 14,
                  ),
                ),
                if (index < _labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index < stage
                          ? _coral
                          : (dark
                                ? const Color(0xFF405273)
                                : const Color(0xFFE3EAF4)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Row(
        children: List.generate(
          _labels.length,
          (index) => Expanded(
            child: Text(
              _labels[index],
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: index <= stage
                    ? (dark ? Colors.white : _navy)
                    : (dark
                          ? const Color(0xFF879AB9)
                          : const Color(0xFF8293B0)),
                fontSize: 8,
                fontWeight: index == stage ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _RouteTabs extends StatelessWidget {
  const _RouteTabs({
    required this.toAccident,
    required this.dark,
    required this.onSelect,
  });
  final bool toAccident, dark;
  final ValueChanged<bool> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [_cardShadow],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RouteTab(
          label: 'To Accident',
          selected: toAccident,
          onTap: () => onSelect(true),
        ),
        _RouteTab(
          label: 'To Hospital',
          selected: !toAccident,
          onTap: () => onSelect(false),
        ),
      ],
    ),
  );
}

class _RouteTab extends StatelessWidget {
  const _RouteTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _coral : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _navy,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _LiveTrackingPill extends StatelessWidget {
  const _LiveTrackingPill({required this.simulated});
  final bool simulated;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [_cardShadow],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _coral,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          simulated ? 'Tracking • Demo' : 'Live Tracking',
          style: const TextStyle(
            color: _navy,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 3,
    child: IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: _navy, size: 20),
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
    ),
  );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
      boxShadow: const [_cardShadow],
    ),
    child: Icon(icon, color: color, size: 27),
  );
}

class _TrafficSignalMarker extends StatelessWidget {
  const _TrafficSignalMarker();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      boxShadow: const [_cardShadow],
    ),
    child: const Icon(Icons.traffic_rounded, color: _green, size: 23),
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [_cardShadow],
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendRow(
          icon: Icons.location_on_rounded,
          color: _coral,
          label: 'Accident Location',
        ),
        _LegendRow(
          icon: Icons.horizontal_rule_rounded,
          color: _blue,
          label: 'Ambulance Route',
        ),
        _LegendRow(
          icon: Icons.horizontal_rule_rounded,
          color: Color(0xFF08BCA6),
          label: 'Hospital Route',
        ),
        _LegendRow(
          icon: Icons.traffic_rounded,
          color: _green,
          label: 'Traffic Signal',
        ),
      ],
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: _navy,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.text, required this.dark});
  final String text;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF14254A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: TextStyle(color: dark ? Colors.white : _navy, fontSize: 10),
    ),
  );
}

class _IntersectionsCard extends StatelessWidget {
  const _IntersectionsCard({required this.routeDistanceKm, required this.dark});
  final double? routeDistanceKm;
  final bool dark;
  static const _names = [
    'Kalamassery Junction',
    'South Kalamassery Signal',
    'HMT Junction',
    'Edappally Toll Junction',
  ];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 14, 13, 12),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF14254A) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [_cardShadow],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.traffic_rounded, color: _coral, size: 25),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Corridor Intersections',
                style: TextStyle(
                  color: dark ? Colors.white : _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8EC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Simulated Priority',
                style: TextStyle(
                  color: _coral,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Signal priority is simulated for this demo. No real traffic signals are controlled.',
          style: TextStyle(
            color: dark ? const Color(0xFFB6C5DF) : const Color(0xFF64799D),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _names.length; index++)
          _IntersectionRow(
            index: index,
            name: _names[index],
            distance: routeDistanceKm == null
                ? '—'
                : '${(routeDistanceKm! * (index + 1) / 5).toStringAsFixed(1)} km',
            dark: dark,
          ),
      ],
    ),
  );
}

class _IntersectionRow extends StatelessWidget {
  const _IntersectionRow({
    required this.index,
    required this.name,
    required this.distance,
    required this.dark,
  });
  final int index;
  final String name, distance;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF1A315C) : const Color(0xFFF7FAFE),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 27,
          height: 27,
          decoration: const BoxDecoration(
            color: _coral,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: dark ? Colors.white : _navy,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          color: Color(0xFF7F96B8),
          size: 15,
        ),
        const SizedBox(width: 3),
        Text(
          distance,
          style: TextStyle(
            color: dark ? const Color(0xFFB6C5DF) : const Color(0xFF64799D),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7EE),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.traffic_rounded, color: _green, size: 14),
              SizedBox(width: 3),
              Text(
                'Priority simulated',
                style: TextStyle(
                  color: _green,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          Icons.chevron_right_rounded,
          color: dark ? const Color(0xFFB6C5DF) : const Color(0xFF8194B2),
          size: 21,
        ),
      ],
    ),
  );
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.name,
    required this.distance,
    required this.dark,
    required this.onNavigate,
  });
  final String name, distance;
  final bool dark;
  final VoidCallback onNavigate;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF14254A) : Colors.white,
      borderRadius: BorderRadius.circular(23),
      boxShadow: [_cardShadow],
    ),
    child: Row(
      children: [
        Container(
          width: 94,
          height: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD5EBFF), Color(0xFF9ACAF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.local_hospital_rounded,
                size: 52,
                color: Colors.white.withValues(alpha: .9),
              ),
              const Positioned(
                top: 10,
                child: Icon(Icons.add_box_rounded, color: _coral, size: 21),
              ),
              const Positioned(
                bottom: 6,
                child: Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF3374B5),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFDDF7EC),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_rounded, color: _green, size: 19),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white : _navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                distance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFB6C5DF)
                      : const Color(0xFF64799D),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        FilledButton.icon(
          onPressed: onNavigate,
          icon: const Icon(Icons.navigation_rounded, size: 15),
          label: const Text(
            'Navigate',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _coral,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ),
      ],
    ),
  );
}
