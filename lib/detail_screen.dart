import 'dart:ui';
import 'package:flutter/material.dart';

class DetailScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final int index;
  final Function(int, Map<String, dynamic>) onUpdate;
  final Function(int) onDelete;

  const DetailScreen({
    super.key,
    required this.assignment,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController titleController;
  late TextEditingController deadlineController;
  late TextEditingController dueTimeController;
  late TextEditingController descriptionController;
  late String selectedPriority;
  bool isEditing = false;
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

  DateTime? _parseDeadlineValue(dynamic rawDeadline) {
    if (rawDeadline == null) return null;

    final text = rawDeadline.toString().trim();
    if (text.isEmpty) return null;

    final isoParsed = DateTime.tryParse(text);
    if (isoParsed != null) return isoParsed;

    final cleaned = text.replaceAll(',', '');
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final month = monthMap[parts[0].toLowerCase()];
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;

    if (parts.length >= 5) {
      final timeParts = parts[3].split(':');
      final rawHour = int.tryParse(timeParts.first);
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
      final meridiem = parts[4].toUpperCase();

      if (rawHour != null && minute != null) {
        var hour24 = rawHour % 12;
        if (meridiem == 'PM') hour24 += 12;
        return DateTime(year, month, day, hour24, minute);
      }
    }

    return DateTime(year, month, day, 23, 59);
  }

  DateTime _currentDueDateTime() {
    if (selectedDeadline != null && selectedDueTime != null) {
      return DateTime(
        selectedDeadline!.year,
        selectedDeadline!.month,
        selectedDeadline!.day,
        selectedDueTime!.hour,
        selectedDueTime!.minute,
      );
    }

    return _parseDeadlineValue(widget.assignment['deadline']) ?? DateTime.now();
  }

  DateTime _safeInitialDate() {
    if (selectedDeadline != null) return selectedDeadline!;
    return DateTime.now();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _safeInitialDate(),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
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

  @override
  void initState() {
    super.initState();
    final initialDueDateTime = _parseDeadlineValue(
      widget.assignment['deadline'],
    );
    if (initialDueDateTime != null) {
      selectedDeadline = DateTime(
        initialDueDateTime.year,
        initialDueDateTime.month,
        initialDueDateTime.day,
      );
      selectedDueTime = TimeOfDay(
        hour: initialDueDateTime.hour,
        minute: initialDueDateTime.minute,
      );
    }

    titleController = TextEditingController(text: widget.assignment["title"]);
    deadlineController = TextEditingController(
      text: _formatDate(selectedDeadline ?? DateTime.now()),
    );
    dueTimeController = TextEditingController(
      text: _formatTime(
        selectedDueTime ?? const TimeOfDay(hour: 23, minute: 59),
      ),
    );
    descriptionController = TextEditingController(
      text: widget.assignment["description"],
    );
    selectedPriority = widget.assignment["priority"] ?? "medium";
  }

  void saveChanges() {
    final dueDateTime = _currentDueDateTime();

    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    widget.onUpdate(widget.index, {
      "id": widget.assignment["id"],
      "userId": widget.assignment["userId"],
      "createdAt": widget.assignment["createdAt"],
      "updatedAt": widget.assignment["updatedAt"],
      "title": titleController.text,
      "deadline": dueDateTime.toIso8601String(),
      "description": descriptionController.text,
      "completed": widget.assignment["completed"],
      "priority": selectedPriority,
    });

    setState(() => isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Assignment updated successfully"),
        backgroundColor: Color(0xFF00C851),
      ),
    );
  }

  void deleteAssignment() {
    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Color(0xFF1A1A2E).withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            title: const Text(
              "Delete Assignment?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              "This action cannot be undone.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onDelete(widget.index);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 22),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 22),
              onPressed: deleteAssignment,
            ),
          if (isEditing)
            TextButton(
              onPressed: saveChanges,
              child: Text(
                "Save",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            if (isEditing)
                              _buildEditField(
                                controller: titleController,
                                label: "Title",
                                icon: Icons.title,
                              )
                            else
                              Text(
                                titleController.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            const SizedBox(height: 20),

                            if (!isEditing)
                              Builder(
                                builder: (context) {
                                  final priorityText = widget
                                      .assignment['priority']
                                      .toString()
                                      .toLowerCase();
                                  final priorityColor = _priorityColor(
                                    priorityText,
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: priorityColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.flag_rounded,
                                          size: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${widget.assignment['priority'].toString().toUpperCase()} PRIORITY",
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            if (isEditing) const SizedBox(height: 16),

                            if (isEditing)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEditField(
                                    controller: deadlineController,
                                    label: "Due Date",
                                    icon: Icons.calendar_today,
                                    readOnly: true,
                                    onTap: _pickDeadline,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    controller: dueTimeController,
                                    label: "Due Time",
                                    icon: Icons.access_time,
                                    readOnly: true,
                                    onTap: _pickDueTime,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Priority Level",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _buildPriorityButton("Low", "low"),
                                      const SizedBox(width: 10),
                                      _buildPriorityButton("Medium", "medium"),
                                      const SizedBox(width: 10),
                                      _buildPriorityButton("High", "high"),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),

                            // Deadline Section (view mode only)
                            if (!isEditing)
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Due Date & Time",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${deadlineController.text} ${dueTimeController.text}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            if (!isEditing) const SizedBox(height: 24),

                            // Divider
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 24),

                            // Description Section
                            Text(
                              "Description",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (isEditing)
                              _buildEditField(
                                controller: descriptionController,
                                label: "Description",
                                icon: Icons.description,
                                maxLines: 5,
                              )
                            else
                              Text(
                                descriptionController.text,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.6,
                                  letterSpacing: 0.2,
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

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : null,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 15,
              ),
              prefixIcon: icon != null
                  ? IconButton(
                      onPressed: onTap,
                      icon: Icon(
                        icon,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.7),
              fontSize: 13,
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
