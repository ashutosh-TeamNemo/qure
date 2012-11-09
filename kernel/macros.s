############################################################################
# Sections (.text, .data etc).

.macro .text16
	TEXTSUBSECTION = 0
	.text SECTION_CODE_TEXT16	# 0
	.code16
.endm

.macro .data16
	.text SECTION_CODE_DATA16	# 1
.endm

.macro .text16end
	.text SECTION_CODE_TEXT16_END	# 2
	.code16
.endm

.macro .text32
	TEXTSUBSECTION = 3
	.text SECTION_CODE_TEXT32	# 3
	.code32
.endm

.macro .code16_
	CODEBITS = 16
	.code16
.endm

.macro .code32_
	CODEBITS = 32
	.code32
.endm


_TLS_SIZE = 0
.macro .tdata
.struct _TLS_SIZE
.endm

.macro .tdata_end
_TLS_SIZE = .
.text32
.endm

.macro .previous
	.if TEXTSUBSECTION == 0
		.text16
	.else
	.if TEXTSUBSECTION == 3
		.text32
	.else
	.error "Unknown text subsection"
	.print TEXTSUBSECTOIN
	.endif
	.endif
	
	.ifdef CODEBITS
	.if CODEBITS == 16
		.code16
	.else
	.if CODEBITS == 32
		.code32
	.endif
	.endif
	.endif
.endm

##############################################################################
# opcodes

INTEL_ARCHITECTURE = 6	# 386 (32 bit)

.if INTEL_ARCHITECTURE < 6
##########################################
## Generated by util/genopcodemacros.pl ##

.macro cmov cond, invcond, src, dst
	.if INTEL_ARCHITECTURE >= 6
		cmov\cond	\src, \dst
	.else
		j\invcond	600f
		mov	\src, \dst
600:
	.endif
.endm
.macro cmove src, dst
	cmov e, ne, \src, \dst
.endm
cmovz=cmove
.macro cmovne src, dst
	cmov ne, e, \src, \dst
.endm
cmovnz=cmovne
.macro cmova src, dst
	cmov a, be, \src, \dst
.endm
cmovnbe=cmova
.macro cmovbe src, dst
	cmov be, a, \src, \dst
.endm
cmovna=cmovbe
.macro cmovae src, dst
	cmov ae, b, \src, \dst
.endm
cmovnb=cmovae
.macro cmovb src, dst
	cmov b, ae, \src, \dst
.endm
cmovnae=cmovb
.macro cmovg src, dst
	cmov g, le, \src, \dst
.endm
cmovnle=cmovg
.macro cmovle src, dst
	cmov le, g, \src, \dst
.endm
cmovng=cmovle
.macro cmovge src, dst
	cmov ge, l, \src, \dst
.endm
cmovnl=cmovge
.macro cmovl src, dst
	cmov l, ge, \src, \dst
.endm
cmovnge=cmovl
.macro cmovp src, dst
	cmov p, np, \src, \dst
.endm
cmovpe=cmovp
.macro cmovnp src, dst
	cmov np, p, \src, \dst
.endm
cmovpo=cmovnp
.macro cmovc src, dst
	cmov c, nc, \src, \dst
.endm
.macro cmovnc src, dst
	cmov nc, c, \src, \dst
.endm
.macro cmovo src, dst
	cmov o, no, \src, \dst
.endm
.macro cmovno src, dst
	cmov no, o, \src, \dst
.endm
.macro cmovs src, dst
	cmov s, ns, \src, \dst
.endm
.macro cmovns src, dst
	cmov ns, s, \src, \dst
.endm

## end of generated code #####
##############################
.endif
