class AppValidators {
  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 3) return 'Name must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value))
      return 'Name can only contain letters';
    return null;
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(value))
      return 'Enter a valid email address';
    return null;
  }

  // Phone validation (Pakistani format)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Phone number is required';
    if (!RegExp(r'^\+92[0-9]{10}$').hasMatch(value))
      return 'Use format: +92XXXXXXXXXX';
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]')))
      return 'Must contain at least 1 uppercase letter';
    if (!value.contains(RegExp(r'[a-z]')))
      return 'Must contain at least 1 lowercase letter';
    if (!value.contains(RegExp(r'[0-9]')))
      return 'Must contain at least 1 number';
    if (!value.contains(RegExp(r'[!@#$%^&*]')))
      return 'Must contain special character (!@#\$%^&*)';
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  // Age validation
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) return 'Age is required';
    final age = int.tryParse(value);
    if (age == null) return 'Enter a valid age';
    if (age < 1 || age > 120) return 'Age must be between 1 and 120';
    return null;
  }
}
