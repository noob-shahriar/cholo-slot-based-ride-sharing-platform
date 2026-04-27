import 'package:flutter/material.dart';

class RideSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> summary;

  const RideSummaryScreen({Key? key, required this.summary}) : super(key: key);

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFF98825);
    const brandBlue  = Color(0xFF1565C0);

    final passengers = List<Map<String, dynamic>>.from(
      summary['passengers'] ?? [],
    );
    final double? distKm   = (summary['routeDistanceKm'] as num?)?.toDouble();
    final double? durMin   = (summary['routeDurationMin'] as num?)?.toDouble();
    final int passCount    = summary['passengersCarried'] ?? passengers.length;
    final int totalSeats   = summary['totalSeats'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        title: const Text(
          'Ride Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Completion Banner ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: brandBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 56),
                  const SizedBox(height: 8),
                  const Text(
                    'Ride Completed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ride #${summary['rideId'] ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Route Card ────────────────────────────────────────────
            _SummaryCard(
              title: 'Route Details',
              icon: Icons.route,
              iconColor: brandOrange,
              children: [
                _InfoRow(
                  icon: Icons.radio_button_checked,
                  iconColor: Colors.green,
                  label: 'From',
                  value: summary['origin'] ?? 'N/A',
                ),
                const Divider(height: 16),
                _InfoRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'To',
                  value: summary['destination'] ?? 'N/A',
                ),
                if (distKm != null) ...[
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.straighten,
                    iconColor: brandBlue,
                    label: 'Distance',
                    value: '${distKm.toStringAsFixed(1)} km',
                  ),
                ],
                if (durMin != null) ...[
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.timer,
                    iconColor: brandBlue,
                    label: 'Duration',
                    value: '${durMin.toStringAsFixed(0)} min',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Time Card ─────────────────────────────────────────────
            _SummaryCard(
              title: 'Time Info',
              icon: Icons.schedule,
              iconColor: brandBlue,
              children: [
                _InfoRow(
                  icon: Icons.departure_board,
                  iconColor: Colors.orange,
                  label: 'Departed',
                  value: _formatDateTime(summary['departureTime']),
                ),
                const Divider(height: 16),
                _InfoRow(
                  icon: Icons.flag,
                  iconColor: Colors.green,
                  label: 'Completed',
                  value: _formatDateTime(summary['completedAt']),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Passengers Card ───────────────────────────────────────
            _SummaryCard(
              title: 'Passengers',
              icon: Icons.people,
              iconColor: brandOrange,
              children: [
                Row(
                  children: [
                    _StatChip(
                      label: 'Carried',
                      value: '$passCount',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Total Seats',
                      value: '$totalSeats',
                      color: brandBlue,
                    ),
                  ],
                ),
                if (passengers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  ...passengers.map(
                    (p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: brandOrange.withOpacity(0.15),
                        child: Text(
                          (p['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: brandOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(p['email'] ?? ''),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'No passengers on this ride.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 28),

            // ── Close Button ──────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 2),
            SizedBox(
              width: 260,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
          Text(label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
