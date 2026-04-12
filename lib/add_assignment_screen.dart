import 'dart:ui';
import 'package:flutter/material.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final titleController = TextEditingController();
  final deadlineController = TextEditingController();
  final dueTimeController = TextEditingController();
  final descriptionController = TextEditingController();
  String selectedPriority = "medium";
  DateTime? selectedDeadline;
  TimeOfDay? selectedDueTime;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    final month = _months[(date.month - 1).clamp(0, 11)];
    return '$month ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Color _priorityColor(String priority) {
    return switch (priority.toLowerCase()) {
      'high' => const Color(0xFFEF5350),
      'low' => const Color(0xFF00C853),
      _ => const Color(0xFFFFB300),
    };
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 10);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDeadline ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Deadline',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F1F1F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDeadline = pickedDate;
      deadlineController.text = _formatDate(pickedDate);
    });
  }

  Future<void> _pickDueTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedDueTime ?? const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F1F1F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    setState(() {
      selectedDueTime = pickedTime;
      dueTimeController.text = _formatTime(pickedTime);
    });
  }

  DateTime? _buildDueDateTime() {
    if (selectedDeadline == null || selectedDueTime == null) return null;
    return DateTime(
      selectedDeadline!.year,
      selectedDeadline!.month,
      selectedDeadline!.day,
      selectedDueTime!.hour,
      selectedDueTime!.minute,
    );
  }

  void addAssignment() {
    final dueDateTime = _buildDueDateTime();

    if (titleController.text.isEmpty || dueDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select due date and due time"),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      "title": titleController.text,
      "deadline": dueDateTime.toIso8601String(),
      "description": descriptionController.text.isEmpty
          ? "No description provided"
          : descriptionController.text,
      "completed": false,
      "priority": selectedPriority,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "New Assignment",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Field
                            _buildInputField(
                              controller: titleController,
                              label: "Assignment Title",
                              icon: Icons.title,
                            ),
                            const SizedBox(height: 18),

                            // Deadline Field
                            _buildInputField(
                              controller: deadlineController,
                              label: "Due Date",
                              icon: Icons.calendar_today,
                              readOnly: true,
                              onTap: _pickDeadline,
                            ),
                            const SizedBox(height: 18),

                            _buildInputField(
                              controller: dueTimeController,
                              label: "Due Time",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: _pickDueTime,
                            ),
                            const SizedBox(height: 18),

                            // Description Field
                            _buildInputField(
                              controller: descriptionController,
                              label: "Description (optional)",
                              icon: Icons.description,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 20),

                            // Priority Selection
                            Text(
                              "Priority Level",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildPriorityButton("Low", "low"),
                                const SizedBox(width: 12),
                                _buildPriorityButton("Medium", "medium"),
                                const SizedBox(width: 12),
                                _buildPriorityButton("High", "high"),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Add Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: addAssignment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.25,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Add Assignment",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : null,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: IconButton(
                onPressed: onTap,
                icon: Icon(icon, color: Colors.white.withOpacity(0.5)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityButton(String label, String value) {
    final isSelected = selectedPriority == value;
    final color = _priorityColor(value);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPriority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.28)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withOpacity(0.55)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    deadlineController.dispose();
    dueTimeController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
