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
  late TextEditingController descriptionController;
  late String selectedPriority;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.assignment["title"]);
    deadlineController = TextEditingController(
      text: widget.assignment["deadline"],
    );
    descriptionController = TextEditingController(
      text: widget.assignment["description"],
    );
    selectedPriority = widget.assignment["priority"] ?? "medium";
  }

  void saveChanges() {
    if (titleController.text.isEmpty || deadlineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    widget.onUpdate(widget.index, {
      "title": titleController.text,
      "deadline": deadlineController.text,
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
            backgroundColor: Color(0xFF1A1A2E).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
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
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
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
                  color: Colors.white.withOpacity(0.9),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.assignment["priority"] == "high"
                                      ? const Color(0xFFEF5350).withOpacity(0.3)
                                      : const Color(
                                          0xFFFF9100,
                                        ).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        widget.assignment["priority"] == "high"
                                        ? const Color(
                                            0xFFEF5350,
                                          ).withOpacity(0.5)
                                        : const Color(
                                            0xFFFF9100,
                                          ).withOpacity(0.5),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  "${widget.assignment['priority'].toString().toUpperCase()} PRIORITY",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),

                            if (isEditing) const SizedBox(height: 16),

                            if (isEditing)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEditField(
                                    controller: deadlineController,
                                    label: "Deadline",
                                    icon: Icons.calendar_today,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Priority Level",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
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

                            // Deadline Section
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(width: 12),
                                if (isEditing)
                                  Expanded(
                                    child: _buildEditField(
                                      controller: deadlineController,
                                      label: "Deadline",
                                      icon: null,
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Due Date",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        deadlineController.text,
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
                            const SizedBox(height: 24),

                            // Divider
                            Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            const SizedBox(height: 24),

                            // Description Section
                            Text(
                              "Description",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
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
                                  color: Colors.white.withOpacity(0.7),
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : null,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: icon != null
                  ? Icon(icon, color: Colors.white.withOpacity(0.4))
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
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPriority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(isSelected ? 0.95 : 0.7),
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
    descriptionController.dispose();
    super.dispose();
  }
}
