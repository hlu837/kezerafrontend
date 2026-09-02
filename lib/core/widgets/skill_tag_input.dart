import 'package:flutter/material.dart';

/// Type-and-Enter chip input for free-form tags (skills, in this app's
/// case). Mirrors the web backoffice's `SkillTagInput.tsx`: submitting the
/// text field adds a chip and clears the field; tapping a chip's delete
/// icon removes it. Case-insensitive de-duplication, same as the web
/// version, so "Forklift" and "forklift" don't both get added.
class SkillTagInput extends StatefulWidget {
  const SkillTagInput({
    super.key,
    required this.label,
    required this.skills,
    required this.onChanged,
    this.hintText,
  });

  final String label;
  final List<String> skills;
  final ValueChanged<List<String>> onChanged;
  final String? hintText;

  @override
  State<SkillTagInput> createState() => _SkillTagInputState();
}

class _SkillTagInputState extends State<SkillTagInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addFromField() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final alreadyPresent = widget.skills
        .any((skill) => skill.toLowerCase() == value.toLowerCase());
    if (!alreadyPresent) {
      widget.onChanged([...widget.skills, value]);
    }
    _controller.clear();
  }

  void _remove(String skill) {
    widget.onChanged(widget.skills.where((s) => s != skill).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add skill',
              onPressed: _addFromField,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addFromField(),
        ),
        if (widget.skills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in widget.skills)
                Chip(
                  label: Text(skill),
                  onDeleted: () => _remove(skill),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
