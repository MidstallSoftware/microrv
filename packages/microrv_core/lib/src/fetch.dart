import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class MicroRVFetcher extends Module {
  Logic get pc => output('pc');
  Logic get ir => output('ir');
  Logic get imem_addr => output('imem_addr');
  Logic get imem_en => output('imem_en');

  MicroRVFetcher({
    required Logic clk,
    required Logic reset,
    required Logic imem_valid,
    required Logic imem_data,
    required Logic enable,
    required Logic stall,
  }) : super(name: 'MicroRVFetch') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    imem_valid = addInput('imem_valid', imem_valid);
    imem_data = addInput('imem_data', imem_data, width: 32);
    enable = addInput('enable', enable);
    stall = addInput('stall', stall);

    addOutput('pc', width: 32);
    addOutput('ir', width: 32);
    addOutput('imem_addr', width: 32);
    addOutput('imem_en');

    final resetSync = FlipFlop(clk, reset, name: 'reset_sync').q;

    final ir_next = Logic(name: 'ir_next', width: 32);
    final next_pc = Logic(name: 'next_pc', width: 32);

    final pc_reg = FlipFlop(clk, next_pc, reset: resetSync, name: 'pc');
    final ir_reg = FlipFlop(clk, ir_next, reset: resetSync, name: 'ir');

    final imem_enVal = Logic(name: 'imem_en');

    pc <= pc_reg.q;
    ir <= ir_reg.q;
    imem_addr <= pc_reg.q;
    imem_en <= imem_enVal;

    Combinational([
      imem_enVal < enable & ~stall,
      If.block([
        Iff(imem_valid, [
          ir_next < imem_data,
          next_pc < pc_reg.q + Const(4, width: 32),
        ]),
        Else([ir_next < ir_reg.q, next_pc < pc_reg.q]),
      ]),
    ]);
  }

  String toStateString() => """
PC: ${pc.value}
IR: ${ir.value}
IM Address: ${imem_addr.value}
IM Enable ${imem_en.value}""";
}
