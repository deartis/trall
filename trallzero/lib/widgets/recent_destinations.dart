import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

/// Persiste e exibe os últimos 5 destinos buscados com sucesso.
///
/// [horizontal] : quando true, exibe chips compactos em scroll horizontal
///               (para a barra de atalhos rápidos abaixo da busca).
///               Quando false (padrão), exibe lista vertical no Drawer.
class RecentDestinations extends StatefulWidget {
  const RecentDestinations({
    super.key,
    required this.onTap,
    this.horizontal = false,
  });

  /// Chamado com o endereço selecionado pelo usuário
  final void Function(String address) onTap;

  /// Modo de exibição: horizontal (chips) ou vertical (lista)
  final bool horizontal;

  @override
  State<RecentDestinations> createState() => _RecentDestinationsState();

  /// Salva um destino na lista de recentes (endereço + timestamp)
  static Future<void> saveDestination(String address) async {
    if (address.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_destinations') ?? [];

    // Remove duplicata se já existir
    final existing = raw.where((e) {
      try {
        return (jsonDecode(e) as Map)['address'] != address;
      } catch (_) {
        return true;
      }
    }).toList();

    // Insere no início
    existing.insert(
      0,
      jsonEncode({'address': address, 'ts': DateTime.now().toIso8601String()}),
    );

    // Mantém no máximo 5
    await prefs.setStringList(
      'recent_destinations',
      existing.take(5).toList(),
    );
  }
}

class _RecentDestinationsState extends State<RecentDestinations> {
  List<_RecentEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_destinations') ?? [];
    final entries = raw.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return _RecentEntry(
          address: m['address'] as String,
          timestamp: DateTime.tryParse(m['ts'] as String? ?? '') ?? DateTime.now(),
        );
      } catch (_) {
        return null;
      }
    }).whereType<_RecentEntry>().toList();

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  String _timeLabel(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    return 'Há ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _entries.isEmpty) return const SizedBox.shrink();

    // ── Modo horizontal: chips em scroll ────────────────────────────
    if (widget.horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _RecentChip(
          entry: _entries[i],
          onTap: () => widget.onTap(_entries[i].address),
        ),
      );
    }

    // ── Modo vertical: lista no Drawer ──────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _entries.map((entry) => _RecentTile(
        entry: entry,
        timeLabel: _timeLabel(entry.timestamp),
        onTap: () => widget.onTap(entry.address),
      )).toList(),
    );
  }
}

class _RecentEntry {
  final String address;
  final DateTime timestamp;
  _RecentEntry({required this.address, required this.timestamp});
}

// ─────────────────────────────────────────────────────────────
//  Chip compacto (modo horizontal)
// ─────────────────────────────────────────────────────────────
class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.entry, required this.onTap});

  final _RecentEntry entry;
  final VoidCallback onTap;

  // Extrai apenas a primeira parte significativa do endereço (rua + número)
  String get _shortLabel {
    final parts = entry.address.split(',');
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        constraints: const BoxConstraints(maxWidth: 180),
        decoration: BoxDecoration(
          color: AppColors.bgPanel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              color: AppColors.amber,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _shortLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tile vertical (modo drawer)
// ─────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.entry,
    required this.timeLabel,
    required this.onTap,
  });

  final _RecentEntry entry;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.amberSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.address,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
