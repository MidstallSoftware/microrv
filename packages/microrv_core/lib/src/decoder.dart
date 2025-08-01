import 'package:rohd/rohd.dart';

class MicroRVDecoder extends Module {
  Logic get opcode => output('opcode');
  Logic get rd => output('rd');
  Logic get funct3 => output('funct3');
  Logic get rs1 => output('rs1');
  Logic get rs2 => output('rs2');
  Logic get funct7 => output('funct7');

  Logic get imm_i => output('imm_i');

  MicroRVDecoder(Logic ir) : super(name: 'MicroRVDecoder') {
    ir = addInput('ir', ir, width: 32);

    addOutput('opcode', width: 7);
    addOutput('rd', width: 5);
    addOutput('funct3', width: 3);
    addOutput('rs1', width: 5);
    addOutput('rs2', width: 5);
    addOutput('funct7', width: 7);

    addOutput('imm_i', width: 32);

    final opcodeValue = Logic(name: 'opcode', width: 7);
    final rdValue = Logic(name: 'rd', width: 5);
    final funct3Value = Logic(name: 'funct3', width: 3);
    final rs1Value = Logic(name: 'rs1', width: 5);
    final rs2Value = Logic(name: 'rs2', width: 5);
    final funct7Value = Logic(name: 'funct7', width: 7);

    final immIValue = Logic(name: 'imm_i', width: 32);

    opcode <= opcodeValue;
    rd <= rdValue;
    funct3 <= funct3Value;
    rs1 <= rs1Value;
    rs2 <= rs2Value;
    funct7 <= funct7Value;

    imm_i <= immIValue;

    Combinational([
      opcodeValue < ir.slice(6, 0),
      rdValue < ir.slice(11, 7),
      funct3Value < ir.slice(14, 12),
      rs1Value < ir.slice(19, 15),
      rs2Value < ir.slice(24, 20),
      funct7Value < ir.slice(31, 25),
    ]);

    Combinational([immIValue < ir.slice(31, 20).signExtend(32)]);
  }

  String toStateString() => """
Opcode: ${opcode.value}
RD: ${rd.value}
Func3: ${funct3.value}
RS1: ${rs1.value}
RS2: ${rs2.value}
Func7: ${funct7.value}""";
}
