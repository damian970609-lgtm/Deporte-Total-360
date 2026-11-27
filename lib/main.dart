import 'package:flutter/material.dart';

import 'agenda_web_screen.dart';
import 'live_channels_screen.dart';

const Color _background = Color(0xFF05080E);
const Color _blue = Color(0xFF00A3FF);
const Color _green = Color(0xFF39FF14);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeporteTotal360App());
}

class DeporteTotal360App extends StatelessWidget {
  const DeporteTotal360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deporte Total 360°',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: Brightness.dark,
          surface: _background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF080E18),
          indicatorColor: _blue.withAlpha(48),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? _green
                  : const Color(0xFFADB9CA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      home: const _MainNavigation(),
    );
  }
}

class _MainNavigation extends StatefulWidget {
  const _MainNavigation();

  @override
  State<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<_MainNavigation> {
  int _selectedIndex = 0;

  void _openAgenda() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const AgendaWebScreen(),
          LiveChannelsScreen(
            isActive: _selectedIndex == 1,
            onOpenAgenda: _openAgenda,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        height: 70,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv_rounded),
            label: 'Transmisión en vivo',
          ),
        ],
      ),
    );
  }
}
