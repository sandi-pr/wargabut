import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/cosplay_project_model.dart';
import '../../../../provider/cosplay_project_provider.dart';

class ManualFillSlotDialog extends StatefulWidget {
  final String projectId;
  final CosplayProjectSlot slot;

  const ManualFillSlotDialog({
    super.key,
    required this.projectId,
    required this.slot,
  });

  static Future<bool?> show(BuildContext context, {
    required String projectId,
    required CosplayProjectSlot slot,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ManualFillSlotDialog(projectId: projectId, slot: slot),
    );
  }

  @override
  State<ManualFillSlotDialog> createState() => _ManualFillSlotDialogState();
}

class _ManualFillSlotDialogState extends State<ManualFillSlotDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _isExternal = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tandai Slot Terisi',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Karakter: ${widget.slot.characterName} ${widget.slot.characterVersion.isNotEmpty ? '(${widget.slot.characterVersion})' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Cosplayer / Teman',
                  hintText: 'Misal: Yuki / Andi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: 'Kontak / Akun Instagram (Opsional)',
                  hintText: 'Misal: @cosplayer_id atau no WA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.contact_mail_outlined),
                ),
              ),
              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengisi di Luar Wargabut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tandai sebagai teman/kenalan yang belum punya akun Wargabut', style: TextStyle(fontSize: 11)),
                value: _isExternal,
                onChanged: (val) => setState(() => _isExternal = val),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nama cosplayer wajib diisi.')),
                            );
                            return;
                          }

                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final provider = context.read<CosplayProjectProvider>();

                          setState(() => _isSubmitting = true);
                          try {
                            final filledUser = SlotFilledUser(
                              uid: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                              username: name.toLowerCase().replaceAll(' ', '_'),
                              displayName: name,
                              instagram: _contactController.text.trim().replaceAll('@', ''),
                              isExternal: _isExternal,
                              externalContact: _contactController.text.trim(),
                              assignedAt: DateTime.now(),
                            );

                            await provider.assignSlotManually(
                                  projectId: widget.projectId,
                                  slotId: widget.slot.slotId,
                                  filledUser: filledUser,
                                );

                            if (mounted) {
                              nav.pop(true);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Slot karakter berhasil ditandai terisi!'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Gagal mengisi slot: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                  child: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan & Kunci Slot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
