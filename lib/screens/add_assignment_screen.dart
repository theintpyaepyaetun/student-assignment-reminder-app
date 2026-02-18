import 'package:flutter/material.dart';

class AddAssignmentScreen extends StatelessWidget {
  const AddAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Assignment"),
      ),
      body: const Center(
        child: Text("Add Assignment Screen"),
      ),
    );
  }
}
