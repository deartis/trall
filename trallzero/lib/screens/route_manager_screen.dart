import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_snackbar.dart';
import '../controllers/truck_controller.dart';
import '../services/ocr_service.dart';
import '../services/location_service.dart';
import '../models/delivery_stop.dart';

class RouteManagerScreen extends StatefulWidget {
  const RouteManagerScreen({super.key});

  @override
  State<RouteManagerScreen> createState() => _RouteManagerScreenState();
}

class _RouteManagerScreenState extends State<RouteManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  // Trabalha numa cópia local — só persiste ao confirmar
  late List<DeliveryStop> _stops;
  bool _isSearching = false;
  bool _isDirty = false; // indica se houve alteração na ordem
  Timer? _debounce;

  LatLng _currentUserLocation = const LatLng(-22.9068, -43.1729);

  // Cores e ícones
  static const _amber = Color(0xFFE07B1A);
  static const _dark = Color(0xFF0E1017);
  static const _card = Color(0xFF161922);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initLocation();

    // Copia as paradas PENDENTES da rota ativa (já carregadas pelo TruckController)
    final tc = context.read<TruckController>();
    _stops = tc.deliveryStops
        .where((s) => !s.isCompleted)
        .map((s) => s)
        .toList();
  }

  Future<void> _initLocation() async {
    try {
      if (await LocationService.handlePermission()) {
        final pos = await LocationService.getCurrentPosition();
        if (mounted) {
          setState(() => _currentUserLocation = LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar localização: $e');
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final text = _searchController.text;
      final tc = context.read<TruckController>();
      if (text.isNotEmpty) {
        tc.fetchSuggestions(text, userLocation: _currentUserLocation);
      } else {
        tc.clearSuggestions();
      }
    });
  }

  Future<void> _addStopFromAddress(String address, LatLng userLocation, {String? defaultRecipientName}) async {
    setState(() => _isSearching = true);
    final tc = context.read<TruckController>();
    final point = await tc.searchAddress(address, userLocation);

    if (point != null) {
      final controller = TextEditingController(text: defaultRecipientName);
      if (!mounted) return;

      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nome do Destinatário',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: João da Silva / Loja X',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _amber),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      setState(() {
        _stops.add(DeliveryStop(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          recipientName: (name != null && name.isNotEmpty)
              ? name
              : 'Destinatário ${_stops.length + 1}',
          address: address,
          lat: point.latitude,
          lng: point.longitude,
        ));
        _isDirty = true;
      });
      _searchController.clear();
      tc.clearSuggestions();
    } else {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Endereço não encontrado.',
          isError: true,
        );
      }
    }

    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _scanInvoice() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ler Nota Fiscal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Escolha a origem da imagem da NF-e.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library, color: _amber),
            label: const Text('Galeria', style: TextStyle(color: _amber)),
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.gallery);
              if (ctx.mounted) Navigator.pop(ctx, img);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt, color: _amber),
            label: const Text('Câmera', style: TextStyle(color: _amber)),
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.camera);
              if (ctx.mounted) Navigator.pop(ctx, img);
            },
          ),
        ],
      ),
    );

    if (image == null) return;

    setState(() => _isSearching = true);
    final rawText = await OcrService.instance.extractTextFromImage(image.path);
    final guessedAddress = OcrService.instance.parseAddressFromText(rawText);
    final guessedName = OcrService.instance.parseClientNameFromText(rawText);
    if (mounted) setState(() => _isSearching = false);
    if (!mounted) return;

    final editController = TextEditingController(text: guessedAddress);
    final finalAddress = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirme o Endereço',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('O OCR identificou o endereço abaixo. Ajuste se necessário:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _amber),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, editController.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (finalAddress != null && finalAddress.trim().isNotEmpty) {
      _addStopFromAddress(
        finalAddress.trim(),
        _currentUserLocation,
        defaultRecipientName: guessedName.isNotEmpty ? guessedName : null,
      );
    }
  }

  void _optimizeStops() {
    if (_stops.length < 2) {
      showStyledSnackBar(
        context: context,
        message: 'Adicione pelo menos 2 paradas para otimizar.',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    LatLng currentLoc = _currentUserLocation;
    final unoptimized = List<DeliveryStop>.from(_stops);
    final optimized = <DeliveryStop>[];
    const distance = Distance();

    while (unoptimized.isNotEmpty) {
      DeliveryStop nearest = unoptimized.first;
      double minDistance =
          distance.as(LengthUnit.Meter, currentLoc, LatLng(nearest.lat, nearest.lng));

      for (final stop in unoptimized.skip(1)) {
        final dist =
            distance.as(LengthUnit.Meter, currentLoc, LatLng(stop.lat, stop.lng));
        if (dist < minDistance) {
          minDistance = dist;
          nearest = stop;
        }
      }

      optimized.add(nearest);
      unoptimized.remove(nearest);
      currentLoc = LatLng(nearest.lat, nearest.lng);
    }

    setState(() {
      _stops
        ..clear()
        ..addAll(optimized);
      _isDirty = true;
    });

    showStyledSnackBar(
      context: context,
      message: 'Rota otimizada por proximidade!',
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF34C759),
    );
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _isDirty = true;
    });
  }

  void _confirmRoute() {
    if (_stops.isEmpty) {
      showStyledSnackBar(
        context: context,
        message: 'Adicione ao menos uma parada.',
        isError: true,
      );
      return;
    }
    Navigator.of(context).pop(_stops);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // ── APP BAR CUSTOMIZADA ────────────────────────────────────────────
          Container(
            color: const Color(0xFF111318),
            padding: EdgeInsets.fromLTRB(8, safeTop + 8, 8, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Paradas da Rota',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Contador de pendentes
                if (_stops.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _amber.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      '${_stops.length} pendente${_stops.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, color: Colors.white70),
                  onPressed: _optimizeStops,
                  tooltip: 'Otimizar Ordem',
                ),
                IconButton(
                  icon: const Icon(Icons.document_scanner, color: Colors.white70),
                  onPressed: _scanInvoice,
                  tooltip: 'Ler NF-e',
                ),
              ],
            ),
          ),

          // ── CAMPO DE BUSCA ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Adicionar endereço...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 15),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _amber, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (v) =>
                          _addStopFromAddress(v, _currentUserLocation),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _ActionCircle(
                  icon: Icons.add_rounded,
                  onTap: () {
                    if (_searchController.text.isNotEmpty) {
                      tc.clearSuggestions();
                      FocusScope.of(context).unfocus();
                      _addStopFromAddress(
                          _searchController.text, _currentUserLocation);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── SUGESTÕES ──────────────────────────────────────────────────────
          if (tc.suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: tc.suggestions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                itemBuilder: (_, i) {
                  final s = tc.suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_rounded,
                        color: Colors.blueAccent, size: 18),
                    title: Text(s,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      _searchController.text = s;
                      tc.clearSuggestions();
                      FocusScope.of(context).unfocus();
                      _addStopFromAddress(s, _currentUserLocation);
                    },
                  );
                },
              ),
            ),

          if (_isSearching)
            const LinearProgressIndicator(
              color: _amber,
              backgroundColor: Colors.transparent,
            ),

          // ── LISTA REORDENÁVEL ──────────────────────────────────────────────
          Expanded(
            child: _stops.isEmpty
                ? _EmptyState()
                : Column(
                    children: [
                      // Dica de arrastar
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'Arraste para reorganizar a ordem de entrega',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _stops.length,
                          proxyDecorator: (child, index, animation) =>
                              Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          ),
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) newIndex -= 1;
                              final item = _stops.removeAt(oldIndex);
                              _stops.insert(newIndex, item);
                              _isDirty = true;
                            });
                          },
                          itemBuilder: (context, index) {
                            final stop = _stops[index];
                            return _StopCard(
                              key: ValueKey(stop.id),
                              stop: stop,
                              index: index,
                              total: _stops.length,
                              onDelete: () => _removeStop(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),

      // ── BARRA INFERIOR ─────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        color: const Color(0xFF111318),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: Row(
          children: [
            if (_isDirty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Descartar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(
                  _stops.isEmpty
                      ? Icons.add_road_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                ),
                label: Text(
                  _stops.isEmpty
                      ? 'Adicione uma parada'
                      : (_isDirty ? 'Aplicar Nova Ordem' : 'Confirmar Rota'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                onPressed: _stops.isEmpty ? null : _confirmRoute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD DE PARADA
// ─────────────────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  const _StopCard({
    super.key,
    required this.stop,
    required this.index,
    required this.total,
    required this.onDelete,
  });

  final DeliveryStop stop;
  final int index;
  final int total;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLast
              ? const Color(0xFF34C759).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Número da parada
          Container(
            width: 52,
            height: 64,
            decoration: BoxDecoration(
              color: isLast
                  ? const Color(0xFF34C759).withValues(alpha: 0.12)
                  : const Color(0xFFE07B1A).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
            ),
            child: Center(
              child: isLast
                  ? const Icon(Icons.flag_rounded,
                      color: Color(0xFF34C759), size: 22)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFFE07B1A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stop.address,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Ações
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF3B30), size: 20),
                onPressed: onDelete,
              ),
              const Icon(Icons.drag_handle_rounded,
                  color: Colors.white24, size: 20),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ESTADO VAZIO
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma parada ainda',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite um endereço ou leia uma\nNota Fiscal para começar',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CÍRCULO DE AÇÃO (botão +)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFE07B1A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE07B1A).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
