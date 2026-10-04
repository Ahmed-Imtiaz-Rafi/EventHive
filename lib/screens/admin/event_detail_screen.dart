import 'package:flutter/material.dart';

class EventDetailScreen extends StatelessWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('EventDetailScreen'));
  }
}
