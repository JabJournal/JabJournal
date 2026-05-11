import 'package:flutter/material.dart';
import '../../services/app_icon_service.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  static const _variants = [
    (name: null,       label: 'Ocean',    asset: 'assets/icons/icon_ocean.png'),
    (name: 'forest',   label: 'Forest',   asset: 'assets/icons/icon_forest.png'),
    (name: 'amethyst', label: 'Amethyst', asset: 'assets/icons/icon_amethyst.png'),
    (name: 'slate',    label: 'Slate',    asset: 'assets/icons/icon_slate.png'),
  ];

  String? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final name = await AppIconService.currentIcon();
      if (mounted) setState(() => _current = name);
    } catch (_) {}
  }

  Future<void> _pick(String? name) async {
    if (_busy || name == _current) return;
    setState(() => _busy = true);
    try {
      await AppIconService.setIcon(name);
      if (mounted) setState(() => _current = name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change icon: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Icon')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(24),
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        children: _variants
            .map((v) => _IconTile(
                  asset: v.asset,
                  label: v.label,
                  selected: _current == v.name,
                  onTap: _busy ? null : () => _pick(v.name),
                ))
            .toList(),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final String asset;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _IconTile({
    required this.asset,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(asset, width: 100, height: 100,
                      fit: BoxFit.cover),
                ),
                if (selected)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cs.primary, width: 3),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 36),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
