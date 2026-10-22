import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/screens/cosmic/gold_conversion_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily element rotates by calendar day', () {
    final day0 = DateTime.utc(1970, 1, 1);
    final day1 = DateTime.utc(1970, 1, 2);

    expect(
      goldConversionDailyElement(day0).biomeId,
      ElementResources.all.first.biomeId,
    );
    expect(
      goldConversionDailyElement(day1).biomeId,
      ElementResources.all[1].biomeId,
    );
  });

  test("today's essence sells for 500 silver per 100", () {
    final date = DateTime.utc(1970, 1, 1);
    final featured = goldConversionDailyElement(date);

    expect(
      goldConversionSilverPayout(
        resourceBiomeId: featured.biomeId,
        quantity: 100,
        date: date,
      ),
      500,
    );
  });

  test('any other essence sells for 1 silver each', () {
    final date = DateTime.utc(1970, 1, 1);
    final featured = goldConversionDailyElement(date);
    final other = ElementResources.all.firstWhere(
      (res) => res.biomeId != featured.biomeId,
    );

    expect(
      goldConversionSilverPayout(
        resourceBiomeId: other.biomeId,
        quantity: 100,
        date: date,
      ),
      100,
    );
  });

  test("today's essence turns over at the phone's own midnight", () {
    final morning = DateTime(2026, 10, 22, 0, 10);
    final evening = DateTime(2026, 10, 22, 23, 50);
    final next = DateTime(2026, 10, 23, 0, 10);

    expect(
      goldConversionDailyElement(evening).biomeId,
      goldConversionDailyElement(morning).biomeId,
    );
    expect(
      goldConversionDailyElement(next).biomeId,
      isNot(goldConversionDailyElement(evening).biomeId),
    );
  });
}
