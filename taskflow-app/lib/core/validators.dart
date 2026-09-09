class Validators {
  static String? required(
    String? value, [
    String message = 'This field is required',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? name(String? value, [int maxLength = 120]) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > maxLength) {
      return 'Name cannot exceed  characters';
    }
    return null;
  }

  static String? validateName(String? value) => name(value);

  static String? title(String? value, [int maxLength = 200]) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.trim().length < 2) {
      return 'Title must be at least 2 characters';
    }
    if (value.trim().length > maxLength) {
      return 'Title cannot exceed  characters';
    }
    return null;
  }

  static String? validateTeamName(String? value) => name(value, 100);
  static String? validateProjectName(String? value) => name(value, 100);
  static String? validateTaskTitle(String? value) => title(value, 100);

  static String? description(
    String? value, [
    int maxLength = 2000,
    int minLength = 0,
  ]) {
    if (minLength > 0 && (value == null || value.trim().length < minLength)) {
      return 'Description must be at least  characters';
    }
    if (value != null && value.length > maxLength) {
      return 'Description cannot exceed  characters';
    }
    return null;
  }

  static String? validateTeamDescription(String? value) =>
      description(value, 500, 5);
  static String? validateProjectDescription(String? value) =>
      description(value, 500, 5);
  static String? validateTaskDescription(String? value) =>
      description(value, 1000, 5);

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validateEmail(String? value) => email(value);

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    return null;
  }

  static String? validatePassword(String? value) => password(value);

  static String? newPassword(String? value, String currentPassword) {
    final basicError = password(value);
    if (basicError != null) return basicError;
    if (value == currentPassword) {
      return 'New password must be different from current password';
    }
    return null;
  }

  static String? validateNewPassword(String? value, String currentPassword) =>
      newPassword(value, currentPassword);

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && end.isBefore(start)) {
      return 'End date must be on or after start date';
    }
    return null;
  }

  static String? validateDateRange(DateTime? start, DateTime? end) =>
      dateRange(start, end);
}
