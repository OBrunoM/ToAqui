import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/contact_provider.dart';
import '../repositories/emergency_repository.dart';
import '../services/location_service.dart';
import 'app_snackbar.dart';

export '../services/location_service.dart' show LocationFetcher;

class EmergencyButton extends ConsumerStatefulWidget {
  final LocationFetcher fetchLocation;
  final Duration holdDuration;

  const EmergencyButton({
    super.key,
    this.fetchLocation = fetchCurrentLocation,
    this.holdDuration = const Duration(seconds: 3),
  });

  @override
  ConsumerState<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends ConsumerState<EmergencyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: widget.holdDuration);
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _trigger();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_sending) return;
    _holdController.forward(from: 0);
  }

  void _cancelHold() {
    if (_holdController.isAnimating) {
      _holdController.stop();
      _holdController.value = 0;
    }
  }

  Future<void> _trigger() async {
    final contacts = ref.read(contactsStreamProvider).value ?? [];
    final linked = contacts.where((c) => c.linkedUid != null).toList();
    if (linked.isEmpty) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Você ainda não tem familiares vinculados. Convide alguém na aba Família primeiro.',
      );
      return;
    }

    setState(() => _sending = true);

    Position? position;
    try {
      position = await widget.fetchLocation();
      await EmergencyRepository(ref.read(firestoreProvider)).recordEmergency(
        ownerUid: ref.read(currentUidProvider),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      if (!mounted) return;
      AppSnackbar.showError(context, 'Não foi possível enviar o alerta. Tente de novo.');
      return;
    }

    // Reset the sending indicator before showing the confirmation dialog: the
    // dialog awaits user dismissal (which may never happen synchronously in
    // tests), and an indeterminate spinner left running would never let
    // `pumpAndSettle` (or the real UI) settle.
    if (mounted) setState(() => _sending = false);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alerta enviado'),
        content: Text(
          position != null
              ? 'Sua localização foi enviada para ${linked.length} familiar(es).'
              : 'Alerta enviado para ${linked.length} familiar(es), sem localização.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coral = Theme.of(context).colorScheme.secondary;

    // Watching here (rather than only `ref.read`-ing inside `_trigger`) subscribes
    // to the contacts stream as soon as the button is built, so the linked-contacts
    // list is already loaded by the time the user completes a hold.
    ref.watch(contactsStreamProvider);

    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 4,
                  color: coral,
                  backgroundColor: coral.withOpacity(0.2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: coral),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sos, color: Colors.white, size: 32),
              ),
            ],
          );
        },
      ),
    );
  }
}
