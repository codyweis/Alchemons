// Samples the Dart CPU profile of a running --profile app and ranks the
// hottest functions. Usage:
//   dart run tool/cpu_profile.dart <ws://…/ws> [seconds=6] [top=35]
// The VM service URI is printed by `flutter run` ("Dart VM Service … at").
// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:async';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  var uri = args.first;
  if (uri.startsWith('http')) {
    uri = '${uri.replaceFirst('http', 'ws').replaceAll(RegExp(r'/$'), '')}/ws';
  }
  final seconds = args.length > 1 ? int.parse(args[1]) : 6;
  final top = args.length > 2 ? int.parse(args[2]) : 35;
  final service = await vmServiceConnectUri(uri);
  final vm = await service.getVM();
  final isolate = vm.isolates!.firstWhere(
    (i) => i.name == 'main',
    orElse: () => vm.isolates!.first,
  );
  final id = isolate.id!;
  await service.clearCpuSamples(id);
  final start = (await service.getVMTimelineMicros()).timestamp!;
  await Future<void>.delayed(Duration(seconds: seconds));
  final span = (await service.getVMTimelineMicros()).timestamp! - start;
  final samples = await service.getCpuSamples(id, start, span);
  final functions = samples.functions!;
  String name(int i) {
    final f = functions[i].function;
    if (f is FuncRef) {
      final owner = f.owner;
      final ownerName = owner is ClassRef
          ? '${owner.name}.'
          : owner is FuncRef
          ? '${owner.name}.'
          : '';
      return '$ownerName${f.name}';
    }
    if (f is NativeFunction) return '[native] ${f.name}';
    return '$f';
  }

  final exclusive = <int, int>{};
  final inclusive = <int, int>{};
  final all = samples.samples!;
  for (final s in all) {
    final stack = s.stack!;
    if (stack.isEmpty) continue;
    exclusive[stack.first] = (exclusive[stack.first] ?? 0) + 1;
    for (final f in stack.toSet()) {
      inclusive[f] = (inclusive[f] ?? 0) + 1;
    }
  }
  final total = all.length;
  void dump(String title, Map<int, int> m) {
    print('\n== $title (of $total samples over ${seconds}s) ==');
    final sorted = m.entries.toList()..sort((a, b) => b.value - a.value);
    for (final e in sorted.take(top)) {
      final pct = (100 * e.value / total).toStringAsFixed(1).padLeft(5);
      print('$pct%  ${name(e.key)}');
    }
  }

  dump('SELF', exclusive);
  dump('INCLUSIVE', inclusive);
  await service.dispose();
}
