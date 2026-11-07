import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/core/format/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('formatNumber', () {
    test('ribuan memakai titik', () {
      expect(formatNumber(4812), '4.812');
      expect(formatNumber(1234567), '1.234.567');
    });

    test('desimal memakai koma, maksimal 1 digit', () {
      expect(formatNumber(182.4), '182,4');
      expect(formatNumber(6.45), '6,5');
    });

    test('tanpa ,0 untuk bilangan bulat', () {
      expect(formatNumber(230.0), '230');
      expect(formatNumber(0), '0');
    });
  });

  group('formatLiters', () {
    test('kriteria R-09: 4812 menjadi "4.812 L"', () {
      expect(formatLiters(4812), '4.812 L');
    });

    test('desimal', () {
      expect(formatLiters(182.4), '182,4 L');
    });
  });

  group('formatFlow', () {
    test('debit L/menit', () {
      expect(formatFlow(6.4), '6,4 L/menit');
      expect(formatFlow(0), '0 L/menit');
    });
  });

  group('formatRatio', () {
    test('rasio anomali', () {
      expect(formatRatio(1.7), '1,7×');
    });
  });

  group('waktu WIB', () {
    final utc = DateTime.utc(2026, 11, 7, 7, 20); // 14.20 WIB

    test('jam hh.mm dalam WIB', () {
      expect(formatClock(utc), '14.20');
    });

    test('tanggal panjang dalam WIB', () {
      expect(formatDayDate(utc), 'Sabtu, 7 November');
    });

    test('pergantian hari mengikuti WIB, bukan UTC', () {
      // 18.30 UTC tanggal 6 = 01.30 WIB tanggal 7.
      expect(
        formatDayDate(DateTime.utc(2026, 11, 6, 18, 30)),
        'Sabtu, 7 November',
      );
    });
  });

  group('formatAgo', () {
    final now = DateTime.utc(2026, 11, 7, 7, 30);

    test('detik', () {
      expect(
        formatAgo(now.subtract(const Duration(seconds: 10)), now: now),
        '10 detik lalu',
      );
    });

    test('menit', () {
      expect(
        formatAgo(now.subtract(const Duration(minutes: 3)), now: now),
        '3 menit lalu',
      );
    });

    test('jam', () {
      expect(
        formatAgo(now.subtract(const Duration(hours: 2)), now: now),
        '2 jam lalu',
      );
    });

    test('lebih dari sehari menampilkan tanggal', () {
      expect(formatAgo(DateTime.utc(2026, 11, 5, 7), now: now), '5 Nov');
    });

    test('waktu di masa depan (jam HP selisih) dianggap baru saja', () {
      expect(
        formatAgo(now.add(const Duration(seconds: 5)), now: now),
        'baru saja',
      );
    });
  });
}
