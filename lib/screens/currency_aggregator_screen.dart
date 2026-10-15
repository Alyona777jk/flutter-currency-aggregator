import 'dart:async';
import 'package:flutter/material.dart';
import '../models/currency_rate.dart';
import '../services/fake_api.dart';

class CurrencyAggregatorScreen extends StatefulWidget {
  const CurrencyAggregatorScreen({super.key});

  @override
  State<CurrencyAggregatorScreen> createState() =>
      _CurrencyAggregatorScreenState();
}

class _CurrencyAggregatorScreenState extends State<CurrencyAggregatorScreen> {
  final FakeApi _api = FakeApi(failureRate: 0.5);

  late Future<List<BankRate>> _banksFuture;
  late final StreamController<TickerUpdate> _tickerController;
  StreamSubscription<TickerUpdate>? _rawStreamSubscription;

  BankRate? _fastestRate;
  bool _isFastestLoading = false;

  @override
  void initState() {
    super.initState();
    _tickerController = StreamController<TickerUpdate>.broadcast();
    _loadData();
    _initLiveStream();
  }

  void _loadData() {
    setState(() {
      _banksFuture = Future.wait([
        _api.fetchBankRateWithRetry('ПриватБанк'),
        _api.fetchBankRateWithRetry('Монобанк'),
        _api.fetchBankRateWithRetry('Ощадбанк'),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [
          BankRate.error('ПриватБанк', 'Тайм-аут'),
          BankRate.error('Монобанк', 'Тайм-аут'),
          BankRate.error('Ощадбанк', 'Тайм-аут'),
        ],
      );
    });
  }

  void _initLiveStream() {
    _rawStreamSubscription = _api
        .getLiveStockStream()
        .map((update) => update)
        .where((update) => update.rate > 0)
        .listen((update) {
          if (!_tickerController.isClosed) {
            _tickerController.add(update);
          }
        });
  }

  Future<void> _fetchFastestBank() async {
    setState(() {
      _isFastestLoading = true;
      _fastestRate = null;
    });

    try {
      final result = await Future.any([
        _api.fetchBankRateWithRetry('ПриватБанк'),
        _api.fetchBankRateWithRetry('Монобанк'),
        _api.fetchBankRateWithRetry('Ощадбанк'),
      ]);

      if (!mounted) return;

      setState(() {
        _fastestRate = result;
        _isFastestLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFastestLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _rawStreamSubscription?.cancel();
    _tickerController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Агрегатор курсів валют (USD)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          await _banksFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveStreamSection(),
              const SizedBox(height: 20),
              _buildFastestSourceSection(),
              const SizedBox(height: 20),
              const Text(
                'Курси у банках:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildFutureBankRatesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStreamSection() {
    return Card(
      elevation: 3,
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Біржовий курс (Live):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<TickerUpdate>(
              stream: _tickerController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Помилка потоку: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Підключення до біржі...'),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return const Text('Немає даних від біржі');
                }

                final update = snapshot.data!;
                final isSignificant = update.isSignificant;

                return Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: isSignificant
                        ? (update.changePercent > 0
                            ? Colors.green[100]
                            : Colors.red[100])
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSignificant
                        ? Border.all(
                            color: update.changePercent > 0
                                ? Colors.green
                                : Colors.red,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${update.rate.toStringAsFixed(2)} UAH',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            update.changePercent >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: update.changePercent >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                          Text(
                            '${update.changePercent}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: update.changePercent >= 0
                                  ? Colors.green[800]
                                  : Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFastestSourceSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _isFastestLoading ? null : _fetchFastestBank,
              icon: const Icon(Icons.flash_on),
              label: const Text('Найшвидше джерело (Future.any)'),
            ),
            if (_isFastestLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
            if (_fastestRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _fastestRate!.isError
                      ? 'Найшвидший банк повернув помилку: ${_fastestRate!.bankName}'
                      : 'Першим відповів: ${_fastestRate!.bankName} (Купівля: ${_fastestRate!.buyRate}, Продаж: ${_fastestRate!.sellRate})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFutureBankRatesSection() {
    return FutureBuilder<List<BankRate>>(
      future: _banksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Завантаження курсів банків...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Text('Критична помилка: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Повторити'),
                ),
              ],
            ),
          );
        }

        final banks = snapshot.data ?? [];

        if (banks.isEmpty) {
          return Center(
            child: Column(
              children: [
                const Text('Дані відсутні'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Повторити'),
                ),
              ],
            ),
          );
        }

        final validBanks = banks.where((b) => !b.isError).toList();
        BankRate? bestBuyBank;
        BankRate? bestSellBank;

        if (validBanks.isNotEmpty) {
          bestBuyBank = validBanks.reduce((a, b) => a.buyRate > b.buyRate ? a : b);
          bestSellBank = validBanks.reduce((a, b) => a.sellRate < b.sellRate ? a : b);
        }

        return Column(
          children: [
            if (validBanks.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.amber[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'Найкраща купівля: ${bestBuyBank!.buyRate} (${bestBuyBank.bankName})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Найкращий продаж: ${bestSellBank!.sellRate} (${bestSellBank.bankName})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: banks.length,
              itemBuilder: (context, index) {
                final bank = banks[index];

                if (bank.isError) {
                  return Card(
                    color: Colors.red[50],
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(bank.bankName),
                      subtitle: Text(
                        'Статус: Недоступний (${bank.errorMessage})',
                        style: const TextStyle(color: Colors.red),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadData,
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListTile(
                    title: Text(bank.bankName),
                    subtitle: Text('Купівля: ${bank.buyRate} UAH'),
                    trailing: Text(
                      'Продаж: ${bank.sellRate} UAH',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
