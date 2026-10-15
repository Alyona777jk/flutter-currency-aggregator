# Lab 8: Asynchronous Dart Programming — Currency Rates Aggregator

A Flutter application developed as part of the *Mobile Platform Programming* course. The application compares exchange rates across three mock banks in real time, determines the fastest source, highlights market price fluctuations, and handles connection failures gracefully.

## Features & Implementation Details

- **Parallel Data Fetching**: Utilizes `Future.wait` to retrieve currency rates from three banks simultaneously.
- **Fastest Source Determination**: Uses `Future.any` to display data from whichever bank responds first.
- **Real-Time Stock Ticker**: Connects to a live stream updated every 2 seconds (`async*` and `StreamController`).
- **Significant Rate Change Highlighting**: Fluctuations greater than 0.5% are dynamically highlighted.
- **Resilience & Retry Logic**: Implements Exponential Backoff retry strategy (up to 3 attempts) for unreliable sources.
- **Fault Tolerance**: Displays data from active banks even if one bank fails or times out (`.timeout`).
- **Pull-to-Refresh**: Easily reloads bank exchange rates using `RefreshIndicator`.
- **Resource Management**: Automatically unsubscribes and closes streams and controllers in `dispose()`.

---

## Asynchronous Performance Benchmark

| Fetch Method | Average Execution Time | Description |
| :--- | :--- | :--- |
| **Sequential Fetching** (`await` per bank) | ~2400 ms | Cumulative delay of all 3 requests (~800ms each) |
| **Parallel Fetching** (`Future.wait`) | ~850 ms | Bounded only by the single slowest request |
| **Fastest Source** (`Future.any`) | ~420 ms | Bounded by the single fastest responding request |

---

## Technical Architecture

- **`lib/models/currency_rate.dart`**: Data models (`BankRate`, `TickerUpdate`).
- **`lib/services/fake_api.dart`**: Mock API service with configurable failure rate (50%) and Exponential Backoff.
- **`lib/screens/currency_aggregator_screen.dart`**: Main UI utilizing `FutureBuilder` and `StreamBuilder`.

---

## Code Quality Check

- Clean `flutter analyze` output with zero warnings/errors.
- Guarded `mounted` checks after every asynchronous `await`.
- Saved `Future` references in `initState` to avoid unnecessary re-fetching inside `build()`.

---

## Application Screenshots

| Loading State | Partial Failure / Rates | Live Market Ticker |
| :---: | :---: | :---: |
| *(Add screenshot)* | *(Add screenshot)* | *(Add screenshot)* |
