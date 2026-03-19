import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool alwaysShowClear;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? suffixStyle;
  final EdgeInsetsGeometry? suffixIconPadding;
  final double? suffixIconSize;

  const AppInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.textInputAction,
    this.alwaysShowClear = false,
    this.enabledBorderColor,
    this.focusedBorderColor,
    this.contentPadding,
    this.suffixStyle,
    this.suffixIconPadding,
    this.suffixIconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    InputBorder borderFor(Color color) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: color, width: 1),
        );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (ctx, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixText: prefixText,
            suffixText: suffixText,
            suffixStyle: suffixStyle,
            prefixIcon: prefixIcon,
            isDense: true,
            contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.20),
            enabledBorder: borderFor(enabledBorderColor ?? cs.outlineVariant),
            focusedBorder: borderFor((focusedBorderColor ?? cs.primary).withValues(alpha: 0.9)),
            errorBorder: borderFor(theme.colorScheme.error),
            focusedErrorBorder: borderFor(theme.colorScheme.error),
            suffixIcon: (alwaysShowClear || hasText)
                ? Tooltip(
                    message: 'Clear',
                    child: Padding(
                      padding: suffixIconPadding ?? const EdgeInsets.all(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(),
                        child: IconButton(
                          iconSize: suffixIconSize ?? 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => controller.clear(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
