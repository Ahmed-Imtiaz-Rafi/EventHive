
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/organizer/event_basic_info_card.dart';
import 'package:event_hive/widgets/organizer/event_role_price_card.dart';
import 'package:event_hive/widgets/organizer/event_addon_card.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _venueCtrl = TextEditingController();
  final TextEditingController _capacityCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Uint8List? _pickedImage;

  bool _loading = false;
  bool _loadingOptions = true;

  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _availableRoleNames = [];

  int? _selectedClubId;
  final Set<int> _selectedCategoryIds = {};

  final List<EventRole> _roles = [];
  final List<EventAddon> _addons = [];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  /// Loads the clubs connected to this user, event categories,
  /// and the registration roles available in Supabase.
  Future<void> _loadDropdownData() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please sign in again.');
      }

      final affiliationRows = await _supabase
          .from('user_affiliation')
          .select('club_id')
          .eq('user_id', user.id);

      final clubIds = affiliationRows
          .map<int>((row) => row['club_id'] as int)
          .toSet()
          .toList();

      List<Map<String, dynamic>> clubs = [];

      if (clubIds.isNotEmpty) {
        final clubRows = await _supabase
            .from('clubs')
            .select('club_id, club_name')
            .inFilter('club_id', clubIds)
            .order('club_name');

        clubs = List<Map<String, dynamic>>.from(clubRows);
      }

      final categoryRows = await _supabase
          .from('event_categories')
          .select('*')
          .order('category_id');

      final roleRows = await _supabase
          .from('registration_roles')
          .select('role_name')
          .order('role_name');

      if (!mounted) return;

      setState(() {
        _clubs = clubs;
        _categories = List<Map<String, dynamic>>.from(categoryRows);

        _availableRoleNames = roleRows
            .map<String>((row) => row['role_name'] as String)
            .toList();

        _selectedClubId =
        _clubs.isNotEmpty ? _clubs.first['club_id'] as int : null;

        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingOptions = false);
      _showMessage('Could not load event options: $e');
    }
  }

  /// Gets a category label from common possible column names.
  String _categoryName(Map<String, dynamic> category) {
    for (final key in ['category_name', 'name', 'title', 'category']) {
      final value = category[key];

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return 'Category ${category['category_id']}';
  }

  /// Converts a selected time to the SQL TIME format.
  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  /// Opens a time picker for the event start or end time.
  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 17, minute: 0)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _displayTime(TimeOfDay? time) {
    if (time == null) return 'Select time';

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  /// Displays a feedback message to the user.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Adds or updates a registration role and its price.
  Future<void> _showRoleDialog({EventRole? existing}) async {
    if (_availableRoleNames.isEmpty) {
      _showMessage('No registration roles are available.');
      return;
    }

    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );

    String? selectedRole = existing?.name;

    if (selectedRole == null ||
        !_availableRoleNames.contains(selectedRole)) {
      selectedRole = _availableRoleNames.first;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Role Price' : 'Edit Role Price',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Registration Role',
                    ),
                    items: _availableRoleNames
                        .map(
                          (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                    )
                        .toList(),
                    onChanged: existing != null
                        ? null
                        : (value) {
                      setDialogState(() => selectedRole = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'e.g. 500',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text);

                    if (selectedRole == null ||
                        price == null ||
                        price < 0) {
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'name': selectedRole,
                      'price': price,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    priceCtrl.dispose();

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final price = result['price'] as double;

    if (existing == null) {
      if (_roles.any((role) => role.name == name)) {
        _showMessage('This registration role is already added.');
        return;
      }

      setState(() => _roles.add(EventRole(name: name, price: price)));
    } else {
      setState(() {
        existing.name = name;
        existing.price = price;
      });
    }
  }

  /// Adds or updates an event add-on.
  Future<void> _showAddonDialog({EventAddon? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null ? 'Add Event Add-on' : 'Edit Event Add-on',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Add-on Name',
                hintText: 'e.g. T-shirt',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'e.g. 500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text);

              if (name.isEmpty || price == null || price < 0) return;

              Navigator.pop(dialogContext, {
                'name': name,
                'price': price,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final price = result['price'] as double;

    if (existing == null) {
      setState(() => _addons.add(EventAddon(name: name, price: price)));
    } else {
      setState(() {
        existing.name = name;
        existing.price = price;
      });
    }
  }

  /// Uploads the selected image and returns its public URL.
  Future<String?> _uploadEventImage() async {
    if (_pickedImage == null) return null;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please sign in again.');
    }

    final path =
        'events/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage.from('event-images').uploadBinary(
      path,
      _pickedImage!,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );

    return _supabase.storage.from('event-images').getPublicUrl(path);
  }

  /// Validates the form, uploads the image, then creates the event
  /// through the database RPC so related records are saved together.
  Future<void> _createEvent() async {
    if (_loading) return;

    final name = _nameCtrl.text.trim();
    final venue = _venueCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim());

    if (name.isEmpty ||
        venue.isEmpty ||
        capacity == null ||
        capacity < 1 ||
        _selectedDate == null) {
      _showMessage(
        'Please enter the event name, date, venue, and valid capacity.',
      );
      return;
    }

    if (_selectedClubId == null) {
      _showMessage('Please select a Hosting Club.');
      return;
    }

    if (_selectedCategoryIds.isEmpty) {
      _showMessage('Please select at least one event category.');
      return;
    }

    if (_startTime != null && _endTime != null) {
      final start = _startTime!.hour * 60 + _startTime!.minute;
      final end = _endTime!.hour * 60 + _endTime!.minute;

      if (end <= start) {
        _showMessage('End time must be after start time.');
        return;
      }
    }

    for (final role in _roles) {
      if (!_availableRoleNames.contains(role.name) || role.price < 0) {
        _showMessage('Please check the registration role prices.');
        return;
      }
    }

    for (final addon in _addons) {
      if (addon.name.trim().isEmpty || addon.price < 0) {
        _showMessage('Please check the add-on details.');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final imageUrl = await _uploadEventImage();

      final eventId = await _supabase.rpc(
        'create_event',
        params: {
          'p_name': name,
          'p_event_date': _selectedDate!.toIso8601String().split('T')[0],
          'p_venue': venue,
          'p_capacity': capacity,
          'p_category_ids': _selectedCategoryIds.toList(),
          'p_club_id': _selectedClubId,
          'p_description': null,
          'p_start_time': _formatTime(_startTime),
          'p_end_time': _formatTime(_endTime),
          'p_image_url': imageUrl,
          'p_department_ids': <int>[],
          'p_accessories': _addons
              .map(
                (addon) => {
              'name': addon.name.trim(),
              'size': 'one_size',
              'price': addon.price,
            },
          )
              .toList(),
          'p_role_prices': _roles
              .map(
                (role) => {
              'role_name': role.name,
              'price': role.price,
            },
          )
              .toList(),
        },
      );

      if (!mounted) return;

      _showMessage('Event created successfully! ID: $eventId');
      context.go('/organizer/home');
    } catch (e) {
      _showMessage('Failed to create event: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Displays the hosting club, categories, and event times.
  Widget _eventOptionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Settings',
            style: TextStyle(
              color: kNavy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hosting Club *',
            style: TextStyle(
              color: kTextMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (_loadingOptions)
            const LinearProgressIndicator()
          else if (_clubs.isEmpty)
            const Text(
              'No affiliated club found. Check your user affiliation.',
              style: TextStyle(color: Colors.red),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedClubId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select Hosting Club',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _clubs.map((club) {
                return DropdownMenuItem<int>(
                  value: club['club_id'] as int,
                  child: Text(club['club_name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedClubId = value);
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'Event Categories *',
            style: TextStyle(
              color: kTextMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_categories.isEmpty && !_loadingOptions)
            const Text('No event categories found.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories.map((category) {
                final id = category['category_id'] as int;
                final selected = _selectedCategoryIds.contains(id);

                return FilterChip(
                  label: Text(_categoryName(category)),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedCategoryIds.add(id);
                      } else {
                        _selectedCategoryIds.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          const Text(
            'Event Time',
            style: TextStyle(
              color: kTextMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: true),
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    'Start: ${_displayTime(_startTime)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: false),
                  icon: const Icon(Icons.access_time_filled),
                  label: Text(
                    'End: ${_displayTime(_endTime)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.white,
        foregroundColor: kNavy,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EventBasicInfoCard(
                nameCtrl: _nameCtrl,
                venueCtrl: _venueCtrl,
                capacityCtrl: _capacityCtrl,
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                },
                pickedImage: _pickedImage,
                onImagePicked: (image) {
                  setState(() => _pickedImage = image);
                },
              ),
              const SizedBox(height: 16),
              _eventOptionsCard(),
              const SizedBox(height: 16),
              EventRolePriceCard(
                roles: _roles,
                onAdd: () => _showRoleDialog(),
                onEdit: (index) {
                  if (index >= 0 && index < _roles.length) {
                    _showRoleDialog(existing: _roles[index]);
                  }
                },
                onDelete: (index) {
                  if (index >= 0 && index < _roles.length) {
                    setState(() => _roles.removeAt(index));
                  }
                },
              ),
              const SizedBox(height: 16),
              EventAddonCard(
                addons: _addons,
                onAdd: () => _showAddonDialog(),
                onEdit: (index) {
                  if (index >= 0 && index < _addons.length) {
                    _showAddonDialog(existing: _addons[index]);
                  }
                },
                onDelete: (index) {
                  if (index >= 0 && index < _addons.length) {
                    setState(() => _addons.removeAt(index));
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                  _loading || _loadingOptions ? null : _createEvent,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
