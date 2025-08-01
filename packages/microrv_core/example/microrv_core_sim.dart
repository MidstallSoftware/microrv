import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:microrv_core/microrv_core.dart';

void main() async {
  final clk = SimpleClockGenerator(14).clk;
  final reset = Logic(name: 'reset');

  final imem_en = Logic(name: 'imem_en');
  final imem_addr = Logic(name: 'imem_addr', width: 5);

  final rom = MicroRVROM(
    clk: clk,
    en: imem_en,
    addr: imem_addr,
    program: {
      0: 0x00100093,
      1: 0xfff00113,
      2: 0xfff00193,
      3: 0x0ff0a213,
      4: 0x0f00a293,
      5: 0x00f0a313,
      6: 0x0030a393,
      7: 0x0020a413,
      8: 0x4020a493,
    },
  );

  final dmem_rdata = Logic(name: 'dmem_rdata', width: 32);
  final dmem_ready = Logic(name: 'dmem_ready');

  final core = MicroRVCore(
    reset: reset,
    clk: clk,
    imem_en: imem_en,
    imem_valid: rom.valid,
    imem_data: rom.data,
    dmem_rdata: dmem_rdata,
    dmem_ready: dmem_ready,
  );

  imem_addr <= core.imem_addr.slice(6, 2);

  await core.build();

  WaveDumper(core);

  Simulator.setMaxSimTime(1000);
  unawaited(Simulator.run());

  reset.inject(1);
  await clk.waitCycles(2); // ensure reset propagates
  reset.inject(0);

  while (true) {
    if (core.pc.value.toInt() > 8) break;
    print('clk cycle ----------------');
    print('rom.valid: ${rom.valid.value}');
    print('rom.en: ${imem_en.value}');
    print('rom.addr: ${imem_addr.value}');
    print('rom.data: ${rom.data.value}');
    print('core.pc: ${core.pc.value}');
    print('core.ir: ${core.ir.value}');
    print('core.imem_addr: ${core.imem_addr.value}');
    print(core.toStateString());
    await clk.waitCycles(1);
  }

  await Simulator.endSimulation();
}
