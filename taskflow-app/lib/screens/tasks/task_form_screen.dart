import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  final String? defaultProjectId;

  const TaskFormScreen({super.key, this.task, this.defaultProjectId});

  bool get isEditing => task != null;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String? _selectedProjectId;
  String? _selectedAssignedTo;
  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskStatus _selectedStatus = TaskStatus.todo;
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _selectedProjectId = widget.task?.projectId ?? widget.defaultProjectId;
    _selectedAssignedTo = widget.task?.assignedTo;
    _selectedPriority = widget.task?.priority ?? TaskPriority.medium;
    _selectedStatus = widget.task?.status ?? TaskStatus.todo;
    _dueDate = widget.task?.dueDateTime;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final projProv = context.read<ProjectProvider>();
        final teamProv = context.read<TeamProvider>();
        if (projProv.projects.isEmpty) {
          projProv.fetchProjects().catchError((_) {});
        }
        if (teamProv.employees.isEmpty) {
          teamProv.fetchEmployees().catchError((_) {});
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().user;
    final isEmployee = user?.role == UserRole.employee;

    if (!isEmployee || !widget.isEditing) {
      if (_selectedProjectId == null) {
        setState(() {
          _errorMessage = 'Please select a project.';
        });
        return;
      }
      if (_selectedAssignedTo == null) {
        setState(() {
          _errorMessage = 'Please select an assignee for this task.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final taskProv = context.read<TaskProvider>();

    try {
      if (widget.isEditing) {
        await taskProv.updateTask(
          widget.task!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          projectId: isEmployee ? null : _selectedProjectId,
          assignedTo: isEmployee ? null : _selectedAssignedTo,
          priority: _selectedPriority,
          status: _selectedStatus,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null && widget.task?.hasDueDate == true,
          isEmployeeRole: isEmployee,
        );
      } else {
        await taskProv.createTask(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          projectId: _selectedProjectId!,
          assignedTo: _selectedAssignedTo!,
          priority: _selectedPriority,
          status: _selectedStatus,
          dueDate: _dueDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Task updated successfully'
                  : 'Task created successfully',
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
    final user = context.watch<AuthProvider>().user;
    final projProv = context.watch<ProjectProvider>();
    final teamProv = context.watch<TeamProvider>();
    final isEmployee = user?.role == UserRole.employee;
    final canChangeProjectOrAssignee = !isEmployee || !widget.isEditing;

    final projects = projProv.projects;
    final employees = teamProv.employees;

    if (_selectedProjectId == null && projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
    }
    if (_selectedAssignedTo == null && employees.isNotEmpty) {
      _selectedAssignedTo = employees.first.id;
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Task' : 'New Task')),
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
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'e.g. Implement user login API',
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                validator: Validators.validateTaskTitle,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the requirements and acceptance criteria',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: Validators.validateTaskDescription,
              ),
              const SizedBox(height: 16),
              if (canChangeProjectOrAssignee) ...[
                if (projects.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Project',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: projects.map((p) {
                      return DropdownMenuItem(value: p.id, child: Text(p.name));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProjectId = val;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                if (employees.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAssignedTo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned To',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: employees.map((e) {
                      return DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '${e.name} (${e.role.toUpperCase()} - ${e.email})',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAssignedTo = val;
                      });
                    },
                  ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TaskPriority.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPriority = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<TaskStatus>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                      items: TaskStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDueDate(context),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dueDate != null
                            ? 'Due Date: ${dateFormat.format(_dueDate!)}'
                            : 'Set Due Date (Optional)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear Due Date',
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                    ),
                  ],
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
                        widget.isEditing ? 'Save Changes' : 'Create Task',
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
