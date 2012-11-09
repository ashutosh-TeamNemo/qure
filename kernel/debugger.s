######################################################################
.intel_syntax noprefix

.data SECTION_DATA_BSS
debug_registers$:	.space 4 * 32
kernel_symtab:		.long 0
kernel_symtab_size:	.long 0
kernel_stabs:		.long 0
kernel_stabs_size:	.long 0
.text32

debug_regstore$:
	mov	[debug_registers$ + 4 * 0], eax
	mov	[debug_registers$ + 4 * 1], ebx
	mov	[debug_registers$ + 4 * 2], ecx
	mov	[debug_registers$ + 4 * 3], edx
	mov	[debug_registers$ + 4 * 4], esi
	mov	[debug_registers$ + 4 * 5], edi
	mov	[debug_registers$ + 4 * 6], ebp
	mov	[debug_registers$ + 4 * 7], esp
	sub	[debug_registers$ + 4 * 7], dword ptr 6	# pushf/pushcolor adjust
	mov	[debug_registers$ + 4 * 8], cs
	mov	[debug_registers$ + 4 * 9], ds
	mov	[debug_registers$ + 4 * 10], es
	mov	[debug_registers$ + 4 * 11], ss
	ret


.macro DEBUG_REGDIFF0 nr, reg
	cmp	[debug_registers$ + 4 * \nr], \reg
	jz	188f
	print	"\reg: "
	push	edx
	mov	edx, [debug_registers$ + 4 * \nr]
	call	printhex8
	print	" -> "
	pop	edx
	push	edx
	mov	edx, \reg
	.if \reg == esp
	add	edx, 6
	.endif
	call	printhex8
	pop	edx
	call	newline
188:
.endm

.macro DEBUG_REGDIFF1 nr, reg
	push	eax
	mov	eax, \reg
	DEBUG_REGDIFF0 \nr, eax
	pop	eax
.endm


debug_regdiff$:
	pushf
	pushcolor 0xf4
	DEBUG_REGDIFF0 0, eax
	DEBUG_REGDIFF0 1, ebx
	DEBUG_REGDIFF0 2, ecx
	DEBUG_REGDIFF0 3, edx
	DEBUG_REGDIFF0 4, esi
	DEBUG_REGDIFF0 5, edi
	DEBUG_REGDIFF0 6, ebp
	DEBUG_REGDIFF0 7, esp
	DEBUG_REGDIFF1 8, cs
	DEBUG_REGDIFF1 9, ds
	DEBUG_REGDIFF1 10, es
	DEBUG_REGDIFF1 11, ss
	popcolor
	popf
	ret


.macro DEBUG_REGSTORE name=""
	DEBUG "\name"
	call	debug_regstore$
.endm
.macro DEBUG_REGDIFF
	call	debug_regdiff$
.endm


.macro BREAKPOINT label
	pushf
	push 	eax
	PRINTC 0xf0, "\label"
	xor	eax, eax
	call	keyboard
	pop	eax
	popf
.endm



.text32
debug_load_symboltable:
.if 0 # if ISO9660 implements multiple sector reading,
	LOAD_TXT "/a/BOOT/KERNEL.SYM", eax
	mov	cl, [boot_drive]
	add	cl, 'a'
	mov	[eax + 1], cl
	call	fs_openfile	# out: eax = file handle
	jc	1f
	call	fs_handle_read # in: eax = handle; out: esi, ecx
	jc	1f

	# copy buffer
	mov	eax, ecx
	call	malloc
	mov	[kernel_symtab], eax
	mov	[kernel_symtab_size], ecx
	mov	edi, eax
	rep	movsb
1:	call	fs_close
	ret
.elseif 1 # OR if bootloader also loads the symbol table.

DEBUG_RAMDISK_DIY=0
	.if DEBUG_RAMDISK_DIY
	movzx	eax, word ptr [bootloader_ds]
	movzx	ebx, word ptr [ramdisk]
	shl	eax, 4
	add	eax, ebx
	mov	bx, SEL_flatDS
	mov	fs, bx

	cmp	dword ptr fs:[eax + 0], 'R'|('A'<<8)|('M'<<16)|('D'<<24)
	jnz	9f
	cmp	dword ptr fs:[eax + 4], 'I'|('S'<<8)|('K'<<16)|('0'<<24)
	jnz	9f
	mov	ecx, fs:[eax + 8]
	cmp	ecx, 2
	jb	9f
	add	eax, 32
	.endif

	.macro DEBUG_LOAD_TABLE name, label

	.if DEBUG_RAMDISK_DIY
	mov	edx, fs:[eax + 4]	# load start
	.else
	mov	edx, [\name\()_load_start_flat]
	.endif
	or	edx, edx
	jz	9f
	I "Found \label: "
	GDT_GET_BASE eax, ds
	sub	edx, eax
	js	8f
	mov	[kernel_\name\()], edx
	mov	ebx, edx
	call	printhex8
	.if DEBUG_RAMDISK_DIY
	mov	edx, fs:[eax + 12]	# load end
	add	eax, 32
	.else
	mov	edx, [\name\()_load_end_flat]
	sub	edx, eax
	.endif
	printchar '-'
	call	printhex8
	I2 " size "
	sub	edx, ebx
	call	printhex8
	mov	[kernel_\name\()_size], edx
	I2 " symbols "
	mov	edx, [ebx]
	call	printdec32
	print " ("
	call	printhex8
	println ")"
	.endm

	DEBUG_LOAD_TABLE symtab, "symbol table"
	DEBUG_LOAD_TABLE stabs, "source line table"

	ret

