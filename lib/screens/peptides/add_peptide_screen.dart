import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/peptide.dart';
import '../../providers/peptide_provider.dart';
import '../../utils/peptide_colors.dart';

class AddPeptideScreen extends StatefulWidget {
  /// Pass an existing peptide to enter edit mode.
  final Peptide? peptide;

  const AddPeptideScreen({super.key, this.peptide});

  bool get isEditing => peptide != null;

  @override
  State<AddPeptideScreen> createState() => _AddPeptideScreenState();
}

class _AddPeptideScreenState extends State<AddPeptideScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _vendorController;
  late final TextEditingController _strengthController;

  /// `null` means "use automatic palette color".
  String? _selectedColorHex;

  /// `null` means "use default beaker icon".
  String? _selectedIconName;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.peptide?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.peptide?.description ?? '');
    _vendorController =
        TextEditingController(text: widget.peptide?.vendor ?? '');
    _strengthController =
        TextEditingController(text: widget.peptide?.dosageStrength ?? '');
    _selectedColorHex = widget.peptide?.colorHex;
    _selectedIconName = widget.peptide?.iconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a peptide name')),
      );
      return;
    }

    String? clean(TextEditingController c) {
      final s = c.text.trim();
      return s.isEmpty ? null : s;
    }

    final description = clean(_descriptionController);
    final vendor = clean(_vendorController);
    final strength = clean(_strengthController);

    final provider = context.read<PeptideProvider>();

    if (widget.isEditing) {
      provider.updatePeptide(
        id: widget.peptide!.id,
        name: name,
        description: description,
        vendor: vendor,
        dosageStrength: strength,
        colorHex: _selectedColorHex,
        iconName: _selectedIconName,
        clearColorHex: _selectedColorHex == null,
        clearIconName: _selectedIconName == null,
      );
    } else {
      provider.addPeptide(
        name: name,
        description: description,
        vendor: vendor,
        dosageStrength: strength,
        colorHex: _selectedColorHex,
        iconName: _selectedIconName,
      );
    }

    Navigator.pop(context);
  }

  // Preview color used so the icon picker can show icons tinted correctly.
  Color _previewColor(int fallbackIndex) {
    if (_selectedColorHex != null) return hexToColor(_selectedColorHex!);
    return peptideColor(fallbackIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Use current list length as a fallback index for the preview color.
    final peptides = context.read<PeptideProvider>().peptides;
    final fallbackIndex = widget.isEditing
        ? peptides.indexWhere((p) => p.id == widget.peptide!.id)
        : peptides.length;
    final previewColor = _previewColor(fallbackIndex < 0 ? 0 : fallbackIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Peptide' : 'Add Peptide'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Peptide Name',
                prefixIcon: const Icon(Icons.science_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vendorController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Vendor (optional)',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _strengthController,
                    decoration: InputDecoration(
                      labelText: 'Strength',
                      hintText: 'e.g. 12mg',
                      prefixIcon: const Icon(Icons.medication_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // ── Color picker ─────────────────────────────────────────────
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            _ColorPicker(
              selectedHex: _selectedColorHex,
              onSelected: (hex) => setState(() => _selectedColorHex = hex),
            ),
            const SizedBox(height: 20),

            // ── Icon picker ──────────────────────────────────────────────
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            _IconPicker(
              selectedKey: _selectedIconName,
              previewColor: previewColor,
              onSelected: (key) => setState(() => _selectedIconName = key),
            ),

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child:
                  Text(widget.isEditing ? 'Save Changes' : 'Add Peptide'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color picker ─────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final String? selectedHex;
  final ValueChanged<String?> onSelected;

  const _ColorPicker({required this.selectedHex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ColorSwatch(
          color: null,
          isSelected: selectedHex == null,
          onTap: () => onSelected(null),
        ),
        ...kPeptideColorPalette.map((color) {
          final hex = colorToHex(color);
          return _ColorSwatch(
            color: color,
            isSelected: selectedHex == hex,
            onTap: () => onSelected(hex),
          );
        }),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAuto = color == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAuto ? scheme.surfaceContainerHighest : color,
          border: Border.all(
            color: isSelected ? scheme.primary : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isAuto ? scheme.primary : color!)
                        .withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 18,
                color: isAuto ? scheme.primary : Colors.white,
              )
            : isAuto
                ? Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  )
                : null,
      ),
    );
  }
}

// ─── Icon picker ──────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  final String? selectedKey;
  final Color previewColor;
  final ValueChanged<String?> onSelected;

  const _IconPicker({
    required this.selectedKey,
    required this.previewColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kPeptideIcons.entries.map((entry) {
        final isSelected =
            selectedKey == entry.key ||
            (selectedKey == null && entry.key == 'science');
        return _IconSwatch(
          iconData: entry.value,
          iconKey: entry.key,
          isSelected: isSelected,
          previewColor: previewColor,
          onTap: () => onSelected(
            entry.key == 'science' ? null : entry.key,
          ),
        );
      }).toList(),
    );
  }
}

class _IconSwatch extends StatelessWidget {
  final IconData iconData;
  final String iconKey;
  final bool isSelected;
  final Color previewColor;
  final VoidCallback onTap;

  const _IconSwatch({
    required this.iconData,
    required this.iconKey,
    required this.isSelected,
    required this.previewColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? previewColor.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border.all(
            color: isSelected ? previewColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          iconData,
          size: 22,
          color: isSelected ? previewColor : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
