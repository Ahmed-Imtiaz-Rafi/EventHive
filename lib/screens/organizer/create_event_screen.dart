
import 'dart:typed_data';

import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/organizer/event_addon_card.dart';
import 'package:event_hive/widgets/organizer/event_basic_info_card.dart';
import 'package:event_hive/widgets/organizer/event_role_price_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // Controllers for the basic event information fields.
  final _nameCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  // Selected event date.
  DateTime? _selectedDate;

  // Image bytes are used because they work on Flutter Web and mobile.
  Uint8List? _pickedImage;

  // Controls the loading state of the Create Event button.
  bool _loading = false;

  // Temporary role list.
  // These will be connected to Supabase later.
  final List<EventRole> _roles = [
    EventRole(
      name: 'Participant',
      price: 500,
    ),
    EventRole(
      name: 'Performer',
      price: 300,
    ),
    EventRole(
      name: 'Guest',
      price: 0,
    ),
  ];

  // Temporary add-on list.
  // These will be connected to Supabase later.
  final List<EventAddon> _addons = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    _orgCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // Validates the required event information before saving.
  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) {
      return 'Please enter event name';
    }

    if (_selectedDate == null) {
      return 'Please select event date';
    }

    if (_venueCtrl.text.trim().isEmpty) {
      return 'Please enter venue';
    }

    if (_orgCtrl.text.trim().isEmpty) {
      return 'Please enter organization';
    }

    if (_capacityCtrl.text.trim().isEmpty) {
      return 'Please enter event capacity';
    }

    final capacity = int.tryParse(
      _capacityCtrl.text.trim(),
    );

    if (capacity == null || capacity <= 0) {
      return 'Please enter a valid capacity';
    }

    return null;
  }

  // Creates the event and uploads its image to Supabase Storage.
  Future<void> _createEvent() async {
    final error = _validate();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      String? imageUrl;

      // Upload the event image if the organizer selected one.
      if (_pickedImage != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}.jpg';

        final filePath = 'events/$fileName';

        await supabase.storage
            .from('event-images')
            .uploadBinary(
          filePath,
          _pickedImage!,
        );

        imageUrl = supabase.storage
            .from('event-images')
            .getPublicUrl(filePath);
      }

      // Save the basic event information in the events table.
      await supabase.from('events').insert({
        'name': _nameCtrl.text.trim(),
        'event_date':
        _selectedDate!.toIso8601String().split('T')[0],
        'venue': _venueCtrl.text.trim(),
        'hosting_org': _orgCtrl.text.trim(),
        'capacity': int.parse(
          _capacityCtrl.text.trim(),
        ),
        'image_url': imageUrl,
        'status': 'active',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Event created successfully!',
          ),
        ),
      );

      // Return to the Organizer Home screen.
      context.go('/organizer/home');
    } catch (e) {
      debugPrint('Error creating event: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create event: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          'Create Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kNavy,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic event information.
            EventBasicInfoCard(
              nameCtrl: _nameCtrl,
              venueCtrl: _venueCtrl,
              orgCtrl: _orgCtrl,
              capacityCtrl: _capacityCtrl,
              selectedDate: _selectedDate,
              pickedImage: _pickedImage,

              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },

              onImagePicked: (image) {
                setState(() {
                  _pickedImage = image;
                });
              },
            ),

            const SizedBox(height: 16),

            // Event roles and prices.
            EventRolePriceCard(
              roles: _roles,

              // Adds a new role.
              onAdd: () async {
                final role = await showRoleDialog(context);

                if (role != null) {
                  setState(() {
                    _roles.add(role);
                  });
                }
              },

              // Edits an existing role.
              onEdit: (index) async {
                final role = await showRoleDialog(
                  context,
                  existing: _roles[index],
                );

                if (role != null) {
                  setState(() {
                    _roles[index] = role;
                  });
                }
              },

              // Deletes an existing role.
              onDelete: (index) {
                setState(() {
                  _roles.removeAt(index);
                });
              },
            ),

            const SizedBox(height: 16),

            // Optional event add-ons.
            EventAddonCard(
              addons: _addons,

              // Adds a new add-on.
              onAdd: () async {
                final addon = await showAddonDialog(context);

                if (addon != null) {
                  setState(() {
                    _addons.add(addon);
                  });
                }
              },

              // Edits an existing add-on.
              onEdit: (index) async {
                final addon = await showAddonDialog(
                  context,
                  existing: _addons[index],
                );

                if (addon != null) {
                  setState(() {
                    _addons[index] = addon;
                  });
                }
              },

              // Deletes an existing add-on.
              onDelete: (index) {
                setState(() {
                  _addons.removeAt(index);
                });
              },
            ),

            const SizedBox(height: 24),

            // Create Event button.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Create Event',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}