8:	printlnc 12, "error: symboltable before kernel: "
	call	printhex8
	printc 12, "data base: "
	mov	eax, edx
	call	printhex8
9:	ret
.else # lame - require 2 builds due to the inclusion of output generated
	# after compilation.
	.data SECTION_DATA_STRINGS # not pure asciiz...
	ksym: .incbin "../root/boot/kernel.sym"
	0:
	.text32
	mov	[kernel_symtab], dword ptr offset ksym
	mov	[kernel_symtab_size], dword ptr (offset 0b - offset ksym)
	ret
.endif

# Idea:
# Specify another table, containing argument definitions.
# This table could be of equal length to the symbol table, containing relative
# offsets to the area after the string table.
# This table could be variable length (specified in symboltable), and would
# be needed to be rep-scasd't.
# An example of such a method is 'schedule', which is known to be an ISR-style method.
# The first argument on the stack - the next higher dword - is eax.
# The second argument is eip, the third cs, the fourth eflags.
# The table entry could then be a symbol reference table, where these symbols
# are merged in the main symbol table, or, a separate symbol table, to avoid scanning
# these special symbols in general scans.
#
# Approach 1:
# A second parameter ebp is used to check the symbol at a fixed distance
# in the stack to see if there is an argument that matches the distance.
# This could be encoded in a fixed-size array of words, one for each symbol,
# encoding the relative start/end offsets (min/max distance to the symbol).
# A second word could be an index into the argument list, capping the symbols to 65k.
#
# Approach 2:
# Or, when a symbol is found, it's argument data is looked-up
# and remembered in another register. Since the stack is traversed in an orderly
# fashion, anytime a new symbol is found - of a certain type - it replaces the current
# symbol. A register then is shared between the getsymbol method and the stack loop,
# containing a pointer to the argument definitions for the current symbol.
# Special care needs to be taken to avoid taking an argument as a return address.

# in: edx
# out: esi
# out: CF
debug_getsymbol:
	mov	esi, [kernel_symtab]
	or	esi, esi
	stc
	jz	9f

	push	ecx
	push	edi
	push	eax
	mov	eax, edx
	mov	ecx, [esi]
	lea	edi, [esi + 4]
	repnz	scasd
	stc
	jnz	1f

	mov	ecx, [esi]
	mov	edi, [edi - 4 + ecx * 4]
	lea	esi, [esi + 4 + ecx * 8]
	lea	esi, [esi + edi]
	clc
1:	pop	eax
	pop	edi
	pop	ecx
9:	ret


# Expects symboltable sorted by address.
#
# in: edx
# out: eax = preceeding symbol address
# out: esi = preceeding symbol label
# out: ebx = succeeding symbol address
# out: edi = succeeding symbol label
# out: CF
debug_get_preceeding_symbol:
	mov	esi, [kernel_symtab]
	or	esi, esi
	stc
	jz	9f

	push	ecx

	mov	ecx, [esi]

	cmp	edx, [esi + ecx * 4]
	cmc
	jb	8f	# dont yield results for out-of-range

	# O(log2(ecx))
	xor	eax, eax
0:	shr	ecx, 1
	jz	1f
2:	add	eax, ecx	# [....eax....]
	cmp	edx, [esi + 4 + eax * 4]
	jz	0f
	ja	0b		# [....|<eax....>]
	sub	eax, ecx	# [<eax....>|....]
	jmp	0b
# odd
1:	jnc	0f
	cmp	edx, [esi + 8 + eax * 4]
	jb	0f
	inc	eax

0:	mov	ecx, [esi]

	push	dword ptr [esi + 4 + eax * 4]	# preceeding symbol address
	push	dword ptr [esi + 8 + eax * 4]	# succeeding symbol address
	lea	ebx, [esi + 4 + ecx * 4]	#ebx->str offset array
	mov	edi, [ebx + eax * 4 + 4]# edi->str offset
	mov	eax, [ebx + eax * 4]	# eax->str offset
	lea	eax, [ebx + eax]	# eax = str ptr - ecx * 4
	lea	esi, [eax + ecx * 4]	# preceeding symbol label
	lea	edi, [ebx + edi]
	lea	edi, [edi + ecx * 4]# succeeding symbol label
	pop	ebx
	pop	eax

	clc
