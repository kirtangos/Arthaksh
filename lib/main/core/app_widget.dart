import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arthaksh/ui/app_theme.dart';
import 'package:arthaksh/ui/theme_extensions.dart';
import 'root_decider.dart';
import '../screens/settings_screen.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Global brand accent provided by controller (overridable via Themes screen)
    final themeCtrl = AppThemeController.instance;
    return ValueListenableBuilder<Color>(
      valueListenable: themeCtrl.seedColor,
      builder: (context, kAccent, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeCtrl.themeMode,
          builder: (context, mode, __) {
            return MaterialApp(
              title: 'Arthaksh',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: kAccent,
                brightness: Brightness.light,
                textTheme: GoogleFonts.poppinsTextTheme(),
                dividerColor:
                    ColorScheme.fromSeed(seedColor: kAccent).outlineVariant,
                extensions: const [
                  SuccessColors(
                    success: Color(0xFF16A34A), // modern green
                    onSuccess: Colors.white,
                  ),
                ],
                // 70% neutral/teal-light surfaces
                scaffoldBackgroundColor: const Color(0xFFFFFFFF),
                appBarTheme: AppBarTheme(
                  centerTitle: false,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF111827), // dark gray typography
                  iconTheme: IconThemeData(color: kAccent),
                  titleTextStyle: TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: ButtonStyle(
                    iconSize: const WidgetStatePropertyAll(24),
                    foregroundColor: WidgetStatePropertyAll(kAccent),
                  ),
                ),
                cardTheme: const CardThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  elevation: 1,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6), // light gray fields
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kAccent, width: 1.4),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF111827)),
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  prefixIconColor: const Color(0xFF6B7280),
                  suffixIconColor: const Color(0xFF6B7280),
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: kAccent,
                  selectionHandleColor: kAccent,
                  selectionColor: kAccent.withValues(alpha: 0.25),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF00897b),
                  brightness: Brightness.dark,
                ).copyWith(
                  // Teal-tinted charcoal base colors
                  primary: const Color(0xFF00897b),
                  surface:
                      const Color(0xFF1A1A1A), // Deep charcoal with teal hint
                  surfaceContainer: const Color(0xFF1F1F1F), // Layer 1
                  surfaceContainerLow: const Color(0xFF242424), // Layer 2
                  surfaceContainerHigh: const Color(0xFF2A2A2A), // Layer 3
                  surfaceContainerHighest: const Color(0xFF303030), // Layer 4
                  onSurface: const Color(0xFFB0C4C7), // Muted cyan/grey text
                  onSurfaceVariant:
                      const Color(0xFF809598), // Softer variant text
                  outline:
                      const Color(0xFF405053), // Subtle teal-tinted borders
                  outlineVariant: const Color(0xFF354548), // Even more subtle
                  primaryContainer:
                      const Color(0xFF003D38), // Dark teal container
                  onPrimaryContainer: const Color(0xFFA5D6D1), // Soft cyan text
                  scrim: const Color(0xFF0A1416), // Dark teal overlay
                ),
                textTheme: GoogleFonts.poppinsTextTheme()
                    .apply(
                      bodyColor:
                          const Color(0xFFB0C4C7), // Muted cyan/grey for body
                      displayColor: const Color(0xFFB0C4C7),
                    )
                    .copyWith(
                      bodyLarge: GoogleFonts.poppins(
                        color: const Color(0xFFB0C4C7),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      bodyMedium: GoogleFonts.poppins(
                        color: const Color(0xFFB0C4C7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      bodySmall: GoogleFonts.poppins(
                        color: const Color(0xFF809598),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      titleLarge: GoogleFonts.poppins(
                        color:
                            const Color(0xFFD1E7E2), // Lighter cyan for titles
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      titleMedium: GoogleFonts.poppins(
                        color: const Color(0xFFC1D7D2),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      titleSmall: GoogleFonts.poppins(
                        color: const Color(0xFFA5D6D1),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                dividerColor: const Color(0xFF405053).withValues(alpha: 0.2),
                extensions: const [
                  SuccessColors(
                    success: Color(0xFF22C55E),
                    onSuccess: Colors.black,
                  ),
                ],
                scaffoldBackgroundColor: const Color(0xFF1A1A1A),
                appBarTheme: const AppBarTheme(centerTitle: false),
                filledButtonTheme: FilledButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
                    minimumSize:
                        const WidgetStatePropertyAll(Size(double.infinity, 48)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: ButtonStyle(
                    iconSize: const WidgetStatePropertyAll(24),
                    foregroundColor: WidgetStatePropertyAll(kAccent),
                  ),
                ),
                cardTheme: const CardThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  elevation: 1,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF374151)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kAccent, width: 1.4),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFFE5E7EB)),
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIconColor: const Color(0xFF9CA3AF),
                  suffixIconColor: const Color(0xFF9CA3AF),
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: kAccent,
                  selectionHandleColor: kAccent,
                  selectionColor: kAccent.withValues(alpha: 0.25),
                ),
              ),
              themeMode: mode,
              home: const RootDecider(),
              routes: {
                '/settings': (context) => const SettingsScreen(),
              },
            );
          },
        );
      },
    );
  }
}
