import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web_indexed.dart';

class StatsService {
  const StatsService();

  Future<double> getTotalReceived({bool includeEventBooks = true}) {
    return nativeDb.getTotalReceived(includeEventBooks: includeEventBooks);
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) {
    return nativeDb.getTotalSent(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestReceivedTotals({
    bool includeEventBooks = true,
  }) {
    return nativeDb.getGuestReceivedTotals(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestSentTotals({
    bool includeEventBooks = true,
  }) {
    return nativeDb.getGuestSentTotals(includeEventBooks: includeEventBooks);
  }

  Future<Map<String, double>> getMonthlyStats(int year, int month) {
    return nativeDb.getMonthlyStats(year, month);
  }

  Future<double?> getMostCommonAmount() {
    return nativeDb.getMostCommonAmount();
  }

  Future<Map<String, dynamic>?> getMostFrequentContact() {
    return nativeDb.getMostFrequentContact();
  }

  Future<Map<String, double>> getYearlyStats(int year) {
    return nativeDb.getYearlyStats(year);
  }
}
