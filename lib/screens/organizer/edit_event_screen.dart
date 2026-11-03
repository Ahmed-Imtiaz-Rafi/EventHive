import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/organizer/event_addon_card.dart';
import 'package:event_hive/widgets/organizer/event_role_price_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edit Event screen.
/// Loads existing event data into the form, lets the organizer edit it,
/// then calls the update_event() RPC — the only permitted write path
/// per the schema's security rules.
class EditEventScreen extends StatefulWidget {
  final String eventId; // UUID of the event to edit
  const EditEventScreen({super.key, required this.eventId});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _supabase = Supabase.instance.client;

  // Basic info controllers — pre-filled once the event loads
  final _nameCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // New image bytes selected by the user (null = keep existing image)
  Uint8List? _newImageBytes;
  // The existing image URL already stored in the database
  String? _existingImageUrl;

  // Dropdown data loaded from Supabase
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _availableRoleNames = [];

  int? _selectedClubId;
  final Set<int> _selectedCategoryIds = {};

  // Roles and add-ons — pre-filled from the database
  final List<EventRole> _roles = [];
  final List<EventAddon> _addons = [];

  bool _loadingData = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────

  /// Loads the event row, its existing roles/add-ons, and the dropdown
  /// options (clubs, categories, registration roles) in parallel.
  Future<void> _loadAll() async {
    setState(() {
      _loadingData = true;
      _loadError = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in.');

      // Run all fetches in parallel for speed.
      // Typed as Future<dynamic> so Dart doesn't widen to List<Object>.
      final List<Future<dynamic>> queries = [
        _supabase
            .from('events')
            .select()
            .eq('event_id', widget.eventId)
            .single(),

        _supabase
            .from('event_role_price')
            .select()
            .eq('event_id', widget.eventId),

        _supabase
            .from('event_accessories')
            .select()
            .eq('event_id', widget.eventId),

        _supabase
            .from('event_category_map')
            .select('category_id')
            .eq('event_id', widget.eventId),

        _supabase
            .from('user_affiliation')
            .select('club_id')
            .eq('user_id', userId),

        _supabase
            .from('event_categories')
            .select()
            .order('category_id'),

        _supabase
            .from('registration_roles')
            .select('role_name')
            .order('role_name'),
      ];

      final results = await Future.wait<dynamic>(queries);

      final event = Map<String, dynamic>.from(results[0] as Map);
      final roleRows = results[1] as List;
      final addonRows = results[2] as List;
      final catMapRows = results[3] as List;
      final affiliationRows = results[4] as List;
      final categoryRows = results[5] as List;
      final roleNameRows = results[6] as List;

      // Load affiliated clubs
      final clubIds = affiliationRows.map((r) => r['club_id'] as int).toList();
      List<Map<String, dynamic>> clubs = [];
      if (clubIds.isNotEmpty) {
        final clubRows = await _supabase
            .from('clubs')
            .select('club_id, club_name')
            .inFilter('club_id', clubIds)
            .order('club_name');
        clubs = List<Map<String, dynamic>>.from(clubRows);
      }

      if (!mounted) return;

      // Pre-fill basic info
      _nameCtrl.text = (event['name'] ?? '').toString();
      _venueCtrl.text = (event['venue'] ?? '').toString();
      _capacityCtrl.text = (event['capacity'] ?? '').toString();
      _existingImageUrl = (event['image_url'] ?? '').toString().trim();
      if (_existingImageUrl!.isEmpty) _existingImageUrl = null;

      // Parse event_date
      final dateStr = (event['event_date'] ?? '').toString();
      if (dateStr.isNotEmpty) {
        _selectedDate = DateTime.tryParse(dateStr);
      }

      // Parse start / end time strings like "09:00:00"
      _startTime = _parseTime((event['start_time'] ?? '').toString());
      _endTime = _parseTime((event['end_time'] ?? '').toString());

      // Pre-select the event's club only when it exists in the
      // organizer's available club list. This prevents an invalid dropdown value.
      final currentClubId = (event['club_id'] as num?)?.toInt();
      final availableClubIds = clubs
          .map((club) => (club['club_id'] as num).toInt())
          .toSet();

      _selectedClubId = availableClubIds.contains(currentClubId)
          ? currentClubId
          : null;

      // Pre-select categories
      for (final row in catMapRows) {
        _selectedCategoryIds.add(row['category_id'] as int);
      }

      // Pre-fill roles
      for (final row in roleRows) {
        _roles.add(EventRole(
          name: (row['role_name'] ?? '').toString(),
          price: (row['price'] as num?)?.toDouble() ?? 0,
        ));
      }

      // Pre-fill add-ons (one row per (name, size) — show name + price)
      final seenAddons = <String>{};
      for (final row in addonRows) {
        final addonName = (row['accessory_name'] ?? '').toString();
        if (!seenAddons.contains(addonName)) {
          seenAddons.add(addonName);
          _addons.add(EventAddon(
            name: addonName,
            price: (row['price'] as num?)?.toDouble() ?? 0,
          ));
        }
      }

      setState(() {
        _clubs = clubs;
        _categories = List<Map<String, dynamic>>.from(categoryRows);
        _availableRoleNames = roleNameRows
            .map<String>((r) => r['role_name'].toString())
            .toList();
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingData = false;
      });
    }
  }

  /// Parses a PostgreSQL TIME string like "09:30:00" into a TimeOfDay.
  TimeOfDay? _parseTime(String raw) {
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _displayTime(TimeOfDay? t) {
    if (t == null) return 'Select time';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  String _categoryName(Map<String, dynamic> c) {
    for (final k in ['category_name', 'name', 'title']) {
      final v = c[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return 'Category ${c['category_id']}';
  }

  // ─────────────────────────────────────────────────────────
  // IMAGE PICKING
  // ─────────────────────────────────────────────────────────

  /// Opens the image picker. If a new image is selected, it replaces the
  /// existing one on save. If not picked, the original URL is kept.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) setState(() => _newImageBytes = bytes);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to select image: $e');
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kNavy),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: kNavy),
              title: const Text('Take a Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ROLE / ADDON DIALOGS  (same pattern as CreateEventScreen)
  // ─────────────────────────────────────────────────────────

  Future<void> _showRoleDialog({EventRole? existing}) async {
    if (_availableRoleNames.isEmpty) {
      _showMessage('No registration roles available.');
      return;
    }

    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );
    String? selectedRole = existing?.name;
    if (selectedRole == null || !_availableRoleNames.contains(selectedRole)) {
      selectedRole = _availableRoleNames.first;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Add Role Price' : 'Edit Role Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Registration Role'),
                items: _availableRoleNames
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                // Disable role name change when editing (schema doesn't allow it)
                onChanged: existing != null
                    ? null
                    : (v) => setDialog(() => selectedRole = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(labelText: 'Price', hintText: 'e.g. 500'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text);
                if (selectedRole == null || price == null || price < 0) return;
                Navigator.pop(ctx, {'name': selectedRole, 'price': price});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    priceCtrl.dispose();
    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final price = result['price'] as double;

    if (existing == null) {
      if (_roles.any((r) => r.name == name)) {
        _showMessage('This role is already added.');
        return;
      }
      setState(() => _roles.add(EventRole(name: name, price: price)));
    } else {
      setState(() { existing.name = name; existing.price = price; });
    }
  }

  Future<void> _showAddonDialog({EventAddon? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Add-on' : 'Edit Add-on'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Add-on Name', hintText: 'e.g. T-shirt'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                  labelText: 'Price', hintText: 'e.g. 500'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              final p = double.tryParse(priceCtrl.text);
              if (n.isEmpty || p == null || p < 0) return;
              Navigator.pop(ctx, {'name': n, 'price': p});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    if (result == null || !mounted) return;

    if (existing == null) {
      setState(() => _addons.add(
          EventAddon(name: result['name'], price: result['price'])));
    } else {
      setState(() { existing.name = result['name']; existing.price = result['price']; });
    }
  }

  // ─────────────────────────────────────────────────────────
  // SAVE (calls update_event() RPC)
  // ─────────────────────────────────────────────────────────

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Validates the form, optionally uploads a new image, then calls
  /// the update_event() RPC. We never UPDATE the events table directly
  /// because the schema's RLS revokes that permission and the RPC
  /// handles roles, add-ons, and categories atomically in one transaction.
  Future<void> _saveEvent() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final venue = _venueCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim());

    if (name.isEmpty || venue.isEmpty || capacity == null || capacity < 1) {
      _showMessage('Please fill in name, venue, and a valid capacity.');
      return;
    }
    if (_selectedDate == null) {
      _showMessage('Please select a date.');
      return;
    }
    if (_selectedClubId == null) {
      _showMessage('Please select a hosting club.');
      return;
    }
    if (_selectedCategoryIds.isEmpty) {
      _showMessage('Please select at least one category.');
      return;
    }
    if (_roles.isEmpty) {
      _showMessage('Add at least one registration role.');
      return;
    }
    if (_startTime != null && _endTime != null) {
      final s = _startTime!.hour * 60 + _startTime!.minute;
      final e = _endTime!.hour * 60 + _endTime!.minute;
      if (e <= s) {
        _showMessage('End time must be after start time.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      // Upload new image if selected; otherwise keep the existing URL.
      String? imageUrl = _existingImageUrl;
      if (_newImageBytes != null) {
        final user = _supabase.auth.currentUser!;
        final path =
            'events/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('event-images').uploadBinary(
          path,
          _newImageBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        imageUrl = _supabase.storage.from('event-images').getPublicUrl(path);
      }

      // Build the accessories JSON — schema expects name, size, price.
      // We default size to 'one_size' since the edit form doesn't show sizes.
      final accessories = _addons
          .map((a) => {'name': a.name.trim(), 'size': 'one_size', 'price': a.price})
          .toList();

      // Build the role prices JSON — schema expects role_name and price.
      final rolePrices = _roles
          .map((r) => {'role_name': r.name, 'price': r.price})
          .toList();

      /// Calls the update_event() SECURITY DEFINER RPC.
      /// This is the only permitted way to update an event per the schema.
      /// It validates authority, updates the events table, and replaces
      /// categories, department restrictions, accessories, and role prices
      /// atomically in a single transaction.
      await _supabase.rpc('update_event', params: {
        'p_event_id': widget.eventId,
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
        'p_accessories': accessories,
        'p_role_prices': rolePrices,
      });

      if (!mounted) return;
      _showMessage('Event updated successfully!');
      context.go('/organizer/event/${widget.eventId}');
    } catch (e) {
      _showMessage('Failed to update event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text(
          'Edit Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/event/${widget.eventId}'),
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildError()
          : _buildForm(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text('Could not load event.\n$_loadError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSub)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAll,
            style: ElevatedButton.styleFrom(backgroundColor: kNavy),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _basicInfoCard(),
          const SizedBox(height: 16),
          _settingsCard(),
          const SizedBox(height: 16),
          EventRolePriceCard(
            roles: _roles,
            onAdd: () => _showRoleDialog(),
            onEdit: (i) { if (i < _roles.length) _showRoleDialog(existing: _roles[i]); },
            onDelete: (i) { if (i < _roles.length) setState(() => _roles.removeAt(i)); },
          ),
          const SizedBox(height: 16),
          EventAddonCard(
            addons: _addons,
            onAdd: () => _showAddonDialog(),
            onEdit: (i) { if (i < _addons.length) _showAddonDialog(existing: _addons[i]); },
            onDelete: (i) { if (i < _addons.length) setState(() => _addons.removeAt(i)); },
          ),
          const SizedBox(height: 28),
          // Cancel + Update buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => context.go('/organizer/event/${widget.eventId}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: kNavy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Update Event',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Basic info card (image, name, date, venue, capacity)
  Widget _basicInfoCard() {
    final showExisting = _newImageBytes == null && _existingImageUrl != null;

    return _card(
      title: 'Basic Information',
      children: [
        // Image picker
        _label('Event Image'),
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
              image: _newImageBytes != null
                  ? DecorationImage(
                  image: MemoryImage(_newImageBytes!), fit: BoxFit.cover)
                  : showExisting
                  ? DecorationImage(
                  image: NetworkImage(_existingImageUrl!),
                  fit: BoxFit.cover)
                  : null,
            ),
            child: (_newImageBytes != null || showExisting)
                ? Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Change',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 36, color: kTextSub),
                SizedBox(height: 8),
                Text('Tap to upload event image',
                    style: TextStyle(color: kTextSub, fontSize: 13)),
                SizedBox(height: 4),
                Text('Optional — banner, poster, or cover photo',
                    style: TextStyle(color: kTextSub, fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Event Name'),
        _textField(_nameCtrl, 'e.g. Tech Fest 2027'),
        const SizedBox(height: 16),
        _label('Date'),
        // Date picker trigger — shows selected date or a placeholder
        GestureDetector(
          onTap: () async {
            final today = DateUtils.dateOnly(DateTime.now());
            final init = _selectedDate != null &&
                !_selectedDate!.isBefore(today)
                ? _selectedDate!
                : today;
            final picked = await showDatePicker(
              context: context,
              initialDate: init,
              firstDate: today,
              lastDate: DateTime(2100),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: kNavy),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    color: kTextSub, size: 18),
                const SizedBox(width: 10),
                Text(
                  _selectedDate == null
                      ? 'Select date'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? kTextSub : kTextMain,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Venue'),
        _textField(_venueCtrl, 'e.g. Main Auditorium'),
        const SizedBox(height: 16),
        _label('Capacity'),
        _textField(_capacityCtrl, 'e.g. 500',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      ],
    );
  }

  // ── Settings card (club, categories, time)
  Widget _settingsCard() {
    return _card(
      title: 'Event Settings',
      children: [
        _label('Hosting Club'),
        if (_clubs.isEmpty)
          const Text('No affiliated club found.',
              style: TextStyle(color: Colors.redAccent))
        else
          DropdownButtonFormField<int>(
            // The selected value must match exactly one item in the list.
            value: _clubs.any(
                  (club) => (club['club_id'] as num).toInt() == _selectedClubId,
            )
                ? _selectedClubId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select hosting club',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Use a map keyed by club_id to prevent duplicate dropdown values.
            items: {
              for (final club in _clubs)
                (club['club_id'] as num).toInt(): club,
            }.values.map((club) {
              return DropdownMenuItem<int>(
                value: (club['club_id'] as num).toInt(),
                child: Text(club['club_name'].toString()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedClubId = value);
            },
          ),
        const SizedBox(height: 16),
        _label('Event Categories'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _categories.map((cat) {
            final id = cat['category_id'] as int;
            final sel = _selectedCategoryIds.contains(id);
            return FilterChip(
              label: Text(_categoryName(cat)),
              selected: sel,
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedCategoryIds.add(id);
                } else {
                  _selectedCategoryIds.remove(id);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _label('Event Time'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (t != null) setState(() => _startTime = t);
                },
                icon: const Icon(Icons.access_time),
                label: Text('Start: ${_displayTime(_startTime)}',
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
                  );
                  if (t != null) setState(() => _endTime = t);
                },
                icon: const Icon(Icons.access_time_filled),
                label: Text('End: ${_displayTime(_endTime)}',
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable card wrapper
  Widget _card({required String title, required List<Widget> children}) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextMain)),
  );

  Widget _textField(
      TextEditingController ctrl,
      String hint, {
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
      }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 14, color: kTextMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub, fontSize: 14),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kNavy, width: 1.5),
          ),
        ),
      );
}