8:	pop	ecx

9:	ret


# The stabs format used here is generated by util/stabs.pl.
#
# The first dword is the number of line/addr entries, speciying the length
# of two arrays that follow it: first, an array of addresses, followed
# by an array of dwords with file and line encoded.
# Then follows a stringtable, where the first part is dword offsets
# relative to this stringtable, followed by the strings. The symboltable
# above uses a different approach as the length of the string array is
# equal to the other arrays, and thus the offset is relative to the start
# of the strings themselves.
#
# Example format, for 3 source lines spread over 2 source files:
# size: .long 3	# 3 addresses
# addr: .rept 3; .long 0xsomething; .endr
# data: .rept 3; .word line, sfidx; .endr
# strtb: .long s1 - strtb; .long s2 - strtb;
# s1: .asciz "foo";
# s2: .asciz "bar";
#
# For the symbol table used above, the strtb part would look like this:
# strtb: .long s1 - strings; .long s2 - strings;
# strings:
#  s1: .asciz "foo";
#  s2: .asciz "bar";

# in: edx = memory address
# out: esi = source filename
# out: eax = source line number
# out: CF
debug_getsource:
	mov	esi, [kernel_stabs]
	or	esi, esi
	stc
	jz	9f

	push	ecx
	push	edi
	mov	eax, edx
	mov	ecx, [esi]	# nr of lines/addresses
	lea	edi, [esi + 4]	# address array
	repnz	scasd
	stc
	jnz	1f
	mov	ecx, [esi]
	mov	edi, [edi - 4 + ecx * 4]	# [file<<16|line] array
	movzx	eax, di				# line
	shr	edi, 16				# source file index
	lea	esi, [esi + 4 + ecx * 8]	# source file offsets
	mov	edi, [esi + edi * 4]		# source file offset
	lea	esi, [esi + edi]		# source filename
	clc
1:	pop	edi
	pop	ecx
9:	ret



# in: edx = address
debug_printsymbol:
	push	eax
	push	esi

	call	debug_getsource
	jc	1f

	push	edx
	mov	edx, eax
	mov	ah, 11
	call	printc
	printcharc_ 7, ':'
	call	printdec32
	call	printspace
	pop	edx

1:
	call	debug_getsymbol
	jc	1f
	pushcolor 14
	call	print
	popcolor
	jmp	9f

1:	push	edi
	push	ebx
	push	edx
	call	debug_get_preceeding_symbol
	jc	8f

	pushcolor 13
	call	print
	print	" + "
	sub	edx, eax
	call	printhex4

	printc 7, " | "
	add	edx, eax
	sub	edx, ebx
	neg	edx
	call	printhex4
	print	" - "
	mov	esi, edi
	call	print
	popcolor

8:	pop	edx
	pop	ebx
	pop	edi

9:	pop	esi
	pop	eax
	ret




.data SECTION_DATA_STRINGS
regnames$:
.ascii "cs"	# 0
.ascii "ds"	# 2
.ascii "es"	# 4
.ascii "fs"	# 6
.ascii "gs"	# 8
.ascii "ss"	# 10

.ascii "fl"	# 12

.ascii "di"	# 14
.ascii "si"	# 16
.ascii "bp"	# 18
.ascii "sp"	# 20
.ascii "bx"	# 22
.ascii "dx"	# 24
.ascii "cx"	# 26
.ascii "ax"	# 28
.ascii "ip"	# 30

.ascii "c.p.a.zstidoppn."

.text32
printregisters:
	pushad
	pushf
	push	ss
	push	gs
	push	fs
	push	es
	push	ds
	push	cs


	call	newline_if
	mov	ebx, esp

	mov	esi, offset regnames$
	mov	ecx, 16	# 6 seg 9 gu 1 flags 1 ip

	PUSHCOLOR 0xf0

	mov	ah, 0b111111	# 6 bits indicating print as word

0:	COLOR	0xf0
	cmp	cl, 16-7
	ja	1f
	printchar_ 'e'
1:	lodsb
	call	printchar
	lodsb
	call	printchar

	COLOR 0xf8
	printchar_ ':'

	COLOR	0xf1
	mov	edx, [ebx]
	add	ebx, 4
	shr	ah, 1
	jc	1f
	call	printhex8
	jmp	2f
1:	call	printhex4
2:	call	printspace

	cmp	ecx, 5
	je	2f
	cmp	ecx, 10
	jne	1f

	# print flag characters
	push	ebx
	push	esi
	push	ecx

	call	printflags$

	pop	ecx
	pop	esi
	pop	ebx

