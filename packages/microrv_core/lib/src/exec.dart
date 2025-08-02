import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'write_back.dart';

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

enum MicroRVInstruction {
  addi(MicroRVOpcode.imm, 0, null),
  slli(MicroRVOpcode.imm, 0x1, 0),
  slti(MicroRVOpcode.imm, 0x2, null),
  sltiu(MicroRVOpcode.imm, 0x3, null),
  srli(MicroRVOpcode.imm, 0x5, 0),
  srai(MicroRVOpcode.imm, 0x5, 0x20),
  xori(MicroRVOpcode.imm, 0x4, 0),
  ori(MicroRVOpcode.imm, 0x6, null),
  andi(MicroRVOpcode.imm, 0x7, null);

  const MicroRVInstruction(this.opcode, this.funct3, this.funct7);

  final MicroRVOpcode opcode;
  final int funct3;
  final int? funct7;

  LogicValue get value => LogicValue.ofIterable([
    LogicValue.ofInt(opcode.index, 7),
    LogicValue.ofInt(funct3, 3),
    LogicValue.ofInt(funct7 ?? 0, 7),
  ]);

  static List<MicroRVInstruction> get ignoreFunct7Set =>
      MicroRVInstruction.values.where((i) => i.funct7 == null).toList();
}

Logic _sltiu(Logic a, Logic b) {
  Logic result = Const(0, width: 1);
  for (int i = 0; i < a.width; i++) {
    final abit = a[i];
    final bbit = b[i];

    result = mux(abit.eq(bbit), result, ~abit & bbit);
  }
  return result;
}

Logic _arithmeticRightShift(Logic value, Logic shamt) {
  final width = value.width;
  final msb = value[width - 1];
  final shifted = value >> shamt;

  final fillMask = Logic(name: 'fillMask', width: width);
  fillMask.inject(LogicValue.filled(width, msb.value));

  final one = Const(1, width: width);
  final shiftedOnes = one << shamt;
  final dynamicMask = ~(shiftedOnes - Const(1, width: width));

  final signFill = fillMask & dynamicMask;
  return shifted | signFill;
}

class MicroRVExecutor extends Module {
  Logic get enable => output('enable');
  Logic get result => output('result');
  Logic get target => output('target');
  Logic get targetAddr => output('targetAddr');
  Logic get valid => output('valid');

  MicroRVExecutor({
    required Logic clk,
    required Logic opcode,
    required Logic rd,
    required Logic funct3,
    required Logic rs1,
    required Logic rs2,
    required Logic funct7,
    required Logic imm_i,
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

    addOutput('enable');
    addOutput('result', width: 32);
    addOutput('target', width: MicroRVWriteBackTarget.width);
    addOutput('targetAddr', width: 32);
    addOutput('valid');

    regReadPort1 = DataPortInterface(32, 5)..connectIO(
      this,
      regReadPort1,
      outputTags: {DataPortGroup.control},
      inputTags: {DataPortGroup.data},
      uniquify: (original) => 'regReadPort1_${original}',
    );

    regReadPort2 = DataPortInterface(32, 5)..connectIO(
      this,
      regReadPort2,
      outputTags: {DataPortGroup.control},
      inputTags: {DataPortGroup.data},
      uniquify: (original) => 'regReadPort2_${original}',
    );

    final enableVal = Logic(name: 'enable');
    enable <= enableVal;

    final resultVal = Logic(name: 'result', width: 32);
    result <= resultVal;

    final targetVal = Logic(
      name: 'target',
      width: MicroRVWriteBackTarget.width,
    );
    target <= targetVal;

    final targetAddrVal = Logic(name: 'targetAddr', width: 32);
    targetAddr <= targetAddrVal;

    final validVal = Logic(name: 'valid');
    valid <= validVal;

    final ignoreFunct7 = Logic(name: 'ignoreFunct7');

    Combinational([
      Case(
        [opcode, funct3].swizzle(),
        MicroRVInstruction.ignoreFunct7Set
            .map(
              (i) => CaseItem(Const(i.value.slice(9, 0)), [ignoreFunct7 < 1]),
            )
            .toList(),
        defaultItem: [ignoreFunct7 < 0],
      ),
    ]);

    final funct7Check = Logic(name: 'funct7Check', width: 7);

    funct7Check <= mux(ignoreFunct7, Const(0, width: 7), funct7);

    final instr = [opcode, funct3, funct7Check].swizzle();

    Combinational([
      Case(
        instr,
        [
          CaseItem(Const(MicroRVInstruction.addi.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data + imm_i,
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.slli.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data << imm_i.slice(4, 0),
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.slti.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal <
                mux(
                  regReadPort1.data[31] ^ imm_i[31],
                  regReadPort1.data[31],
                  regReadPort1.data.lt(imm_i),
                ).zeroExtend(32),
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.sltiu.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < _sltiu(regReadPort1.data, imm_i).zeroExtend(32),
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.srli.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data >> imm_i.slice(4, 0),
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.srai.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal <
                _arithmeticRightShift(regReadPort1.data, imm_i.slice(4, 0)),
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.xori.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data ^ imm_i,
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.ori.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data | imm_i,
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
          CaseItem(Const(MicroRVInstruction.andi.value), [
            regReadPort1.en < 1,
            regReadPort1.addr < rs1,
            resultVal < regReadPort1.data & imm_i,
            targetVal <
                Const(
                  MicroRVWriteBackTarget.reg.index,
                  width: MicroRVWriteBackTarget.width,
                ),
            targetAddrVal < rd.zeroExtend(32),
            enableVal < 1,
            validVal < 1,
          ]),
        ],
        defaultItem: [
          enableVal < 0,
          validVal < 0,
          targetVal < 0,
          targetAddrVal < 0,
          resultVal < 0,
          regReadPort1.en < 0,
          regReadPort1.addr < 0,
        ],
      ),
    ]);
  }

  String toStateString() => """
Enable: ${enable.value}
Result: ${result.value}
Target: ${target.value}
Target Address: ${targetAddr.value}
Valid: ${valid.value}""";
}
