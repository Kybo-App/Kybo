import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_repository.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  final AdminRepository _repo = AdminRepository();
  bool _maintenanceEnabled = false;
  bool _isLoading = true;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      bool status = await _repo.getMaintenanceStatus();
      if (mounted) setState(() => _maintenanceEnabled = status);
    } catch (e) {
      debugPrint("Error loading config: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMaintenance(bool value) async {
    setState(() => _isLoading = true);
    try {
      await _repo.setMaintenanceStatus(value);
      setState(() => _maintenanceEnabled = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? "Maintenance ENABLED" : "Maintenance DISABLED",
            ),
            backgroundColor: value ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  Future<void> _scheduleMaintenance() async {
    if (_selectedDate == null || _selectedTime == null) return;

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Schedule"),
            content: Text(
              "This will send a notification to ALL users saying maintenance will start at:\n\n${DateFormat('yyyy-MM-dd HH:mm').format(dateTime)}",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm & Notify"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await _repo.scheduleMaintenance(dateTime, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Maintenance Scheduled & Notification Sent!"),
              backgroundColor: Colors.blue,
            ),
          );
          setState(() {
            _selectedDate = null;
            _selectedTime = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text(
            "System Configuration",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // --- MANUAL TOGGLE ---
          Card(
            color: _maintenanceEnabled
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: SwitchListTile(
              title: const Text("Maintenance Mode (Immediate)"),
              subtitle: Text(
                _maintenanceEnabled
                    ? "App is locked for users"
                    : "App is active",
              ),
              value: _maintenanceEnabled,
              onChanged: _toggleMaintenance,
              activeColor: Colors.red,
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // --- SCHEDULE SECTION ---
          const Text(
            "Schedule Maintenance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pick a date and time to warn users about upcoming maintenance.",
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate == null
                              ? "Select Date & Time"
                              : "${DateFormat('dd/MM/yyyy').format(_selectedDate!)} at ${_selectedTime!.format(context)}",
                        ),
                      ),
                      const Spacer(),
                      if (_selectedDate != null)
                        FilledButton.icon(
                          onPressed: _scheduleMaintenance,
                          icon: const Icon(Icons.send),
                          label: const Text("Schedule & Notify"),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
