import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
      ),
      body: const Center(
        child: Text(
          'Calendar',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}