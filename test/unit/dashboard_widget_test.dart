import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:expense_manager/data/models/budget_model.dart';
import 'package:expense_manager/data/models/category_model.dart';
import 'package:expense_manager/data/models/sync_status.dart';
import 'package:expense_manager/data/models/transaction_model.dart';
import 'package:expense_manager/data/repositories/budget_repository.dart';
import 'package:expense_manager/data/repositories/category_repository.dart';
import 'package:expense_manager/data/repositories/transaction_repository.dart';
import 'package:expense_manager/features/auth/auth_service.dart';
import 'package:expense_manager/features/dashboard/dashboard_screen.dart';
import 'package:expense_manager/features/transactions/add_transcation_screen.dart';
import 'package:expense_manager/providers/budget_provider.dart';
import 'package:expense_manager/providers/category_provider.dart';
import 'package:expense_manager/providers/settings_provider.dart';
import 'package:expense_manager/providers/transaction_provider.dart';
import 'package:expense_manager/sync/sync_queue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helper.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockConnectivity extends Mock implements Connectivity {}

// Prevent MockSyncQueue from triggering real SQLite / DBHelper calls
class MockSyncQueue extends Mock implements SyncQueue {
  @override
  Future<void> get ready async {}

  @override
  ValueNotifier<int> get pendingChangeCount => ValueNotifier<int>(0);

  @override
  ValueNotifier<bool> get isOnline => ValueNotifier<bool>(true);

  @override
  ValueNotifier<SyncQueueStatus> get syncStatus =>
      ValueNotifier<SyncQueueStatus>(SyncQueueStatus.synced);

  @override
  Future<void> refreshPendingCount() async {}

  @override
  void dispose() {}
}

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository([List<TransactionModel> seed = const []])
      : _items = List.of(seed);
  final List<TransactionModel> _items;

  @override
  Future<List<TransactionModel>> getTransactions(String userId) async =>
      List.of(_items);
  @override
  Future<void> addTransaction(TransactionModel transaction) async =>
      _items.add(transaction);
  @override
  Future<void> updateTransaction(TransactionModel transaction) async {}
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> restoreTransaction(TransactionModel transaction) async {}
  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() async => [];
}

class FakeBudgetRepository implements BudgetRepository {
  @override
  Future<List<BudgetModel>> getBudgets(String userId) async => [];
  @override
  Future<void> addBudget(BudgetModel budget) async {}
  @override
  Future<void> updateBudget(BudgetModel budget) async {}
  @override
  Future<void> deleteBudget(String id) async {}
}

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository(this._items);
  final List<CategoryModel> _items;

  @override
  Future<List<CategoryModel>> getCategories(String userId) async =>
      List.of(_items);
  @override
  Future<void> addCategory(CategoryModel category) async => _items.add(category);
  @override
  Future<void> updateCategory(CategoryModel category) async {}
  @override
  Future<void> deleteCategory(String id) async {}
}

const _testUserId = 'widget_test_user';

List<CategoryModel> _seedCategories() {
  final now = DateTime.now();
  return [
    CategoryModel(
      id: 'cat_food',
      userId: _testUserId,
      name: 'Food',
      icon: 'restaurant',
      type: TransactionType.expense,
      color: 0xFFEF5350,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
    CategoryModel(
      id: 'cat_salary',
      userId: _testUserId,
      name: 'Salary',
      icon: 'attach_money',
      type: TransactionType.income,
      color: 0xFF66BB6A,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
  ];
}

List<TransactionModel> _seedTransactions() {
  final now = DateTime.now();
  return [
    TransactionModel(
      id: 'txn_1',
      userId: _testUserId,
      amount: 250,
      type: TransactionType.income,
      categoryId: 'cat_salary',
      accountId: 'bank',
      date: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
    TransactionModel(
      id: 'txn_2',
      userId: _testUserId,
      amount: 25,
      type: TransactionType.expense,
      categoryId: 'cat_food',
      accountId: 'cash',
      note: 'Coffee with Sam',
      date: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
  ];
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  // Set explicit screen dimensions to prevent RenderFlex layout overflow
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mockAuth = MockFirebaseAuth();
  when(() => mockAuth.currentUser).thenReturn(null);
  when(() => mockAuth.authStateChanges())
      .thenAnswer((_) => const Stream<User?>.empty());

  SharedPreferences.setMockInitialValues({});

  final transactionProvider = TransactionProvider(
    repository: FakeTransactionRepository(_seedTransactions()),
  );
  await transactionProvider.loadTransactions(_testUserId);

  final budgetProvider = BudgetProvider(repository: FakeBudgetRepository());
  final categoryProvider =
  CategoryProvider(repository: FakeCategoryRepository(_seedCategories()));
  await categoryProvider.loadCategories(_testUserId);

  final authService = AuthService(firebaseAuth: mockAuth);
  final syncQueue = MockSyncQueue();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        Provider<SyncQueue>.value(value: syncQueue),
      ],
      child: const MaterialApp(
        home: DashboardScreen(userId: _testUserId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestDatabaseFactory);
  setUp(resetTestDatabase);

  testWidgets(
      'renders balance, income/expense, and recent transactions without exceptions',
          (tester) async {
        await _pumpDashboard(tester);

        expect(tester.takeException(), isNull);

        expect(find.text('Total Balance'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('income_card')),
            matching: find.text('Income'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('expense_card')),
            matching: find.text('Expenses'),
          ),
          findsOneWidget,
        );
        expect(find.text('Recent Transactions'), findsOneWidget);
        expect(find.textContaining('Coffee with Sam'), findsOneWidget);
      });

  testWidgets('tapping the Income card opens AddTransactionScreen',
          (tester) async {
        await _pumpDashboard(tester);

        final incomeFinder = find.byKey(const Key('income_card'));
        if (incomeFinder.evaluate().isNotEmpty) {
          await tester.tap(incomeFinder.first);
        } else {
          await tester.tap(find.text('Income').first);
        }

        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionScreen), findsOneWidget);
        expect(find.text('Add Income'), findsOneWidget);
      });

  testWidgets(
      'tapping the Expenses card opens AddTransactionScreen locked to expense',
          (tester) async {
        await _pumpDashboard(tester);

        final expenseFinder = find.byKey(const Key('expense_card'));
        if (expenseFinder.evaluate().isNotEmpty) {
          await tester.tap(expenseFinder.first);
        } else {
          await tester.tap(find.text('Expenses').first);
        }

        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionScreen), findsOneWidget);
        expect(find.text('Add Expense'), findsOneWidget);
      });
}