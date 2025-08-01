import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

enum MicroRVWriteBackTarget {
  mem,
  reg;

  static const width = 2;
}

class MicroRVWriteBack extends Module {
  MicroRVWriteBack({
    required Logic result,
    required Logic target,
    required Logic targetAddr,
    required DataPortInterface regWritePort,
  }) : super(name: 'MicroRVWriteBack') {
    result = addInput('result', result, width: 32);
    target = addInput('target', target, width: MicroRVWriteBackTarget.width);
    targetAddr = addInput('targetAddr', targetAddr, width: 5);

    regWritePort = DataPortInterface(32, 5)..connectIO(
      this,
      regWritePort,
      outputTags: {DataPortGroup.data, DataPortGroup.control},
      uniquify: (original) => 'regWritePort_${original}',
    );

    Combinational([
      If.block([
        Iff(target.eq(MicroRVWriteBackTarget.mem.index), []),
        Iff(target.eq(MicroRVWriteBackTarget.reg.index), [
          regWritePort.en < 1,
          regWritePort.addr < targetAddr,
          regWritePort.data < result,
        ]),
      ]),
    ]);
  }
}
