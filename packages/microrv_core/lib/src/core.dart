import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

import 'decoder.dart';
import 'exec.dart';
import 'write_back.dart';

enum MicroRVRegister {
  zero,
  ra,
  sp,
  gp,
  tp,
  t0,
  t1,
  t2,
  s0,
  s1,
  a0,
  a1,
  a2,
  a3,
  a4,
  a5,
  a6,
  a7,
  s2,
  s3,
  s4,
  s5,
  s6,
  s7,
  s8,
  s9,
  s10,
  s11,
  t3,
  t4,
  t5,
  t6,
}

class MicroRVCore extends Module {
  late RegisterFile regFile;
  late MicroRVDecoder decoder;
  late MicroRVExecutor exec;
  late MicroRVWriteBack wb;

  late DataPortInterface regWritePort;
  late DataPortInterface regReadPort1;
  late DataPortInterface regReadPort2;

  Logic get pc => output('pc');
  Logic get ir => output('ir');

  Logic get imem_addr => output('imem_addr');
  Logic get imem_ready => output('imem_ready');

  Logic get dmem_addr => output('dmem_addr');
  Logic get dmem_wdata => output('dmem_wdata');
  Logic get dmem_we => output('dmem_we');
  Logic get dmem_re => output('dmem_re');
  Logic get dmem_mask => output('dmem_mask');
  Logic get dmem_valid => output('dmem_valid');

  Logic readReg1(MicroRVRegister r) {
    regReadPort1.en.put(1);
    regReadPort1.addr.put(r.index);
    return regReadPort1.data;
  }

  Logic readReg2(MicroRVRegister r) {
    regReadPort2.en.put(1);
    regReadPort2.addr.put(r.index);
    return regReadPort2.data;
  }

  void writeReg(MicroRVRegister r, dynamic value) {
    regWritePort.en.put(1);
    regWritePort.addr.put(r.index);
    regWritePort.data <= value;
  }

  MicroRVCore({
    required Logic clk,
    required Logic reset,
    required Logic imem_en,
    required Logic imem_valid,
    required Logic imem_data,
    required Logic dmem_rdata,
    required Logic dmem_ready,
  }) : super(name: 'MicroRVCore') {
    // Clock & reset inputs
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    // Instruction & data memory inputs
    imem_en = addInput('imem_en', imem_en);
    imem_valid = addInput('imem_valid', imem_valid);
    imem_data = addInput('imem_data', imem_data, width: 32);
    dmem_rdata = addInput('dmem_rdata', dmem_rdata, width: 32);
    dmem_ready = addInput('dmem_ready', dmem_ready);

    // Program counter & instruction register output
    addOutput('pc', width: 32);
    addOutput('ir', width: 32);

    // Instruction memory output
    addOutput('imem_addr', width: 32);
    addOutput('imem_ready');

    // Data memory output
    addOutput('dmem_addr', width: 32);
    addOutput('dmem_wdata', width: 32);
    addOutput('dmem_we');
    addOutput('dmem_re');
    addOutput('dmem_mask', width: 4);
    addOutput('dmem_valid');

    // Register file
    regWritePort = DataPortInterface(32, 5);
    regReadPort1 = DataPortInterface(32, 5);
    regReadPort2 = DataPortInterface(32, 5);

    regFile = RegisterFile(
      clk,
      reset,
      [regWritePort],
      [regReadPort1, regReadPort2],
      numEntries: MicroRVRegister.values.length,
      name: 'MicroRVRegisterFile',
    );

    // Program counter setup
    final next_pc = Logic(name: 'next_pc', width: 32);
    final pc_reg = FlipFlop(clk, next_pc, reset: reset, name: 'pc_reg');

    imem_en.put(1);
    pc <= pc_reg.q;
    imem_addr <= pc_reg.q;

    // Instruction register
    final next_ir = Logic(name: 'next_ir', width: 32);
    final ir_reg = FlipFlop(clk, next_ir, reset: reset, name: 'ir_reg');
    ir <= ir_reg.q;

    Combinational([
      If.block([
        Iff(imem_valid, [
          next_ir < imem_data,
          next_pc < pc_reg.q + Const(4, width: 32),
        ]),
        Else([next_ir < ir_reg.q, next_pc < pc_reg.q]),
      ]),
    ]);

    decoder = MicroRVDecoder(next_ir);

    exec = MicroRVExecutor(
      clk: clk,
      opcode: decoder.opcode,
      rd: decoder.rd,
      funct3: decoder.funct3,
      rs1: decoder.rs1,
      rs2: decoder.rs2,
      funct7: decoder.funct7,
      imm_i: decoder.imm_i,
      regReadPort1: regReadPort1,
      regReadPort2: regReadPort2,
    );

    wb = MicroRVWriteBack(
      result: exec.result,
      target: exec.target,
      targetAddr: exec.targetAddr,
      regWritePort: regWritePort,
    );
  }

  String toStateString() => """
PC: ${pc.value}
IR: ${ir.value}
Instruction:
${decoder.toStateString().split('\n').map((line) => '- $line').join('\n')}

Instruction Memory:
- Address: ${imem_addr.value}
- Ready: ${imem_ready.value}

Registers:
${MicroRVRegister.values.map((reg) => '- ${reg.name}: ${regFile.getData(LogicValue.ofInt(reg.index, 5))}').join('\n')}""";
}
