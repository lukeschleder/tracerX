import 'dart:io';

import 'package:tracer_x/tracer_x.dart';

/// Minimal cart / checkout domain used to demonstrate a real state bug.
///
/// Bug: `CheckoutService.placeOrder` forgets to re-validate stock after the
/// coupon is applied, so an out-of-stock item can still reach `confirmed`.
class CartItem {
  CartItem({
    required this.sku,
    required this.price,
    required this.quantity,
    required this.inStock,
  });

  final String sku;
  final double price;
  final int quantity;
  final bool inStock;

  double get lineTotal => price * quantity;
}

class CheckoutService {
  CheckoutService(this.tracer);

  final TracerSession tracer;

  double _subtotal = 0;
  double _discount = 0;
  String _status = 'idle';

  /// Buggy path: applies coupon then confirms without a stock re-check.
  Future<void> placeOrderBuggy(List<CartItem> items, {String? coupon}) async {
    tracer.info(
      'Checkout started',
      metadata: {'itemCount': items.length, 'status': _status},
    );

    _subtotal = items.fold(0, (sum, item) => sum + item.lineTotal);
    tracer.debug(
      'Subtotal calculated',
      metadata: {'subtotal': _subtotal},
    );

    if (coupon != null) {
      _discount = _subtotal * 0.1;
      tracer.info(
        'Coupon applied',
        metadata: {'coupon': coupon, 'discount': _discount},
      );
    }

    // BUG: missing stock validation before confirmation.
    _status = 'confirmed';
    tracer.error(
      'Order confirmed with possible stock violation',
      metadata: {
        'status': _status,
        'total': _subtotal - _discount,
        'skus': items.map((i) => i.sku).toList(),
      },
    );
  }

  /// Fixed path: validates stock after pricing, then confirms.
  Future<void> placeOrderFixed(List<CartItem> items, {String? coupon}) async {
    tracer.info(
      'Checkout started',
      metadata: {'itemCount': items.length, 'status': _status},
    );

    _subtotal = items.fold(0, (sum, item) => sum + item.lineTotal);
    tracer.debug(
      'Subtotal calculated',
      metadata: {'subtotal': _subtotal},
    );

    if (coupon != null) {
      _discount = _subtotal * 0.1;
      tracer.info(
        'Coupon applied',
        metadata: {'coupon': coupon, 'discount': _discount},
      );
    }

    final outOfStock = items.where((item) => !item.inStock).toList();
    if (outOfStock.isNotEmpty) {
      _status = 'rejected';
      tracer.info(
        'Stock validation failed',
        metadata: {
          'status': _status,
          'outOfStock': outOfStock.map((i) => i.sku).toList(),
        },
      );
      return;
    }

    _status = 'confirmed';
    tracer.info(
      'Order confirmed',
      metadata: {
        'status': _status,
        'total': _subtotal - _discount,
        'skus': items.map((i) => i.sku).toList(),
      },
    );
  }
}

List<CartItem> _sampleCart() => [
      CartItem(sku: 'TEE-001', price: 28, quantity: 1, inStock: true),
      CartItem(sku: 'HAT-014', price: 22, quantity: 1, inStock: false),
    ];

Future<TracerTrace> _recordBug(Directory outputDir) async {
  final fileSink = FileSink(directory: outputDir.path);
  // Force colorize so the demo is vivid even when stdout is redirected.
  final session = TracerX.startSession(
    'checkout-bug',
    sinks: [ConsoleSink(colorize: true), fileSink],
  );

  final checkout = CheckoutService(session);
  await checkout.placeOrderBuggy(_sampleCart(), coupon: 'SAVE10');
  return session.end();
}

Future<TracerTrace> _recordFix(Directory outputDir) async {
  final fileSink = FileSink(directory: outputDir.path);
  final session = TracerX.startSession(
    'checkout-fixed',
    sinks: [ConsoleSink(colorize: true), fileSink],
  );

  final checkout = CheckoutService(session);
  await checkout.placeOrderFixed(_sampleCart(), coupon: 'SAVE10');
  return session.end();
}

Future<void> main() async {
  final outputDir = Directory('${Directory.systemTemp.path}/tracerx_example');
  if (outputDir.existsSync()) {
    await outputDir.delete(recursive: true);
  }
  await outputDir.create(recursive: true);

  const colorize = true;

  stdout.writeln(
    AnsiColors.wrap(
      '=== Recording baseline (buggy checkout) ===',
      AnsiColors.bold + AnsiColors.yellow,
      enabled: colorize,
    ),
  );
  final baseline = await _recordBug(outputDir);

  stdout.writeln();
  stdout.writeln(
    AnsiColors.wrap(
      '=== Recording fixed checkout ===',
      AnsiColors.bold + AnsiColors.green,
      enabled: colorize,
    ),
  );
  final fixed = await _recordFix(outputDir);

  stdout.writeln();
  final diff = TracerDiff(baseline: baseline, target: fixed);
  stdout.write(diff.generateReceipt(colorize: colorize));

  final receiptPath = '${outputDir.path}/fix_receipt.txt';
  await diff.saveReceipt(receiptPath);

  stdout.writeln();
  stdout.writeln('Receipt saved to: $receiptPath');
  stdout.writeln('Traces saved to:  ${outputDir.path}');
}
