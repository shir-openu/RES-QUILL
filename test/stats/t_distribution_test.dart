import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  group('regularized incomplete beta', () {
    test('evaluates and inverts basic symmetric cases', () {
      expect(
        RegularizedIncompleteBeta.evaluate(0.5, 0.5, 0.5),
        closeTo(0.5, 1e-13),
      );
      expect(
        RegularizedIncompleteBeta.evaluate(0.5, 2, 2),
        closeTo(0.5, 1e-13),
      );

      for (final p in [1e-8, 0.001, 0.1, 0.5, 0.9, 0.999, 1 - 1e-8]) {
        final x = RegularizedIncompleteBeta.inverse(p, 2.5, 4.0);
        expect(
          RegularizedIncompleteBeta.evaluate(x, 2.5, 4.0),
          closeTo(p, 3e-12),
        );
      }
    });
  });

  group('t distribution', () {
    test('matches standard critical values', () {
      expect(
        TDistribution(1).quantile(0.975),
        closeTo(12.706204736174694, 1e-9),
      );
      expect(
        TDistribution(9).quantile(0.975),
        closeTo(2.262157162798205, 1e-11),
      );
      expect(
        TDistribution(14).quantile(0.975),
        closeTo(2.144786687917804, 1e-11),
      );
      expect(
        TDistribution(30).quantile(0.975),
        closeTo(2.0422724563012378, 1e-11),
      );
      expect(
        TDistribution(326).quantile(0.975),
        closeTo(1.9672675222597706, 1e-11),
      );
    });

    test('cdf and quantile invert each other', () {
      for (final df in [1.0, 2.0, 9.0, 16.487715772749027, 48.8, 326.0]) {
        final distribution = TDistribution(df);
        for (final p in [0.0001, 0.01, 0.1, 0.5, 0.9, 0.99, 0.9999]) {
          final t = distribution.quantile(p);
          expect(distribution.cdf(t), closeTo(p, 5e-11));
        }
      }
    });

    test('is symmetric around zero', () {
      final distribution = TDistribution(20.98836880348925);
      for (final t in [0.1, 1.5, 2.9, 8.0]) {
        expect(distribution.cdf(-t), closeTo(1 - distribution.cdf(t), 2e-14));
      }
    });
  });
}
