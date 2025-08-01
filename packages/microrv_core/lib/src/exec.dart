import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

enum MicroRVOpcode {
  lui(0x37),
  auipc(0x17),
  jal(0x6F),
  jalr(0x67),
  branch(0x63),
  load(0x3),
  store(0x23),
  imm(0x13),
  reg(0x33),
  fence(0xF),
  system(0x73);

  const MicroRVOpcode(this.value);

  final int value;
  Logic get logic => Const(value, width: 7);

  static MicroRVOpcode? decode(Logic bits) {
    for (final val in MicroRVOpcode.values) {
      if (val.value == bits.value.toInt()) return val;
    }
    return null;
  }
}

Logic sltu(Logic a, Logic b) {
  Logic result = Const(0, width: 1);
  for (int i = 0; i < a.width; i++) {
    final abit = a[i];
    final bbit = b[i];

    result = mux(abit.eq(bbit), result, ~abit & bbit);
  }
  return result;
}

class MicroRVExecutor extends Module {
  MicroRVExecutor({
    required Logic opcode,
    required Logic rd,
    required Logic funct3,
    required Logic rs1,
    required Logic rs2,
    required Logic funct7,
    required Logic imm_i,
    required DataPortInterface regWritePort,
    required DataPortInterface regReadPort1,
    required DataPortInterface regReadPort2,
  }) : super(name: 'MicroRVExecutor') {
    opcode = addInput('opcode', opcode, width: 7);
    rd = addInput('rd', rd, width: 5);
    funct3 = addInput('funct3', funct3, width: 3);
    rs1 = addInput('rs1', rs1, width: 5);
    rs2 = addInput('rs2', rs2, width: 5);
    funct7 = addInput('funct7', funct7, width: 7);

    imm_i = addInput('imm_i', imm_i, width: 32);

    regWritePort = DataPortInterface(32, 5)
      ..connectIO(this, regWritePort,
        outputTags: {DataPortGroup.data, DataPortGroup.control},
        uniquify: (original) => 'regWritePort_${original}',
      );

    regReadPort1 = DataPortInterface(32, 5)
      ..connectIO(this, regReadPort1,
        outputTags: {DataPortGroup.control},
        inputTags: {DataPortGroup.data}, 
        uniquify: (original) => 'regReadPort1_${original}',
      );

    regReadPort2 = DataPortInterface(32, 5)
      ..connectIO(this, regReadPort2,
        outputTags: {DataPortGroup.control},
        inputTags: {DataPortGroup.data},
        uniquify: (original) => 'regReadPort2_${original}',
      );

    final result = Logic(name: 'result', width: 32);

    Combinational([
      If.block([
        Iff(opcode.eq(MicroRVOpcode.imm.logic), [
          regReadPort1.en < 1,
          regReadPort1.addr < rs1,
          If.block([
            Iff(funct3.eq(Const(0, width: 3)), [
              result < regReadPort1.data + imm_i,
            ]),
            Iff(funct3.eq(Const(1, width: 3)), [
              result < (regReadPort1.data << imm_i),
            ]),
            Iff(funct3.eq(Const(2, width: 3)), [
              result < mux(regReadPort1.data[31] ^ imm_i[31], regReadPort1.data[31], regReadPort1.data[31].lt(imm_i[31])).zeroExtend(32),
            ]),
            Iff(funct3.eq(Const(3, width: 3)), [
              result < sltu(regReadPort1.data, imm_i).zeroExtend(32),
            ]),
            Iff(funct3.eq(Const(4, width: 3)), [
              result < regReadPort1.data ^ imm_i,
            ]),
            Iff(funct3.eq(Const(5, width: 3)), [
              If.block([
                Iff(funct7.eq(Const(0, width: 7)), [
                  result < regReadPort1.data >> imm_i.slice(4, 0),
                ]),
                Iff(funct7.eq(Const(32, width: 7)), [
                  result < mux(regReadPort1.data[31], Const(-1, width: 32) << (Const(32, width: 32) - (regReadPort1.data >> imm_i.slice(4, 0))), regReadPort1.data >> imm_i.slice(4, 0)),
                ]),
                // TODO: illegal instruction
              ]),
              result < regReadPort1.data ^ imm_i,
            ]),
          ]),
          // TODO: illegal instruction
        ]),
      ]),
      // TODO: illegal instruction
    ]);

    Combinational([
      If.block([
        Iff(opcode.eq(MicroRVOpcode.imm.logic), [
          regWritePort.en < 1,
          regWritePort.addr < rd,
          regWritePort.data < result,
        ]),
      ]),
    ]);
  }
}
