import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

class PassengerHomePage extends StatelessWidget {
  const PassengerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RideBookingScreen();
  }
}

class _RideBookingScreen extends StatefulWidget {
  const _RideBookingScreen();

  @override
  State<_RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<_RideBookingScreen> {
  final TextEditingController rideIdCtrl = TextEditingController();
  final TextEditingController passengerIdCtrl = TextEditingController(text: '2');
  bool loading = false;
  String? message;
  Map<String, dynamic>? booking;

  @override
  void dispose() {
    rideIdCtrl.dispose();
    passengerIdCtrl.dispose();
    super.dispose();
  }

  Future<void> createBooking() async {
    final rideId = int.tryParse(rideIdCtrl.text.trim());
    final passengerId = int.tryParse(passengerIdCtrl.text.trim());
    if (rideId == null || passengerId == null) {
      setState(() => message = 'Enter numeric ride ID and passenger ID.');
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rideId': rideId, 'passengerId': passengerId}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        setState(() {
          booking = Map<String, dynamic>.from(data['bookingRequest'] as Map);
          message = 'Booking request sent. Ask the driver to accept.';
        });
      } else {
        setState(() => message = data['message']?.toString() ?? 'Request failed');
      }
    } catch (_) {
      setState(() => message = 'Could not reach backend');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> refreshBooking() async {
    final id = booking?['id'] as int?;
    if (id == null) {
      setState(() => message = 'Create a booking first to refresh its status.');
      return;
    }
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/bookings/$id'));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          booking = Map<String, dynamic>.from(data as Map);
          message = 'Status: ${booking!['status']}';
        });
      } else {
        setState(() => message = data['message']?.toString() ?? 'Failed to load booking');
      }
    } catch (_) {
      setState(() => message = 'Could not reach backend');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openFarePreview() {
    final rideId = int.tryParse(rideIdCtrl.text.trim());
    final b = booking;
    if (rideId == null || b == null) {
      setState(() => message = 'Create a booking first.');
      return;
    }
    if (b['status'] != 'ACCEPTED') {
      setState(() => message = 'Wait for the driver to accept before continuing.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FarePreviewScreen(rideId: rideId, bookingId: b['id'] as int),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger — request ride')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Request to join a ride (uses existing booking API). After the driver accepts, continue to fare, seats, and payment.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: rideIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ride ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passengerIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Passenger user ID',
                  border: OutlineInputBorder(),
                  helperText: 'Must exist in the database (e.g. seed a second user).',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : createBooking,
                icon: const Icon(Icons.send),
                label: const Text('Send booking request'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading ? null : refreshBooking,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh booking status'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: openFarePreview,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Next: fare preview'),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              if (booking != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(const JsonEncoder.withIndent('  ').convert(booking!)),
                  ),
                ),
              ],
            ],
          ),
          if (loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FarePreviewScreen extends StatefulWidget {
  const _FarePreviewScreen({required this.rideId, required this.bookingId});

  final int rideId;
  final int bookingId;

  @override
  State<_FarePreviewScreen> createState() => _FarePreviewScreenState();
}

class _FarePreviewScreenState extends State<_FarePreviewScreen> {
  final TextEditingController pickupLat = TextEditingController();
  final TextEditingController pickupLng = TextEditingController();
  final TextEditingController dropLat = TextEditingController();
  final TextEditingController dropLng = TextEditingController();
  final TextEditingController pickupLabel = TextEditingController(text: 'My pickup');
  final TextEditingController dropLabel = TextEditingController(text: 'My drop-off');

  Map<String, dynamic>? ride;
  Map<String, dynamic>? quote;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  @override
  void dispose() {
    pickupLat.dispose();
    pickupLng.dispose();
    dropLat.dispose();
    dropLng.dispose();
    pickupLabel.dispose();
    dropLabel.dispose();
    super.dispose();
  }

  Future<void> _loadRide() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rides/${widget.rideId}'));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() => error = data['message']?.toString() ?? 'Ride not found');
        return;
      }
      final r = Map<String, dynamic>.from(data as Map);
      setState(() {
        ride = r;
        pickupLat.text = (r['originLat'] ?? '').toString();
        pickupLng.text = (r['originLng'] ?? '').toString();
        dropLat.text = (r['destinationLat'] ?? '').toString();
        dropLng.text = (r['destinationLng'] ?? '').toString();
      });
      await _fetchQuote();
    } catch (_) {
      setState(() => error = 'Network error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchQuote() async {
    setState(() => error = null);
    final plat = double.tryParse(pickupLat.text.trim());
    final plng = double.tryParse(pickupLng.text.trim());
    final dlat = double.tryParse(dropLat.text.trim());
    final dlng = double.tryParse(dropLng.text.trim());
    if (plat == null || plng == null || dlat == null || dlng == null) {
      setState(() => error = 'Enter valid coordinates for pickup and drop-off.');
      return;
    }

    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/fares/preview'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': widget.rideId,
          'pickupLat': plat,
          'pickupLng': plng,
          'dropoffLat': dlat,
          'dropoffLng': dlng,
          'bookingRequestId': widget.bookingId,
          'pickupLabel': pickupLabel.text.trim(),
          'dropoffLabel': dropLabel.text.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        setState(() => error = data['message']?.toString() ?? 'Fare preview failed');
        return;
      }
      setState(() => quote = Map<String, dynamic>.from(data as Map));
    } catch (_) {
      setState(() => error = 'Network error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openSeats() {
    final q = quote;
    if (q == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SeatSelectionScreen(
          rideId: widget.rideId,
          bookingId: widget.bookingId,
          quote: q,
          pickupLat: double.parse(pickupLat.text.trim()),
          pickupLng: double.parse(pickupLng.text.trim()),
          dropLat: double.parse(dropLat.text.trim()),
          dropLng: double.parse(dropLng.text.trim()),
          pickupLabel: pickupLabel.text.trim(),
          dropLabel: dropLabel.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = ride;
    return Scaffold(
      appBar: AppBar(title: const Text('Fare preview')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (r != null) ...[
                Text('${r['origin']} → ${r['destination']}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Ride #${r['id']} · ${r['status']} · Departs ${r['departureTime']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
              const Text('Pickup coordinates', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pickupLat,
                      decoration: const InputDecoration(labelText: 'Lat', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pickupLng,
                      decoration: const InputDecoration(labelText: 'Lng', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Drop-off coordinates', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dropLat,
                      decoration: const InputDecoration(labelText: 'Lat', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: dropLng,
                      decoration: const InputDecoration(labelText: 'Lng', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pickupLabel,
                decoration: const InputDecoration(labelText: 'Pickup label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dropLabel,
                decoration: const InputDecoration(labelText: 'Drop label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : _fetchQuote,
                icon: const Icon(Icons.calculate),
                label: const Text('Update fare estimate'),
              ),
              if (quote != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated total: ${_formatMoney(quote!['totalCents'])} ${quote!['currency']}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Your segment ≈ ${quote!['segmentKm']} km'),
                        const SizedBox(height: 8),
                        Text('Breakdown: ${_prettyBreakdown(quote!['breakdown'])}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openSeats,
                  icon: const Icon(Icons.event_seat),
                  label: const Text('Continue to seat selection'),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
          if (loading)
            const Positioned.fill(
              child: IgnorePointer(child: Center(child: CircularProgressIndicator())),
            ),
        ],
      ),
    );
  }
}

class _SeatSelectionScreen extends StatefulWidget {
  const _SeatSelectionScreen({
    required this.rideId,
    required this.bookingId,
    required this.quote,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.pickupLabel,
    required this.dropLabel,
  });

  final int rideId;
  final int bookingId;
  final Map<String, dynamic> quote;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final String pickupLabel;
  final String dropLabel;

  @override
  State<_SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<_SeatSelectionScreen> {
  List<dynamic> seats = [];
  int? selectedSeat;
  String? lockExpires;
  bool loading = false;
  String? error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshMap();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshMap(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMap({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/rides/${widget.rideId}/seat-map'));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        if (mounted) setState(() => error = data['message']?.toString() ?? 'Failed to load seats');
        return;
      }
      final list = data['seats'] as List<dynamic>? ?? [];
      int? mineSeat;
      String? mineExpiry;
      for (final s in list) {
        final m = Map<String, dynamic>.from(s as Map);
        if (m['bookingRequestId'] == widget.bookingId) {
          mineSeat = m['seatIndex'] as int?;
          mineExpiry = m['expiresAt']?.toString();
          break;
        }
      }
      if (mounted) {
        setState(() {
          seats = list;
          error = null;
          if (mineSeat != null) {
            selectedSeat = mineSeat;
            lockExpires = mineExpiry;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Network error');
    } finally {
      if (!silent && mounted) setState(() => loading = false);
    }
  }

  Future<void> _lock(int seatIndex) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/${widget.bookingId}/seat/lock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'seatIndex': seatIndex}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 201) {
        setState(() => error = data['message']?.toString() ?? 'Could not hold seat');
        await _refreshMap(silent: true);
        return;
      }
      final lock = data['lock'] as Map<String, dynamic>?;
      setState(() {
        selectedSeat = seatIndex;
        lockExpires = lock?['expiresAt']?.toString();
      });
      await _refreshMap(silent: true);
    } catch (_) {
      setState(() => error = 'Network error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _continueConfirm() {
    if (selectedSeat == null) {
      setState(() => error = 'Select and lock a seat first.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BookingConfirmScreen(
          rideId: widget.rideId,
          bookingId: widget.bookingId,
          seatIndex: selectedSeat!,
          quote: widget.quote,
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropLat: widget.dropLat,
          dropLng: widget.dropLng,
          pickupLabel: widget.pickupLabel,
          dropLabel: widget.dropLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seat selection'),
        actions: [
          IconButton(onPressed: loading ? null : () => _refreshMap(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Tap an available seat to hold it for a few minutes. Booked seats are blocked; held seats show a countdown on the map response.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: seats.map((s) {
                  final m = Map<String, dynamic>.from(s as Map);
                  final idx = m['seatIndex'] as int;
                  final state = m['state'] as String? ?? '';
                  final isMine =
                      m['bookingRequestId'] != null && m['bookingRequestId'] == widget.bookingId;
                  Color bg = Colors.grey.shade200;
                  if (state == 'BOOKED') bg = Colors.red.shade100;
                  if (state == 'LOCKED') bg = Colors.amber.shade100;
                  if (idx == selectedSeat && isMine) bg = Colors.green.shade100;

                  return InkWell(
                    onTap: (state == 'AVAILABLE' || (isMine && state == 'LOCKED')) ? () => _lock(idx) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.event_seat, size: 32),
                          const SizedBox(height: 4),
                          Text('Seat $idx', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(state, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (lockExpires != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Your hold expires at: $lockExpires', style: const TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _continueConfirm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Review & confirm booking'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
          if (loading)
            const Positioned.fill(
              child: IgnorePointer(child: Center(child: CircularProgressIndicator())),
            ),
        ],
      ),
    );
  }
}

class _BookingConfirmScreen extends StatefulWidget {
  const _BookingConfirmScreen({
    required this.rideId,
    required this.bookingId,
    required this.seatIndex,
    required this.quote,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.pickupLabel,
    required this.dropLabel,
  });

  final int rideId;
  final int bookingId;
  final int seatIndex;
  final Map<String, dynamic> quote;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final String pickupLabel;
  final String dropLabel;

  @override
  State<_BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<_BookingConfirmScreen> {
  bool loading = false;
  String? error;

  Future<void> _confirm() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/${widget.bookingId}/seat/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seatIndex': widget.seatIndex,
          'pickupLat': widget.pickupLat,
          'pickupLng': widget.pickupLng,
          'dropoffLat': widget.dropLat,
          'dropoffLng': widget.dropLng,
          'pickupLabel': widget.pickupLabel,
          'dropoffLabel': widget.dropLabel,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 201 && res.statusCode != 200) {
        setState(() => error = data['message']?.toString() ?? 'Confirm failed');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _PaymentScreen(
            bookingId: widget.bookingId,
            quote: widget.quote,
            seatIndex: widget.seatIndex,
          ),
        ),
      );
    } catch (_) {
      setState(() => error = 'Network error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Seat ${widget.seatIndex}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Estimated fare: ${_formatMoney(widget.quote['totalCents'])} ${widget.quote['currency']}'),
            const SizedBox(height: 8),
            Text('Pickup: ${widget.pickupLabel}'),
            Text('Drop-off: ${widget.dropLabel}'),
            const Spacer(),
            FilledButton.icon(
              onPressed: loading ? null : _confirm,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Confirm booking'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _PaymentScreen extends StatefulWidget {
  const _PaymentScreen({
    required this.bookingId,
    required this.quote,
    required this.seatIndex,
  });

  final int bookingId;
  final Map<String, dynamic> quote;
  final int seatIndex;

  @override
  State<_PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<_PaymentScreen> {
  bool loading = false;
  String? error;

  Future<void> _pay() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final key = 'pay-${widget.bookingId}-${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payments/mock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingRequestId': widget.bookingId,
          'mockMethod': 'in_app_mock',
          'idempotencyKey': key,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 201 && res.statusCode != 200) {
        setState(() => error = data['message']?.toString() ?? 'Payment failed');
        return;
      }
      if (!mounted) return;
      final payment = data['payment'] as Map<String, dynamic>?;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _PaymentSuccessScreen(
            amountCents: payment?['amountCents'] ?? widget.quote['totalCents'],
            currency: payment?['currency'] ?? widget.quote['currency'],
            seatIndex: widget.seatIndex,
          ),
        ),
      );
    } catch (_) {
      setState(() => error = 'Network error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Total due', style: Theme.of(context).textTheme.titleMedium),
            Text(
              _formatMoney(widget.quote['totalCents']),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('${widget.quote['currency']} · Seat ${widget.seatIndex}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            const Text(
              'This is a mock checkout. No real money moves; the backend records a completed payment for your booking.',
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: loading ? null : _pay,
              icon: const Icon(Icons.lock_open),
              label: const Text('Confirm & pay (mock)'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _PaymentSuccessScreen extends StatelessWidget {
  const _PaymentSuccessScreen({
    required this.amountCents,
    required this.currency,
    required this.seatIndex,
  });

  final dynamic amountCents;
  final dynamic currency;
  final int seatIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All set')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 72),
              const SizedBox(height: 16),
              Text('Payment successful', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Charged ${_formatMoney(amountCents)} $currency for seat $seatIndex.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMoney(dynamic cents) {
  final c = (cents is num) ? cents.toInt() : int.tryParse(cents?.toString() ?? '') ?? 0;
  final major = c / 100.0;
  return major.toStringAsFixed(2);
}

String _prettyBreakdown(dynamic raw) {
  if (raw is! Map) return raw.toString();
  final m = Map<String, dynamic>.from(raw);
  final buf = StringBuffer();
  buf.write('base ${m['baseFareCents']}¢ · ');
  buf.write('distance fare ${m['distanceFareCents']}¢ · ');
  buf.write('occupancy ×${m['occupancyMultiplier']} · ');
  buf.write('peak ×${m['peakMultiplier']}');
  return buf.toString();
}
