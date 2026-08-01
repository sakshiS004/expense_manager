import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/local/db_helper.dart';
import 'data/repositories/budget_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/auth/app_lock_gate.dart';
import 'features/auth/app_lock_service.dart';
import 'features/auth/auth_service.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/notification_service.dart';
import 'features/settings/settings_screen.dart';
import 'features/transactions/transaction_history_screen.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'sync/sync_queue.dart';
import 'sync/sync_service.dart';

void main() async {
  // Preserve native splash screen until initialization completes
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    // Initialize Firebase & Offline Persistence
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Ensure local SQLite DB is ready
    await DBHelper.instance.database;

    // Initialize Notifications
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleDailyReminders();
  } catch (e) {
    debugPrint('Initialization error: $e');
  } finally {
    // Dismiss splash screen only after all async initialization finishes
    FlutterNativeSplash.remove();
  }

  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(
            repository: LocalTransactionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BudgetProvider(
            repository: LocalBudgetRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(
            repository: LocalCategoryRepository(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppLockService()..load()),

        // ProxyProviders manage dependent services cleanly without object recreation inside build()
        ProxyProvider2<AuthService, TransactionProvider, SyncService>(
          update: (_, auth, transactionProvider, __) => SyncService(
            userId: auth.currentUserId,
            transactionProvider: transactionProvider,
          ),
        ),
        ProxyProvider<SyncService, SyncQueue>(
          update: (_, syncService, __) => SyncQueue(onSync: syncService.sync),
        ),
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> {
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataForUser(context.read<AuthService>().currentUserId);
    });
  }

  void _loadDataForUser(String userId) {
    _lastUserId = userId;
    context.read<TransactionProvider>().loadTransactions(userId);
    context.read<BudgetProvider>().loadBudgets(userId);
    context.read<CategoryProvider>().loadCategories(userId);
  }

  @override
  Widget build(BuildContext context) {
    // Safely listen only to changes in currentUserId
    final userId = context.select<AuthService, String>((auth) => auth.currentUserId);

    // Auto-reload data when user status changes
    if (_lastUserId != userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDataForUser(userId);
      });
    }

    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Expense Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.themeMode,
          home: const AppLockGate(child: DashboardNavWrapper()),
        );
      },
    );
  }
}

class DashboardNavWrapper extends StatefulWidget {
  const DashboardNavWrapper({super.key});

  @override
  State<DashboardNavWrapper> createState() => _DashboardNavWrapperState();
}

class _DashboardNavWrapperState extends State<DashboardNavWrapper> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TransactionHistoryScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}