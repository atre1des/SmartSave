/// Read-only presentation contract. An authenticated adapter is a Phase B task.
abstract interface class WorkspaceData {
  int get balance;
  int get monthlySpending;
  int get budget;
  List<({String name, int saved, int target})> get goals;
  List<({String merchant, String category, int amount})> get transactions;
  List<({String symbol, String name, int price, double change})> get quotes;
}

class FictionalWorkspace implements WorkspaceData {
  const FictionalWorkspace();

  @override
  int get balance => 845200;
  @override
  int get monthlySpending => 74800;
  @override
  int get budget => 95000;
  @override
  List<({String name, int saved, int target})> get goals => const [
    (name: 'Emergency fund', saved: 420000, target: 600000),
    (name: 'Weekend in Almaty', saved: 80000, target: 200000),
  ];
  @override
  List<({String merchant, String category, int amount})> get transactions =>
      const [
        (merchant: 'Orchard Market', category: 'Food', amount: -18450),
        (merchant: 'Metro pass', category: 'Transport', amount: -6800),
        (merchant: 'Apartment utilities', category: 'Home', amount: -49550),
        (merchant: 'Studio payroll', category: 'Salary', amount: 920000),
      ];
  @override
  List<({String symbol, String name, int price, double change})> get quotes =>
      const [
        (symbol: 'HSBK', name: 'Halyk Bank', price: 245, change: 1.8),
        (symbol: 'KSPI', name: 'Kaspi.kz', price: 42300, change: .6),
        (symbol: 'KEGC', name: 'KEGOC', price: 1480, change: -.4),
        (symbol: 'KAP', name: 'Kazatomprom', price: 21900, change: 2.3),
      ];
}
