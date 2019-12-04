# Uttam Rao
########## the PC and condition codes registers #############
register fF { predPC:64 = 0; }


########## Fetch #############
register fD {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	valP:64 = 0;
	Stat:3 = STAT_BUB;
	
}

pc = [
     M_icode == JXX && !M_cnd : M_valA;
     1 : F_predPC;
];


f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];

f_valC = [
	f_icode in { JXX } : i10bytes[8..72];
	1 : i10bytes[16..80];
];

wire offset:64;
offset = [
	f_icode in { HALT, NOP, RET } : 1;
	f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { RMMOVQ, MRMOVQ} : 10;
	f_icode in { JXX, CALL } : 9;
	1 : 10;
];
f_valP = pc + offset;

f_Stat = [
	f_icode == HALT : STAT_HLT;
	f_icode > 0xb : STAT_INS;
	1 : STAT_AOK;
];

stall_F = loadUse || (f_Stat != STAT_AOK);


########## Decode #############
wire loadUse:1;
loadUse = [
    e_icode == MRMOVQ && (reg_srcA == e_dstM || reg_srcB == e_dstM) : 1;
    1 : 0;
];
stall_D = loadUse;
bubble_D = e_icode == JXX && !e_cnd;
bubble_E = loadUse || (e_icode == JXX && !e_cnd);

register dE {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	valA:64 = 0;
	valB:64 = 0;
	dstE:4 = REG_NONE;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_BUB;
	
}

d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_rA = D_rA;
d_rB = D_rB;
d_valC = D_valC;
d_dstE = [
	d_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : D_rB;
	1 : REG_NONE;
];
d_dstM = [
	d_icode in {MRMOVQ} : D_rA;
	1: REG_NONE;
];
d_valA = [
	D_icode == JXX : D_valP;
	reg_srcA == e_dstE && e_dstE != REG_NONE : e_valE;
	reg_srcA == m_dstE && m_dstE != REG_NONE : m_valE;
	reg_dstE == reg_srcA && reg_dstE != REG_NONE : reg_inputE;
	reg_srcA == REG_NONE : 0;
    	reg_srcA == m_dstM : m_valM;
    	reg_srcA == W_dstM : W_valM;
	1 : reg_outputA;
];

d_valB = [
	reg_srcB == e_dstE && e_dstE != REG_NONE : e_valE;
	reg_srcB == m_dstE && m_dstE != REG_NONE : m_valE;
	reg_dstE == reg_srcB && reg_dstE != REG_NONE : reg_inputE;
    	reg_srcB == REG_NONE : 0;
    	reg_srcB == m_dstM : m_valM;
    	reg_srcB == W_dstM : W_valM;
	1 : reg_outputB;
];


# source selection
reg_srcA = [
	d_icode in {RMMOVQ, RRMOVQ, CMOVXX, OPQ} : D_rA;
	d_icode in {RMMOVQ} : D_rA;
	1 : REG_NONE;
];

reg_srcB = [
	d_icode in {RRMOVQ, CMOVXX, OPQ} : D_rB;
	d_icode in {RMMOVQ, MRMOVQ} : D_rB;
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
	dstM:4 = REG_NONE;
	Stat:3 = STAT_BUB;
	
}

e_Stat = E_Stat;
e_icode = E_icode;
e_valA = E_valA;
e_dstM = E_dstM;
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
       1 : E_dstE;
];


########## Memory #############
register mW {
	
	icode:4 = NOP;
	valA:64 = 0;
	valE:64 = 0;
	valM:64 = 0;
	dstE:4 = REG_NONE;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_BUB;
	
}

m_Stat = M_Stat;
m_icode = M_icode;
m_valE = M_valE;
m_valA = M_valA;
m_dstE = M_dstE;
m_dstM = M_dstM;
mem_readbit = M_icode in { MRMOVQ };
mem_writebit = M_icode in { RMMOVQ };
mem_addr = [
        M_icode in { MRMOVQ, RMMOVQ } : M_valE;
        1: 0xBADBADBAD;
];
mem_input = [
        M_icode in { RMMOVQ } : M_valA;
        1: 0xBADBADBAD;
];

m_valM = mem_output;





########## Writeback #############


# destination selection
reg_dstE = W_dstE;
reg_dstM = W_dstM;

reg_inputM = [
        W_icode in {MRMOVQ} : W_valM;
        1: 0xBADBADBAD;
];

reg_inputE = [ # unlike book, we handle the "forwarding" actions (something + 0) here
	W_icode in {RRMOVQ, IRMOVQ} : W_valE;
	W_icode in {IRMOVQ, OPQ, CMOVXX} : W_valE;
	W_icode == MRMOVQ : W_valM;
        1: 0xBADBADBAD;
];


########## PC and Status updates #############

Stat = W_Stat;

f_predPC = [
	 f_Stat != STAT_AOK : pc;
	 f_icode == JXX : f_valC;
	 1 : f_valP;
];



