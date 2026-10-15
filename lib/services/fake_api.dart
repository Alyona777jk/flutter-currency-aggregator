import 'dart:async';
import 'dart:math';
import '../models/currency_rate.dart';

class FakeApi {
  final double failureRate;
  final Random _random;

  FakeApi({this.failureRate = 0.5, Random? random})
      : _random = random ?? Random();

  Future<BankRate> fetchBankRateWithRetry(
    String bankName, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await _fetchBankRate(bankName);
      } catch (e) {
        if (attempt >= maxRetries) {
          return BankRate.error(
            bankName,
            'Недоступний (після $maxRetries спроб)',
          );
        }
        final delayMs = 300 * pow(2, attempt - 1).toInt();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  Future<BankRate> _fetchBankRate(String bankName) async {
    final delay = 400 + _random.nextInt(800);
    await Future<void>.delayed(Duration(milliseconds: delay));

    if (_random.nextDouble() < failureRate) {
      throw StateError('Сервер $bankName недоступний');
    }

    final base = 41.0 + _random.nextDouble() * 0.5;
    final buy = double.parse(base.toStringAsFixed(2));
    final sell = double.parse((base + 0.30).toStringAsFixed(2));

    return BankRate(
      bankName: bankName,
      buyRate: buy,
      sellRate: sell,
    );
  }

  Stream<TickerUpdate> getLiveStockStream() async* {
    double currentRate = 41.25;

    while (true) {
      await Future<void>.delayed(const Duration(seconds: 2));

      final delta = (_random.nextDouble() * 0.8) - 0.4;
      final newRate = double.parse(
        (currentRate + delta).clamp(38.0, 45.0).toStringAsFixed(2),
      );

      final changePercent = ((newRate - currentRate) / currentRate) * 100;
      final absChange = changePercent.abs();

      currentRate = newRate;

      yield TickerUpdate(
        rate: newRate,
        changePercent: double.parse(changePercent.toStringAsFixed(2)),
        isSignificant: absChange > 0.5,
      );
    }
  }
}
