import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

enum MicroRVWriteBackTarget {
  mem,
  reg;

  static const width = 2;
}

class MicroRVWriteBack extends Module {
  MicroRVWriteBack({
    required Logic clk,
    required Logic reset,
    required Logic enable,
    required Logic result,
    required Logic target,
    required Logic targetAddr,
    required DataPortInterface regWritePort,
  }) : super(name: 'MicroRVWriteBack') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    enable = addInput('enable', enable);
    result = addInput('result', result, width: 32);
    target = addInput('target', target, width: MicroRVWriteBackTarget.width);
    targetAddr = addInput('targetAddr', targetAddr, width: 32);

    regWritePort = DataPortInterface(32, 5)..connectIO(
      this,
      regWritePort,
      outputTags: {DataPortGroup.data, DataPortGroup.control},
      uniquify: (original) => 'regWritePort_${original}',
    );

    final resetSync1 = FlipFlop(clk, reset).q;
    final resetSync2 = FlipFlop(clk, resetSync1).q;
    final enableLatch = FlipFlop(clk, enable, reset: resetSync2);

    Combinational([
      If.block([
        Iff(enableLatch.q, [
          If.block([
            Iff(target.eq(MicroRVWriteBackTarget.mem.index), []),
            Iff(target.eq(MicroRVWriteBackTarget.reg.index), [
              regWritePort.en < 1,
              regWritePort.addr < targetAddr.slice(4, 0),
              regWritePort.data < result,
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
