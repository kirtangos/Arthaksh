import 'constants.dart';

/// Validation functions for loan planner forms
/// Reusable across different screens and components

String? vRequired(String? value) {
  if (value == null || value.trim().isEmpty) return required;
  return null;
}

String? vMoney(String? value) {
  if (value == null || value.trim().isEmpty) return required;
  final x = double.tryParse(value.replaceAll(',', ''));
  if (x == null || !x.isFinite) return enterValidNumber;
  if (x <= 0) return mustBeGreaterThanZero;
  return null;
}

String? vRate(String? value) {
  if (value == null || value.trim().isEmpty) return required;
  final x = double.tryParse(value.replaceAll(',', ''));
  if (x == null || !x.isFinite) return enterValidNumber;
  if (x < 0) return mustBeGreaterEqualZero;
  if (x > 100) return mustBeLessEqual100;
  return null;
}

String? vTenure(String? value) {
  if (value == null || value.trim().isEmpty) return required;
  final x = double.tryParse(value.replaceAll(',', ''));
  if (x == null || !x.isFinite) return enterValidNumber;
  if (x <= 0) return mustBeGreaterThanZero;
  return null;
}
