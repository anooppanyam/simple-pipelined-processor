# Uttam Rao (ur6yr)

register pP {  
	pc:64 = 0; # 64-bits wide; 0 is its default value.
} 

pc = P_pc;

wire opcode:8, icode:4, valC:64, rB:4, rA:4, ifun:4;

opcode = i10bytes[0..8];   # first byte read from instruction memory
icode = opcode[4..8];      # top nibble of that byte
ifun = opcode[0..4];
valC = [
	icode == JXX : i10bytes[8..72];
	1	     : i10bytes[16..80];
];
rA = i10bytes[12..16];
rB = i10bytes[8..12];

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}

wire valE:64;



Stat = [
	icode == NOP    : STAT_AOK;
	icode == JXX    : STAT_AOK;
	icode == IRMOVQ : STAT_AOK;
	icode == RRMOVQ : STAT_AOK;
	icode == OPQ    : STAT_AOK;
	icode == CMOVXX : STAT_AOK;
	icode == RMMOVQ : STAT_AOK;
	icode == MRMOVQ : STAT_AOK;
	icode == HALT   : STAT_HLT;
	1               : STAT_INS;
];

reg_srcA = [
	icode == RRMOVQ : rA;
	icode == OPQ    : rA;
	icode == RMMOVQ : rA;
	1		: REG_NONE;
];

reg_srcB = [
	icode == OPQ    : rB;
	icode == RMMOVQ : rB;
	icode == MRMOVQ : rB;
	1		: REG_NONE;
];

reg_dstE = [
	!conditionsMet && icode == CMOVXX : REG_NONE;
	icode == IRMOVQ : rB;
	icode == RRMOVQ : rB;
	icode == OPQ    : rB;
	icode == MRMOVQ	: rA;
	1		: REG_NONE;
];

reg_inputE = [

	icode == IRMOVQ : valC;
	icode == RRMOVQ : reg_outputA;
	icode == OPQ	: valE;
	icode == MRMOVQ	: mem_output;
	1		: 0;
];


valE = [
	icode == OPQ && ifun == XORQ : reg_outputA ^ reg_outputB;
	icode == OPQ && ifun == ADDQ : reg_outputA + reg_outputB;
	icode == OPQ && ifun == SUBQ : reg_outputB - reg_outputA;
	icode == OPQ && ifun == ANDQ : reg_outputA & reg_outputB;
	icode == RMMOVQ 	     : reg_outputB + valC;
	icode == MRMOVQ 	     : reg_outputB + valC;
	1			     : 0;
];

mem_addr = valE;
mem_input = reg_outputA;
mem_readbit = [
	icode == MRMOVQ : 1;
	1		: 0;
];
mem_writebit = [
	icode == RMMOVQ : 1;
	1		: 0;
];


c_ZF = (valE == 0);
c_SF = (valE >= 0x8000000000000000);
stall_C = (icode != OPQ);

wire conditionsMet:1;
conditionsMet= [
	ifun == LE 	: C_SF || C_ZF;
	ifun == LT 	: C_SF;
	ifun == EQ 	: C_ZF;
	ifun == GE 	: !C_SF || C_ZF;
	ifun == GT 	: !C_SF && !C_ZF;
	ifun == NE 	: !C_ZF;
	ifun == ALWAYS  : 1;
	1	        : 0;
];


wire mux : 64;
mux = [

	icode == NOP    		: P_pc + 1;
	icode == JXX && conditionsMet   : valC;
	icode == JXX && !conditionsMet  : P_pc + 9;
	icode == IRMOVQ 		: P_pc + 10;
	icode == RRMOVQ 		: P_pc + 2;
	icode == OPQ			: P_pc + 2;
	icode == RMMOVQ			: P_pc + 10;
	icode == CMOVXX			: P_pc + 2;
	icode == MRMOVQ 		: P_pc + 10;
	icode == HALT			: P_pc + 1;
	1	        		: 0xBADBADBAD;
];
	

p_pc = mux;

