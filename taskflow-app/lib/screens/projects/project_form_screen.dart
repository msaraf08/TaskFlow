import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../providers/team_provider.dart';

class ProjectFormScreen extends StatefulWidget {
  final Project? project;

  const ProjectFormScreen({super.key, this.project});

  bool get isEditing => project != null;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _selectedTeamId;
  ProjectStatus _selectedStatus = ProjectStatus.planned;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController = TextEditingController(
      text: widget.project?.description ?? '',
    );
    _selectedTeamId = widget.project?.teamId;
    _selectedStatus = widget.project?.status ?? ProjectStatus.planned;
    _startDate = widget.project?.startDateTime;
    _endDate = widget.project?.endDateTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final dateError = Validators.validateDateRange(_startDate, _endDate);
    if (dateError != null) {
      setState(() {
        _errorMessage = dateError;
      });
      return;
    }

    if (_selectedTeamId == null) {
      setState(() {
        _errorMessage = 'Please select a team for this project.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final projProv = context.read<ProjectProvider>();

    try {
      if (widget.isEditing) {
        await projProv.updateProject(
          widget.project!.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          teamId: _selectedTeamId,
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        await projProv.createProject(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          teamId: _selectedTeamId!,
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Project updated successfully'
                  : 'Project created successfully',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamProv = context.watch<TeamProvider>();
    final teams = teamProv.teams;

    if (_selectedTeamId == null && teams.isNotEmpty) {
      _selectedTeamId = teams.first.id;
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Project' : 'New Project'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'e.g. Mobile App Redesign',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                validator: Validators.validateProjectName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is the goal of this project?',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: Validators.validateProjectDescription,
              ),
              const SizedBox(height: 16),
              if (teams.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selectedTeamId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Team',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                  items: teams.map((t) {
                    return DropdownMenuItem(value: t.id, child: Text(t.name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTeamId = val;
                    });
                  },
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProjectStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: ProjectStatus.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _startDate != null
                            ? dateFormat.format(_startDate!)
                            : 'Start Date',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        _endDate != null
                            ? dateFormat.format(_endDate!)
                            : 'End Date',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing ? 'Save Changes' : 'Create Project',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
