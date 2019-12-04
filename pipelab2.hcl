# -*-sh-*- # this line enables partial syntax highlighting in emacs

######### The PC #############
register fF { pc:64 = 0; }


########## Fetch #############
pc = F_pc;


f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];

f_valC = [
        f_icode in { JXX } : i10bytes[8..72];
        1 : i10bytes[16..80];
];

wire offset:64, valP:64;
offset = [
        f_icode in { HALT, NOP, RET } : 1;
        f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { RMMOVQ, MRMOVQ} : 10;
        f_icode in { JXX, CALL } : 9;
        1 : 10;
];
valP = F_pc + offset;



########## Decode #############
wire loadUse:1;

loadUse = [
	((E_dstM == D_rA) || (E_dstM == D_rB)) && D_icode == MRMOVQ : 1;
	((E_dstM == f_rA) || (E_dstM == f_rB)) && f_icode == MRMOVQ : 1;
	1 : 0;
];

stall_F = loadUse || (f_Stat != STAT_AOK);
stall_D = loadUse;
bubble_E = loadUse;

register fD {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	Stat:3 = STAT_AOK;
	
}

reg_srcA = [
        D_icode in {RMMOVQ} : D_rA;
        1 : REG_NONE;
];
reg_srcB = [
        D_icode in {RMMOVQ, MRMOVQ} : D_rB;
        1 : REG_NONE;
];

d_dstM = [ 
        D_icode in {MRMOVQ} : D_rA;
        1: REG_NONE;
];

########## Execute #############
register dE {
	
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64	= 0;
	valA:64 = 0;
	valB:64 = 0;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

d_Stat = D_Stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_rA = D_rA;
d_rB = D_rB;
d_valC = D_valC;
d_valA = [
	reg_srcA == REG_NONE : 0;
	reg_srcA == m_dstM : m_valM;
	reg_srcA == W_dstM : W_valM;
	1 : reg_outputA;
];
d_valB = [
	reg_srcB == REG_NONE : 0;
	reg_srcB == m_dstM : m_valM;
	reg_srcB == W_dstM : W_valM;
	1 : reg_outputB;
];

wire operand1:64, operand2:64;

operand1 = [
        E_icode in { MRMOVQ, RMMOVQ } : E_valC;
        1: 0;
];
operand2 = [
        E_icode in { MRMOVQ, RMMOVQ } : E_valB;
        1: 0;
];

wire valE:64;

valE = [
        E_icode in { MRMOVQ, RMMOVQ } : operand1 + operand2;
        1 : 0;
];



########## Memory #############
register eM {
	
	icode:4 = NOP;
	valE:64	= 0;
	valA:64 = 0;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

e_Stat = E_Stat;
e_icode = E_icode;
e_valE = valE;
e_valA = E_valA;
e_dstM = E_dstM;

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

########## Writeback #############
register mW {
	
	icode:4 = NOP;
	valM:64	= 0;
	valA:64 = 0;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	
}

m_Stat = M_Stat;
m_icode = M_icode;
m_valM = mem_output;
m_dstM = M_dstM;
m_valA = M_valA;

reg_dstM = W_dstM;

reg_inputM = [
        W_icode in {MRMOVQ} : W_valM;
        1: 0xBADBADBAD;
];


f_Stat = [
        f_icode == HALT : STAT_HLT;
        f_icode > 0xb : STAT_INS;
        1 : STAT_AOK;
];
Stat = W_Stat;

f_pc = valP;


