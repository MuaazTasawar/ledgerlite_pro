import 'package:flutter/foundation.dart';
import '../../core/models/entry.dart';
import '../../core/models/ledger.dart';
import '../../core/services/key_service.dart';
import '../../core/services/ledger_service.dart';

class HomeController extends ChangeNotifier {
  final LedgerService _ledgerService;
  final KeyService _keyService;

  HomeController({
    required LedgerService ledgerService,
    required KeyService keyService,
  })  : _ledgerService = ledgerService,
        _keyService = keyService;

  LedgerSummary _summary = LedgerSummary.empty();
  List<SignedEntryModel> _recentEntries = [];
  List<String> _customerNames = [];
  bool _isLoading = true;
  String? _error;

  LedgerSummary get summary => _summary;
  List<SignedEntryModel> get recentEntries => _recentEntries;
  List<String> get customerNames => _customerNames;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get merchantName => _keyService.merchantName;
  String get shortPublicKey => _keyService.shortPublicKey;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _ledgerService.summary(),
        _ledgerService.allEntries(),
        _ledgerService.customerNames(),
      ]);

      _summary = results[0] as LedgerSummary;
      final allEntries = results[1] as List<SignedEntryModel>;
      _customerNames = results[2] as List<String>;
      _recentEntries = allEntries.reversed.take(10).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}