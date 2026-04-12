import 'package:flutter/material.dart';

import 'features/driver/driver_ride_page.dart';
import 'features/passenger/passenger_home_page.dart';

void main() {
  runApp(const CholoApp());
}

class CholoApp extends StatelessWidget {
  const CholoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cholo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const ModePickerPage(),
    );
  }
}

class ModePickerPage extends StatelessWidget {
  const ModePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cholo'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Choose a flow',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Driver: create route, manage bookings. Passenger: fare preview, seats, mock payment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DriverRidePage()),
                );
              },
              icon: const Icon(Icons.drive_eta),
              label: const Text('Driver — route & bookings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PassengerHomePage()),
                );
              },
              icon: const Icon(Icons.airline_seat_recline_normal),
              label: const Text('Passenger — fare, seats & pay'),
            ),
          ],
        ),
      ),
    );
  }
}
