import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final int eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Event Details Screen'));
  }
}
