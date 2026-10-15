class BankRate {
  final String bankName;
  final double buyRate;
  final double sellRate;
  final bool isError;
  final String? errorMessage;

  BankRate({
    required this.bankName,
    required this.buyRate,
    required this.sellRate,
    this.isError = false,
    this.errorMessage,
  });

  factory BankRate.error(String bankName, String message) {
    return BankRate(
      bankName: bankName,
      buyRate: 0.0,
      sellRate: 0.0,
      isError: true,
      errorMessage: message,
    );
  }
}

class TickerUpdate {
  final double rate;
  final double changePercent;
  final bool isSignificant;

  TickerUpdate({
    required this.rate,
    required this.changePercent,
    required this.isSignificant,
  });
}
