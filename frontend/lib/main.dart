import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
      home: const DriverRidePage(),
    );
  }
}

class DriverRidePage extends StatefulWidget {
  const DriverRidePage({super.key});

  @override
  State<DriverRidePage> createState() => _DriverRidePageState();
}

class _DriverRidePageState extends State<DriverRidePage> {
  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController departureController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();

  int? rideId;
  String rideStatus = "NOT_CREATED";
  bool isLoading = false;
  DateTime? selectedDepartureTime;

  LatLng? startLocation;
  LatLng? endLocation;

  final String baseUrl = "http://10.0.2.2:5000/api/rides";

  bool get canEdit => rideStatus == "NOT_CREATED" || rideStatus == "PLANNED";
  bool get canShowCreate => rideId == null;
  bool get canShowPlannedActions => rideId != null && rideStatus == "PLANNED";

  void handleMapTap(TapPosition tapPosition, LatLng point) {
    if (!canEdit || isLoading) return;

    setState(() {
      if (startLocation == null) {
        startLocation = point;
        originController.text =
            "Start: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
      } else if (endLocation == null) {
        endLocation = point;
        destinationController.text =
            "Destination: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
      } else {
        startLocation = point;
        endLocation = null;
        originController.text =
            "Start: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
        destinationController.clear();
      }
    });
  }

  Future<void> pickDepartureDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDepartureTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDepartureTime ?? now),
    );

    if (pickedTime == null) return;

    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      selectedDepartureTime = finalDateTime;
      departureController.text = finalDateTime.toUtc().toIso8601String();
    });
  }

  String formatDepartureForDisplay() {
    if (selectedDepartureTime == null) return "";
    final dt = selectedDepartureTime!;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return "${dt.day}/${dt.month}/${dt.year}  $hour:$minute $suffix";
  }

  Future<void> createRide() async {
    if (!_validateInputs()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driverId": 1,
          "origin": originController.text.trim(),
          "destination": destinationController.text.trim(),
          "departureTime": departureController.text.trim(),
          "seats": int.tryParse(seatsController.text.trim()) ?? 1,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          rideId = data["ride"]["id"];
          rideStatus = data["ride"]["status"];
        });
        showMessage("Ride created successfully");
      } else {
        showMessage(data["message"] ?? "Failed to create ride");
      }
    } catch (e) {
      showMessage("Could not connect to backend");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateRoute() async {
    if (rideId == null) return;
    if (!_validateInputs()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/$rideId/route"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "origin": originController.text.trim(),
          "destination": destinationController.text.trim(),
          "departureTime": departureController.text.trim(),
          "seats": int.tryParse(seatsController.text.trim()) ?? 1,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          rideStatus = data["ride"]["status"];
        });
        showMessage("Route updated successfully");
      } else {
        showMessage(data["message"] ?? "Failed to update route");
      }
    } catch (e) {
      showMessage("Could not connect to backend");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startRide() async {
    if (rideId == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/$rideId/start"),
        headers: {"Content-Type": "application/json"},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          rideStatus = data["ride"]["status"];
        });
        showMessage("Ride started");
      } else {
        showMessage(data["message"] ?? "Failed to start ride");
      }
    } catch (e) {
      showMessage("Could not connect to backend");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> cancelRide() async {
    if (rideId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel ride"),
        content: const Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/$rideId/cancel"),
        headers: {"Content-Type": "application/json"},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          rideStatus = data["ride"]["status"];
        });
        showMessage("Ride cancelled");
      } else {
        showMessage(data["message"] ?? "Failed to cancel ride");
      }
    } catch (e) {
      showMessage("Could not connect to backend");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void resetForm() {
    setState(() {
      rideId = null;
      rideStatus = "NOT_CREATED";
      selectedDepartureTime = null;
      startLocation = null;
      endLocation = null;
      originController.clear();
      destinationController.clear();
      departureController.clear();
      seatsController.clear();
    });
  }

  bool _validateInputs() {
    if (originController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty ||
        departureController.text.trim().isEmpty ||
        seatsController.text.trim().isEmpty) {
      showMessage("Please fill all fields");
      return false;
    }

    final seats = int.tryParse(seatsController.text.trim());
    if (seats == null || seats <= 0) {
      showMessage("Seats must be a positive number");
      return false;
    }

    if (startLocation == null || endLocation == null) {
      showMessage("Please select start and destination on the map");
      return false;
    }

    return true;
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case "PLANNED":
        return Colors.orange;
      case "ONGOING":
        return Colors.green;
      case "CANCELLED":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "PLANNED":
        return Icons.schedule;
      case "ONGOING":
        return Icons.directions_car;
      case "CANCELLED":
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (startLocation != null) {
      markers.add(
        Marker(
          point: startLocation!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_pin, size: 42, color: Colors.green),
        ),
      );
    }

    if (endLocation != null) {
      markers.add(
        Marker(
          point: endLocation!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_pin, size: 42, color: Colors.red),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (startLocation == null || endLocation == null) {
      return [];
    }

    return [
      Polyline(
        points: [startLocation!, endLocation!],
        strokeWidth: 4,
        color: Colors.blue,
      ),
    ];
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    departureController.dispose();
    seatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(rideStatus);

    return Scaffold(
      appBar: AppBar(title: const Text("Driver Module 1"), centerTitle: true),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.map),
                            SizedBox(width: 8),
                            Text(
                              "Select Route on Map",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 300,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: const LatLng(23.8103, 90.4125),
                                initialZoom: 12,
                                onTap: handleMapTap,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  userAgentPackageName: "com.example.frontend",
                                ),
                                PolylineLayer(polylines: _buildPolylines()),
                                MarkerLayer(markers: _buildMarkers()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Tap once for start, tap again for destination. A third tap resets and starts a new route.",
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.route),
                            SizedBox(width: 8),
                            Text(
                              "Route Details",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: originController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: "Origin",
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: destinationController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: "Destination",
                            prefixIcon: Icon(Icons.flag_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: departureController,
                          readOnly: true,
                          onTap: (canEdit && !isLoading)
                              ? pickDepartureDateTime
                              : null,
                          decoration: InputDecoration(
                            labelText: "Departure Time",
                            hintText: "Select departure time",
                            prefixIcon: const Icon(Icons.access_time),
                            suffixIcon: const Icon(Icons.calendar_month),
                            border: const OutlineInputBorder(),
                            helperText: selectedDepartureTime == null
                                ? null
                                : formatDepartureForDisplay(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: seatsController,
                          enabled: canEdit && !isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Seats",
                            prefixIcon: Icon(Icons.event_seat_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(_statusIcon(rideStatus), color: statusColor),
                            const SizedBox(width: 8),
                            const Text(
                              "Ride Session",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _infoRow(
                          "Ride ID",
                          rideId?.toString() ?? "Not created",
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              "Status",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(38),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                rideStatus,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (canShowCreate)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : createRide,
                      icon: const Icon(Icons.add_road),
                      label: const Text("Create Route"),
                    ),
                  ),
                if (canShowPlannedActions) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : updateRoute,
                      icon: const Icon(Icons.edit_road),
                      label: const Text("Change Route"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : startRide,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Start Session"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: isLoading ? null : cancelRide,
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel Ride"),
                    ),
                  ),
                ],
                if (rideStatus == "ONGOING" || rideStatus == "CANCELLED") ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : resetForm,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Create New Ride"),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withAlpha(20),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
