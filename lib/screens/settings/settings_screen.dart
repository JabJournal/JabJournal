import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/foreground_service_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/app_icon_service.dart';
import 'app_icon_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return ListView(
            children: [
              _SectionHeader(label: 'Appearance'),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_auto_outlined),
                title: const Text('Follow System Theme'),
                subtitle: const Text('Automatically match your device appearance'),
                value: theme.useSystem,
                onChanged: (v) => theme.setUseSystem(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(
                  Icons.dark_mode_outlined,
                  color: theme.useSystem ? Colors.grey[400] : null,
                ),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: theme.useSystem ? Colors.grey[400] : null,
                  ),
                ),
                subtitle: Text(
                  theme.useSystem
                      ? 'Disable "Follow System Theme" to set manually'
                      : 'Switch to a dark color scheme',
                  style: TextStyle(
                    color: theme.useSystem ? Colors.grey[400] : null,
                  ),
                ),
                value: theme.darkMode,
                onChanged: theme.useSystem ? null : (v) => theme.setDarkMode(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(
                  Icons.circle,
                  color: theme.darkMode && !theme.useSystem ? null : Colors.grey[400],
                ),
                title: Text(
                  'OLED Mode',
                  style: TextStyle(
                    color: theme.darkMode && !theme.useSystem ? null : Colors.grey[400],
                  ),
                ),
                subtitle: Text(
                  theme.darkMode && !theme.useSystem
                      ? 'Use pure black backgrounds to save battery on OLED screens'
                      : 'Enable Dark Mode first',
                  style: TextStyle(
                    color: theme.darkMode && !theme.useSystem ? null : Colors.grey[400],
                  ),
                ),
                value: theme.oledMode,
                onChanged: theme.darkMode && !theme.useSystem
                    ? (v) => theme.setOledMode(v)
                    : null,
              ),
              const Divider(height: 1),
              const _AppIconNavTile(),
              const Divider(height: 1),
              _SectionHeader(label: 'Data'),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Backup & Export'),
                subtitle: const Text('Export, import, and schedule backups'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                ),
              ),
              const _AdvancedSection(),
            ],
          );
        },
      ),
    );
  }
}

// ─── App Icon nav tile (Appearance → App Icon sub-screen) ────────────────────

class _AppIconNavTile extends StatefulWidget {
  const _AppIconNavTile();

  @override
  State<_AppIconNavTile> createState() => _AppIconNavTileState();
}

class _AppIconNavTileState extends State<_AppIconNavTile> {
  static const _labels = {
    null:        'Ocean',
    'forest':    'Forest',
    'amethyst':  'Amethyst',
    'slate':     'Slate',
  };

  static const _assets = {
    null:        'assets/icons/icon_ocean.png',
    'forest':    'assets/icons/icon_forest.png',
    'amethyst':  'assets/icons/icon_amethyst.png',
    'slate':     'assets/icons/icon_slate.png',
  };

  String? _current;

  @override
  void initState() {
    super.initState();
    if (AppIconService.isSupported) _load();
  }

  Future<void> _load() async {
    try {
      final name = await AppIconService.currentIcon();
      if (mounted) setState(() => _current = name);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!AppIconService.isSupported) return const SizedBox.shrink();
    final label = _labels[_current] ?? 'Ocean';
    final asset = _assets[_current] ?? _assets[null]!;
    return ListTile(
      leading: const Icon(Icons.app_shortcut_outlined),
      title: const Text('App Icon'),
      subtitle: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(asset, width: 36, height: 36, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppIconScreen()),
        );
        _load();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// "Advanced" section — currently only contains the foreground service
/// escape hatch. Hidden entirely on platforms where it doesn't apply.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ForegroundServiceProvider>(
      builder: (context, fg, _) {
        if (!fg.isSupported) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            _SectionHeader(label: 'Advanced'),
            SwitchListTile(
              secondary: const Icon(Icons.shield_outlined),
              title: const Text('Persistent background service'),
              subtitle: const Text(
                  'Adds a permanent low-priority notification that keeps the '
                  'app alive at all times. Only enable if scheduled reminders '
                  'are unreliable on your device — most phones don\'t need it.'),
              isThreeLine: true,
              value: fg.enabled,
              onChanged: fg.isLoaded ? (v) => fg.setEnabled(v) : null,
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
