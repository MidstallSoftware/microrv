import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

import 'decoder.dart';
import 'exec.dart';
import 'fetch.dart';
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
  late MicroRVFetcher fetcher;
  late MicroRVDecoder decoder;
  late MicroRVExecutor exec;
  late MicroRVWriteBack wb;

  late DataPortInterface regWritePort;
  late DataPortInterface regReadPort1;
  late DataPortInterface regReadPort2;

  Logic get imem_en => output('imem_en');
  Logic get imem_addr => output('imem_addr');

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
    required Logic imem_valid,
    required Logic imem_data,
    required Logic dmem_rdata,
    required Logic dmem_ready,
  }) : super(name: 'MicroRVCore') {
    // Clock & reset inputs
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    // Instruction & data memory inputs
    imem_valid = addInput('imem_valid', imem_valid);
    imem_data = addInput('imem_data', imem_data, width: 32);
    dmem_rdata = addInput('dmem_rdata', dmem_rdata, width: 32);
    dmem_ready = addInput('dmem_ready', dmem_ready);

    // Instruction memory output
    addOutput('imem_en');
    addOutput('imem_addr', width: 32);

    // Data memory output
    addOutput('dmem_addr', width: 32);
    addOutput('dmem_wdata', width: 32);
    addOutput('dmem_we');
    addOutput('dmem_re');
    addOutput('dmem_mask', width: 4);
    addOutput('dmem_valid');

    final resetSync = FlipFlop(clk, reset, name: 'reset_sync').q;

    // Register file
    regWritePort = DataPortInterface(32, 5);
    regReadPort1 = DataPortInterface(32, 5);
    regReadPort2 = DataPortInterface(32, 5);

    regFile = RegisterFile(
      clk,
      resetSync,
      [regWritePort],
      [regReadPort1, regReadPort2],
      numEntries: MicroRVRegister.values.length,
      name: 'MicroRVRegisterFile',
    );

    fetcher = MicroRVFetcher(
      clk: clk,
      reset: reset,
      imem_data: imem_data,
      imem_valid: imem_valid,
      enable: Const(1),
      stall: Const(0),
    );

    imem_addr <= fetcher.imem_addr;
    imem_en <= fetcher.imem_en;

    decoder = MicroRVDecoder(fetcher.ir);

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
      clk: clk,
      reset: reset,
      enable: exec.enable,
      result: exec.result,
      target: exec.target,
      targetAddr: exec.targetAddr,
      regWritePort: regWritePort,
    );
  }

  String toStateString() => """
Instruction Memory:
- Enable ${imem_en.value}
- Address: ${imem_addr.value}

Fetcher:
${fetcher.toStateString().split('\n').map((line) => '- $line').join('\n')}

Decoder:
${decoder.toStateString().split('\n').map((line) => '- $line').join('\n')}

Executor:
${exec.toStateString().split('\n').map((line) => '- $line').join('\n')}

Registers:
${MicroRVRegister.values.map((reg) => '- ${reg.name}: ${regFile.getData(LogicValue.ofInt(reg.index, 5))}').join('\n')}""";
}