2:	call	newline

1: 	loopnz	0b

	call	newline

	POPCOLOR
	pop	eax # cs
	pop	ds
	pop	es
	pop	fs
	pop	gs
	pop	ss
	popf
	popad
	ret

printflags$:
	mov	esi, offset regnames$ + 32 # flags
	mov	ecx, 16
2:	lodsb
	shr	edx, 1
	setc	bl
	jc	3f
	add	al, 'A' - 'a'
3:	shl	bl, 1
	add	ah, bl
	call	printcharc
	sub	ah, bl
	loop	2b
	ret


.data SECTION_DATA_BSS
debugger_stack_print_lines$:	.long 0
debugger_cmdline_pos$:		.long 0
.text32
# task
debugger:
	PIC_GET_MASK
	push	eax
	#push	dword ptr [mutex]
	push	dword ptr [task_queue_sem]
	push	edx
	push	dword ptr 0	# local storage
	push	esi	# orig stack offset
	push	edi	# stack offset

	call	screen_get_scroll_lines
	mov	[debugger_stack_print_lines$], eax

	# enabling timer allows keyboard job: page up etc.
	#call	scheduler_suspend
	#DEBUG_DWORD [mutex]

	#mov	dword ptr [mutex], MUTEX_SCHEDULER # 0#~MUTEX_SCREEN # -1
	mov	dword ptr [task_queue_sem], -1

	PIC_SET_MASK ~(1<<IRQ_KEYBOARD)# | 1<<IRQ_TIMER)
	sti	# for keyboard. Todo: mask other interrupts.

1:	printlnc_ 0xb8, "Debugger: h=help c=continue p=printregisters s=sched m=mode"

0:	printcharc_ 0xb0, ' '	# force scroll
	call	screen_get_pos
	mov	[debugger_cmdline_pos$], eax

4:	mov	eax, [debugger_cmdline_pos$]
	call	screen_set_pos

	mov	al, [esp + 8]
	and	al, 7
	LOAD_TXT "stack"
	jz	2f
	LOAD_TXT "sched"
	cmp	al, 1
	jz	2f
	LOAD_TXT "?????"
2:	printc 0xb8, "(mode:"
	movzx	edx, al
	call	printdec32
	mov	ah, 0xb0
	call	printc
	printc_ 0xb8, ") > "

6:	xor	ax, ax
	call	keyboard

	# use offset as symbols arent defined yet - gas bug
	.if SCREEN_BUFFER
	cmp	ax, offset K_PGUP
	jz	66f
	.endif
	cmp	ax, offset K_UP
	jz	56f
	cmp	ax, offset K_DOWN
	jz	59f
	cmp	ax, offset K_ESC
	jz	10f
	test	eax, K_KEY_CONTROL | K_KEY_ALT
	jnz	6b
	cmp	al, 'c'
	jz	9f
	cmp	al, 'p'
	jz	2f
	cmp	al, 'h'
	jz	1b
	cmp	al, 's'
	jz	55f
	cmp	al, 'm'
	jz	13f
	jmp	6b

10:	mov	edi, [esp]
	jmp	62f
59:	add	edi, 4
	jmp	62f
56:	sub	edi, 4
62:	mov	esi, [esp + 4]
		# calculate where stack is printed on screen
		call	screen_get_scroll_lines
		sub	eax, [debugger_stack_print_lines$]
		add	[debugger_stack_print_lines$], eax
		mov	edx, 160
		imul	eax, edx
		mov	edx, [stack_print_pos$]
		sub	edx, eax
		jns	1f
		call	debug_print_stack$
		call	screen_get_scroll_lines
		mov	[debugger_stack_print_lines$], eax
		jmp	0b
		1:
	PUSH_SCREENPOS edx
	call	debug_print_stack$
	POP_SCREENPOS
#		mov	eax, [stack_print_lines$]
#		mov	[debugger_stack_print_lines$], eax
	jmp	6b

.if SCREEN_BUFFER
66:	call	scroll	# doesn't flush last line
	jmp	4b
.endif

55:	call	cmd_tasks
	jmp	0b

13:	mov	al, [esp + 8]	# update low 3 bits (8 modes max)
	mov	dl, al
	and	al, 0xf8
	inc	dl
	and	dl, 7
	or	al, dl
	mov	[esp + 8], al
	jmp	4b

9:	call	scheduler_resume
	pop	edi
	pop	esi
	add	esp, 4	# local storage
	pop	edx
	pop	dword ptr [task_queue_sem]
	#pop	dword ptr [mutex]
	pop	eax
	PIC_SET_MASK
	ret

2:	call	debug_print_exception_registers$# printregisters
	jmp	0b
