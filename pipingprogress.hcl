########## the PC and condition codes registers #############
register fF { pc:64 = 0; }


########## Fetch #############
register fD {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	valP:64 = 0;
	Stat:3 = STAT_AOK;
	
}

pc = F_pc;


f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];
f_valP = valP;

f_valC = [
	f_icode in { JXX } : i10bytes[8..72];
	1 : i10bytes[16..80];
];

wire offset:64, valP:64;
offset = [
	f_icode in { HALT, NOP, RET } : 1;
	f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { JXX, CALL } : 9;
	1 : 10;
];
valP = F_pc + offset;

f_Stat = [
	f_icode == HALT : STAT_HLT;
	f_icode > 0xb : STAT_INS;
	1 : STAT_AOK;
];

stall_F = (f_Stat != STAT_AOK);


########## Decode #############
register dE {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	valA:64 = 0;
	valB:64 = 0;
	dstE:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_rA = D_rA;
d_rB = D_rB;
d_valC = D_valC;
d_dstE = [
	d_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : d_rB;
	1 : REG_NONE;
];
d_valA = [
	reg_srcA == e_dstE && reg_srcA != REG_NONE: e_valE;
	reg_srcA == m_dstE && reg_srcA != REG_NONE: m_valE;
	reg_srcA == W_dstE && reg_srcA != REG_NONE: W_valE;
	1 : reg_outputA;
];

d_valB = [
	reg_srcB == e_dstE && reg_srcB != REG_NONE : e_valE;
	reg_srcB == m_dstE && reg_srcB != REG_NONE : m_valE;
	reg_srcB == W_dstE && reg_srcB != REG_NONE: W_valE;
	1 : reg_outputB;
];


# source selection
reg_srcA = [
	d_icode in {RRMOVQ, CMOVXX, OPQ} : d_rA;
	1 : REG_NONE;
];

reg_srcB = [
	d_icode in {RRMOVQ, CMOVXX, OPQ} : d_rB;
	1 : REG_NONE;
];


########## Execute #############
register cC {
	SF:1 = 0;
	ZF:1 = 1;
}

c_ZF = (e_valE == 0);
c_SF = (e_valE >= 0x8000000000000000);
stall_C = (e_icode != OPQ);

register eM {
	
	icode:4 = NOP;
	valE:64 = 0;
	valA:64 = 0;
	cnd:1 = 0;
	dstE:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

e_Stat = E_Stat;
e_icode = E_icode;
e_valA = E_valA;
e_valE = [
	E_icode == IRMOVQ : E_valC;
	E_icode == RRMOVQ : E_valA;
	E_icode == CMOVXX : E_valA;
	E_icode == OPQ && E_ifun == XORQ : E_valA ^ E_valB;
	E_icode == OPQ && E_ifun == ADDQ : E_valA + E_valB;
	E_icode == OPQ && E_ifun == SUBQ : E_valB - E_valA;
	E_icode == OPQ && E_ifun == ANDQ : E_valA & E_valB;
	E_icode == RMMOVQ 	     : E_valB + E_valC;
	E_icode == MRMOVQ 	     : E_valB + E_valC;
	1			     : 0;
];
e_cnd = [
	E_ifun == LE 	: C_SF || C_ZF;
	E_ifun == LT 	: C_SF;
	E_ifun == EQ 	: C_ZF;
	E_ifun == GE 	: !C_SF || C_ZF;
	E_ifun == GT 	: !C_SF && !C_ZF;
	E_ifun == NE 	: !C_ZF;
	E_ifun == ALWAYS  : 1;
	1	        : 0;
];

e_dstE = [
	!e_cnd && e_icode == CMOVXX : REG_NONE;
	e_icode == IRMOVQ : E_rB;
	e_icode == RRMOVQ : E_rB;
	e_icode == OPQ    : E_rB;
	e_icode == MRMOVQ	: E_rA;
	1		: REG_NONE;
];


########## Memory #############
register mW {
	
	icode:4 = NOP;
	valE:64 = 0;
	valM:64 = 0;
	dstE:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

m_Stat = M_Stat;
m_icode = M_icode;
m_valE = M_valE;
m_dstE = M_dstE;
mem_addr = m_valE;
mem_input = M_valA;
mem_readbit = [
	m_icode == MRMOVQ : 1;
	1		: 0;
];
mem_writebit = [
	m_icode == RMMOVQ : 1;
	1		: 0;
];

m_valM = mem_output;





########## Writeback #############


# destination selection
reg_dstE = W_dstE;

reg_inputE = [ # unlike book, we handle the "forwarding" actions (something + 0) here
	W_icode == RRMOVQ : W_valE;
	W_icode in {IRMOVQ, OPQ, CMOVXX} : W_valE;
	W_icode == MRMOVQ : W_valM;
        1: 0xBADBADBAD;
];


########## PC and Status updates #############

Stat = W_Stat;

f_pc = valP;



