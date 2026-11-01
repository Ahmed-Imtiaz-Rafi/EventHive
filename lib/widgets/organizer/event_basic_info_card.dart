
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:event_hive/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

/// Collapsible card for entering the basic information of an event.
/// Image bytes support both Flutter Web and Android.
class EventBasicInfoCard extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController capacityCtrl;

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  final Uint8List? pickedImage;
  final ValueChanged<Uint8List> onImagePicked;

  const EventBasicInfoCard({
    super.key,
    required this.nameCtrl,
    required this.venueCtrl,
    required this.capacityCtrl,
    required this.selectedDate,
    required this.onDateSelected,
    required this.pickedImage,
    required this.onImagePicked,
  });

  @override
  State<EventBasicInfoCard> createState() =>
      _EventBasicInfoCardState();
}

class _EventBasicInfoCardState extends State<EventBasicInfoCard> {
  bool _expanded = true;

  /// Opens the image picker and reads the selected image as bytes.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) widget.onImagePicked(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select image: $e')),
      );
    }
  }

  /// Displays image selection options.
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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: kNavy,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: kNavy,
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Opens the date picker and returns the selected date.
  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = widget.selectedDate;

    final initialDate = selected != null && !selected.isBefore(today)
        ? selected
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kNavy),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      widget.onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Text(
                    'Basic Information',
                    style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: kNavy,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        image: widget.pickedImage != null
                            ? DecorationImage(
                          image: MemoryImage(widget.pickedImage!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: widget.pickedImage == null
                          ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: kTextSub,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to upload event image',
                            style: TextStyle(
                              color: kTextSub,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Banner, poster, or cover photo',
                            style: TextStyle(
                              color: kTextSub,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                          : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Event Name'),
                  _field(
                    controller: widget.nameCtrl,
                    hint: 'e.g. Tech Fest 2027',
                  ),
                  const SizedBox(height: 16),
                  _label('Date'),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: kTextSub,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.selectedDate == null
                                ? 'Select date'
                                : '${widget.selectedDate!.day} / '
                                '${widget.selectedDate!.month} / '
                                '${widget.selectedDate!.year}',
                            style: TextStyle(
                              color: widget.selectedDate == null
                                  ? kTextSub
                                  : kTextMain,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Venue'),
                  _field(
                    controller: widget.venueCtrl,
                    hint: 'e.g. Main Auditorium',
                  ),
                  const SizedBox(height: 16),
                  _label('Capacity'),
                  _field(
                    controller: widget.capacityCtrl,
                    hint: 'e.g. 500',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a label for a form field.
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextMain,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a reusable text field.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: kTextMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextSub, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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
}
