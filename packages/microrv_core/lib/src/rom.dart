import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class MicroRVROM extends Module {
  final Map<int, int> program;

  Logic get data => output('data');
  Logic get valid => output('valid');

  MicroRVROM({
    required Logic clk,
    required Logic reset,
    required Logic en,
    required Logic addr,
    this.program = const {0: 12},
  }) : super(name: 'MicroRVROM') {
    final dataOut = Logic(name: 'dataOut', width: 32);
    final validBit = Logic(name: 'validBit');

    addOutput('data', width: 32);
    addOutput('valid');

    addInput('clk', clk);
    addInput('en', en);
    addInput('addr', addr, width: addr.width);

    final enableLatch = FlipFlop(clk, en, reset: reset);

    data <= dataOut;
    valid <= validBit;

    Combinational([
      If.block([
        Iff(enableLatch.q, [
          Case(
            addr,
            program.entries
                .map(
                  (entry) => CaseItem(Const(entry.key, width: addr.width), [
                    dataOut < Const(entry.value, width: 32),
                    validBit < Const(1),
                  ]),
                )
                .toList(),
            defaultItem: [dataOut < Const(0, width: 32), validBit < Const(0)],
          ),
        ]),
        Else([dataOut < Const(0, width: 32), validBit < Const(0)]),
      ]),
    ]);
  }

  String toStateString() => """
Data: ${data.value}
Valid: ${valid.value}""";
}
