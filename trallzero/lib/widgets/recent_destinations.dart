import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste e exibe os últimos 5 destinos buscados com sucesso.
class RecentDestinations extends StatefulWidget {
  const RecentDestinations({
    super.key,
    required this.onTap,
  });

  /// Chamado com o endereço selecionado pelo usuário
  final void Function(String address) onTap;

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
    if (_loading) return const SizedBox.shrink();
    if (_entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            'DESTINOS RECENTES',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        ..._entries.map((entry) => _RecentTile(
          entry: entry,
          timeLabel: _timeLabel(entry.timestamp),
          onTap: () => widget.onTap(entry.address),
        )),
      ],
    );
  }
}

class _RecentEntry {
  final String address;
  final DateTime timestamp;
  _RecentEntry({required this.address, required this.timestamp});
}

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
                color: const Color(0xFFE07B1A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFFE07B1A),
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
