import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../models/team.dart';
import '../../providers/team_provider.dart';

class TeamFormScreen extends StatefulWidget {
  final Team? team;

  const TeamFormScreen({super.key, this.team});

  bool get isEditing => team != null;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _selectedManagerId;
  final Set<String> _selectedMemberIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team?.name ?? '');
    _descController = TextEditingController(
      text: widget.team?.description ?? '',
    );
    _selectedManagerId = widget.team?.managerId;
    if (widget.team != null) {
      _selectedMemberIds.addAll(widget.team!.memberIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManagerId == null) {
      setState(() {
        _errorMessage = 'Please select a manager for this team.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final teamProv = context.read<TeamProvider>();

    try {
      if (widget.isEditing) {
        await teamProv.updateTeam(
          widget.team!.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          managerId: _selectedManagerId,
          memberIds: _selectedMemberIds.toList(),
        );
      } else {
        await teamProv.createTeam(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          managerId: _selectedManagerId!,
          memberIds: _selectedMemberIds.toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Team updated successfully'
                  : 'Team created successfully',
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
    final employees = teamProv.employees;

    final eligibleManagers = employees.where((e) {
      final role = e.role.toLowerCase();
      return role == 'manager' || role == 'admin';
    }).toList();

    if (_selectedManagerId == null && eligibleManagers.isNotEmpty) {
      final firstManager = eligibleManagers
          .where((e) => e.role.toLowerCase() == 'manager')
          .firstOrNull;
      _selectedManagerId = firstManager?.id ?? eligibleManagers.first.id;
    } else if (_selectedManagerId != null &&
        eligibleManagers.isNotEmpty &&
        !eligibleManagers.any((e) => e.id == _selectedManagerId)) {
      _selectedManagerId = eligibleManagers.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Team' : 'New Team')),
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
                  labelText: 'Team Name',
                  hintText: 'Engineering, Design, Marketing...',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                validator: Validators.validateTeamName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is the responsibility of this team?',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: Validators.validateTeamDescription,
              ),
              const SizedBox(height: 16),
              if (employees.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue:
                      eligibleManagers.any((e) => e.id == _selectedManagerId)
                      ? _selectedManagerId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Team Manager',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  hint: eligibleManagers.isEmpty
                      ? const Text('No managers or admins available')
                      : const Text('Select Team Manager'),
                  items: eligibleManagers.map((emp) {
                    return DropdownMenuItem(
                      value: emp.id,
                      child: Text(
                        '${emp.name} (${emp.role.toUpperCase()} - ${emp.email})',
                      ),
                    );
                  }).toList(),
                  onChanged: eligibleManagers.isEmpty
                      ? null
                      : (val) {
                          setState(() {
                            _selectedManagerId = val;
                          });
                        },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select an eligible manager for this team';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Initial Team Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: employees.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      final isSelected = _selectedMemberIds.contains(emp.id);
                      final isManager = emp.id == _selectedManagerId;

                      return CheckboxListTile(
                        title: Text(emp.name),
                        subtitle: Text(
                          '${emp.email} • ${emp.role.toUpperCase()}',
                        ),
                        secondary: isManager
                            ? const Icon(Icons.star, color: Colors.amber)
                            : null,
                        value: isSelected,
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedMemberIds.add(emp.id);
                            } else {
                              _selectedMemberIds.remove(emp.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
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
                        widget.isEditing ? 'Save Changes' : 'Create Team',
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
