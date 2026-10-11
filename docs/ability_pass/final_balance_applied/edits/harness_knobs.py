# EXPERIMENT ONLY: the harness reads KNOBS="a=1,b=2" into kBalanceKnobs.
T = 'test/ability_scaling_report_test.dart'
def edits(mode):
    if mode != 'exp':
        return []
    return [(T, """    final env = Platform.environment;
    List<String> list(String key, List<String> fallback) {""",
"""    final env = Platform.environment;
    for (final kv in (env['KNOBS'] ?? '').split(',')) {
      final i = kv.indexOf('=');
      if (i <= 0) continue;
      kBalanceKnobs[kv.substring(0, i).trim()] =
          double.parse(kv.substring(i + 1).trim());
    }
    List<String> list(String key, List<String> fallback) {""")]
