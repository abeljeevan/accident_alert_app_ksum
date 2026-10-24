import 'package:flutter/material.dart';

const appRed = Color(0xFFFF3347);
const appBlue = Color(0xFF2588F5);

class NearbyHospitalsView extends StatefulWidget {
  const NearbyHospitalsView({super.key, required this.isDarkMode, required this.onLoad, this.onNavigate});
  final bool isDarkMode;
  final Future<List<(String, double, double, double)>> Function() onLoad;
  final Future<void> Function(String name, double latitude, double longitude)? onNavigate;
  @override
  State<NearbyHospitalsView> createState() => _NearbyHospitalsViewState();
}

class _NearbyHospitalsViewState extends State<NearbyHospitalsView> {
  final _search = TextEditingController();
  late Future<List<(String, double, double, double)>> _future;
  @override
  void initState() { super.initState(); _future = widget.onLoad(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 12), child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search nearby hospitals...'))),
    Expanded(child: FutureBuilder<List<(String, double, double, double)>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_off_rounded, size: 46), const SizedBox(height: 12), const Text('Could not load nearby hospitals.', textAlign: TextAlign.center), const SizedBox(height: 8), Text('Allow location access and check your internet connection, then try again.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 12), FilledButton.icon(onPressed: () => setState(() => _future = widget.onLoad()), icon: const Icon(Icons.refresh), label: const Text('Try again'))])));
      final all = snapshot.data ?? const <(String, double, double, double)>[];
      final results = all.where((h) => h.$1.toLowerCase().contains(_search.text.trim().toLowerCase())).toList();
      if (results.isEmpty) return Center(child: Text(all.isEmpty ? 'No hospitals found nearby.' : 'No matching hospitals.'));
      return ListView.separated(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), itemCount: results.length, separatorBuilder: (_, __) => const SizedBox(height: 9), itemBuilder: (context, index) {
        final hospital = results[index];
        return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Row(children: [Container(width: 39, height: 39, decoration: BoxDecoration(color: appRed.withValues(alpha: .1), shape: BoxShape.circle), child: const Icon(Icons.local_hospital_rounded, color: appRed)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(hospital.$1, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${hospital.$2.toStringAsFixed(1)} km away', style: Theme.of(context).textTheme.bodySmall)])), const SizedBox(width: 8), FilledButton(onPressed: widget.onNavigate == null ? null : () => widget.onNavigate!(hospital.$1, hospital.$3, hospital.$4), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11)), child: const Text('Navigate'))])));
      });
    }))
  ]);
}

class HomeAction extends StatelessWidget {
  const HomeAction({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.prominent = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Card(color: prominent ? appRed : null, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: prominent ? Colors.white.withValues(alpha: .18) : appRed.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: prominent ? Colors.white : appRed, size: 23)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: prominent ? Colors.white : null, fontSize: 14)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: prominent ? Colors.white.withValues(alpha: .85) : Theme.of(context).colorScheme.onSurfaceVariant))])), Icon(Icons.chevron_right_rounded, color: prominent ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant)]))));
}

class DetectorView extends StatelessWidget {
  const DetectorView({super.key, required this.isDarkMode, required this.voiceEnabled, required this.onVoiceChanged, required this.onSimulate, required this.onSendAlert, required this.onStatus});
  final bool isDarkMode, voiceEnabled;
  final ValueChanged<bool> onVoiceChanged;
  final VoidCallback onSimulate, onSendAlert;
  final String Function() onStatus;
  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;
    Widget sensor(IconData icon, String label, String value, Color tint) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: tint.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: tint, size: 20), const SizedBox(width: 8), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Theme.of(context).colorScheme.onSurface))]))])));
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(height: 194, decoration: BoxDecoration(color: appRed.withValues(alpha: isDarkMode ? .13 : .08), borderRadius: BorderRadius.circular(24)), child: Stack(alignment: Alignment.center, children: [Container(width: 156, height: 156, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: appRed.withValues(alpha: .13), width: 16))), Container(width: 118, height: 118, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: appRed.withValues(alpha: .23), width: 2))), Container(width: 82, height: 82, decoration: BoxDecoration(color: card, shape: BoxShape.circle, boxShadow: [BoxShadow(color: appRed.withValues(alpha: .16), blurRadius: 22)]), child: const Icon(Icons.directions_car_rounded, color: appRed, size: 42)), const Positioned(top: 18, right: 22, child: Icon(Icons.cloud_rounded, color: appBlue, size: 34))])),
      const SizedBox(height: 17), const Center(child: Text('Monitoring Sensors...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))), const SizedBox(height: 13),
      Row(children: [sensor(Icons.speed_rounded, 'Accelerometer', 'Monitoring', const Color(0xFF1DBB78)), const SizedBox(width: 10), sensor(Icons.explore_rounded, 'Gyroscope', 'Monitoring', const Color(0xFF1DBB78))]), const SizedBox(height: 10),
      Row(children: [sensor(Icons.directions_car_rounded, 'Speed', 'Live sensor', appBlue), const SizedBox(width: 10), sensor(Icons.location_on_rounded, 'Location', 'GPS ready', appBlue)]), const SizedBox(height: 15),
      FilledButton.icon(onPressed: onSimulate, icon: const Icon(Icons.warning_rounded), label: const Text('Simulate Accident'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50))), const SizedBox(height: 12),
      Card(child: SwitchListTile(secondary: const Icon(Icons.mic_rounded, color: appRed), title: const Text('Voice Assistant', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Tap and say “Help”'), activeTrackColor: appRed, value: voiceEnabled, onChanged: onVoiceChanged)), const SizedBox(height: 10),
      Card(child: ListTile(leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF21B66F), size: 29), title: const Text('Detection Status', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(onStatus()), trailing: Icon(Icons.graphic_eq_rounded, color: const Color(0xFF21B66F)))), const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: onSendAlert, icon: const Icon(Icons.notification_important_rounded), label: const Text('Send Emergency Alert')),
    ]);
  }
}
