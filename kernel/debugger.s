######################################################################
.intel_syntax noprefix

.data SECTION_DATA_BSS
kernel_symtab:		.long 0
kernel_symtab_size:	.long 0
kernel_stabs:		.long 0
kernel_stabs_size:	.long 0

.text32
debug_load_symboltable:	# bootloader/ramdisk preloaded
call cmd_ramdisk # show contents
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


	GDT_GET_BASE ecx, ds

	.macro DEBUG_LOAD_TABLE name, label

	.if DEBUG_RAMDISK_DIY
	mov	edx, fs:[eax + 4]	# load start
	mov	ebx, fs:[eax + 12]	# load end
	.else
	mov	edx, [\name\()_load_start_flat]
	mov	ebx, [\name\()_load_end_flat]
	.endif
	print "checking \label:"
#	or	edx, edx
#	jnz	19f
	call	ramdisk_load_image	# updates memory map
#	jc	18f
#19:
	I "Found \label: "
	sub	edx, ecx
	js	8f
	mov	[kernel_\name\()], edx	# load_start ds-relative
	mov	ebx, edx
	call	printhex8
	.if DEBUG_RAMDISK_DIY
	mov	edx, fs:[eax + 12]	# load end
	add	eax, 32
	.else
	mov	edx, [\name\()_load_end_flat]
	sub	edx, ecx
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
18:
	.endm

	DEBUG_LOAD_TABLE symtab, "symbol table"
	DEBUG_LOAD_TABLE stabs, "source line table"
	ret

8:	printlnc 12, "error: symboltable before kernel: "
	call	printhex8
	printc 12, "data base: "
	mov	eax, edx
	call	printhex8
9:	debug "error"
	ret

# in: edx = load start
# in: ebx = load end
# Format:
#   .long lba, mem_start, sectors, mem_end
ramdisk_load_image:
	or	edx, edx
	jnz	1f
	printlnc 5, "image not loaded"
	ret

1:	println "image already loaded"

	sub	ebx, edx	# ebx = load size
	mov	edi, 10		# the memory type to set

	# update the memory map so malloc won't use that area
	pushad
	DEBUG_DWORD edx, "load_start"
	mov	esi, offset memory_map
	mov	ecx, RM_MEMORY_MAP_MAX_SIZE
	# find the entry that has higher address:
0:	cmp	dword ptr [esi + 16], 0	# region type
	jz	2f	# end of list: append
	cmp	dword ptr [esi + 4], 0	# check high addr 0
	jnz	1f		# somehow missed injection pt, continue
	cmp	edx, [esi]	# is < 4gb addr, check ramdisk entry before
	je	3f	# insert
	#jb	4f	in range of prev entry - not implemented: append.
1:	add	esi, 24
	loop	0b

0:	call	print_memory_map
	popad
	ret

# append
2:	#DEBUG "update memory map"; call newline
	mov	[esi + 0], edx		# mem start
	mov	[esi + 4], dword ptr 0
	mov	[esi + 8], ebx
	mov	[esi + 12], dword ptr 0
	mov	[esi + 16], edi	# mem type
	jmp	0b
# cur entry start matches load address
3:	#DEBUG "Got exact match"
	# edx = [esi]: set edx to new start:
	add	edx, ebx	# edx = start of free mem
	xchg	ebx, [esi + 8]	# swap mem size
	sub	ebx, [esi + 8]	# ebx is remaining free mem
	mov	[esi + 16], edi	# mark allocated; TODO: check if it was 1
	mov	edi, 1	# on append, mark as free mem
	#DEBUG_DWORD edx,"free start"
	#DEBUG_DWORD ebx, "free size"
	# now, edx and ebx contain the remaining free mem from the block.
	# we append.
	jmp	1b	# for now continue to end.

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


# in: edx = symbol name string ptr
# out: edx = symbol address
# out: CF
debug_findsymboladdr:
	mov	esi, [kernel_symtab]
	or	esi, esi
	stc
	jz	9f

	push_	eax ecx ebx edi
	mov	edi, edx	# backup
	mov	eax, edx	# arg sym name
	call	strlen
	mov	edx, eax	# edx = strlen of sym to find

	##

	lodsd	# first dword: nr of hex addresses, and symbols.
	lea	ebx, [esi + eax * 8]	# start of string table

	lea	esi, [esi + eax * 4]	# start of string ptr
	mov	ecx, eax

########
	# the ecx dwords found at esi are relative to ebx
0:	lodsd
	push_	esi ecx
	mov	ecx, [esi]	# next ptr
	sub	ecx, eax	# cur ptr
	dec	ecx		# it includes the 0 delim

	cmp	ecx, edx	# compare string lengths
	jnz	1f

	lea	esi, [ebx + eax]	# point to string

	push	edi
	repz	cmpsb
	pop	edi

1:	pop_	ecx esi
	jz	1f
	loop	0b
	stc
########
0:	pop_	edi ebx ecx eax
9:	ret

1:	mov	ebx, [kernel_symtab]
	mov	edx, [ebx]	# nr of entries
	sub	edx, ecx
	lea	edx, [ebx + 4 + edx * 4]
	mov	edx, [edx]
	jmp	0b

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
	jz	0f	# exact match
	ja	0b		# [....|<eax....>]
	sub	eax, ecx	# [<eax....>|....]
	jmp	0b
# odd
1:	jnc	0f	# even
3:	cmp	edx, [esi + 8 + eax * 4]
	jb	0f
	inc	eax
	cmp	eax, [esi]
	jb	3b 	# should not loop > 1, but 5 times is seen..

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

#####################################################################
# Printing mutexes
.data SECTION_DATA_BSS
debugger_mutex_col_width$:	.byte 0
.text32
debugger_printcalc_mutex$:
	# calculate mutex name width
	xor	edx, edx
	mov	eax, NUM_MUTEXES
	mov	esi, offset mutex_names
0:	call	strlen_
	cmp	ecx, edx
	jb	1f
	mov	edx, ecx
	stc
1:	adc	esi, ecx
	dec	eax
	jnz	0b
	inc	edx
	mov	[debugger_mutex_col_width$], dl
	ret

debugger_print_mutex$:
	push	eax
	push	ecx
	push	edx
	push	esi
	push	edi

	cmp	byte ptr [debugger_mutex_col_width$], 0
	jnz	1f
	call	debugger_printcalc_mutex$
1:

	printc_ 11, "mutex: "
	mov	edx, [mutex]
	call	printbin8
	call	newline

	mov	ecx, NUM_MUTEXES
	mov	esi, offset mutex_owner
	mov	edi, offset mutex_names
########
0:	mov	edx, NUM_MUTEXES
	sub	edx, ecx
	call	printdec32
	printchar_ ':'

	xchg	esi, edi
	push	ecx
	movzx	ecx, byte ptr [debugger_mutex_col_width$]
	add	ecx, esi
	call	print_
	sub	ecx, esi
	jbe	1f
2:	call	printspace
	loop	2b
1:	pop	ecx
	xchg	esi, edi

	printchar_ '='
	lodsd
	mov	edx, eax
	call	printhex8
	or	edx, edx
	jz	1f
	call	printspace
	call	debug_printsymbol
1:	call	newline
	loop	0b
########
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	eax
	ret

DEBUGGER_SWAP_CR3 = 0

.data SECTION_DATA_BSS
debugger_stack_print_lines$:	.long 0
debugger_cmdline_pos$:		.long 0
.text32
# task
debugger:
	push_	ds es
	push	ebp
	PIC_GET_MASK
	push	eax
	mov	eax, SEL_compatDS
	mov	ds, eax
	mov	es, eax
	#push	dword ptr [mutex]
	push	dword ptr [task_queue_sem]
	push	edx
	push	dword ptr 0	# local storage
	push	esi	# orig stack offset
	push	edi	# stack offset
	mov	ebp, esp
	push	ebx	# stack segment
.if DEBUGGER_SWAP_CR3
	mov	eax, cr3
	push	eax
	mov	eax, [page_directory_phys]
	mov	cr3, eax
.endif

	call	screen_get_scroll_lines
	mov	[debugger_stack_print_lines$], eax

	# enabling timer allows keyboard job: page up etc.
	#call	scheduler_suspend
	#DEBUG_DWORD [mutex]

	#mov	dword ptr [mutex], MUTEX_SCHEDULER # 0#~MUTEX_SCREEN # -1
	mov	dword ptr [task_queue_sem], -1

	PIC_SET_MASK ~(1<<IRQ_KEYBOARD)# | 1<<IRQ_TIMER)
	sti	# for keyboard. Todo: mask other interrupts.
	pushad	# just in case
	mov	al, IRQ_KEYBOARD + IRQ_BASE
	mov	ebx, offset isr_keyboard
	mov	cx, cs
	call	hook_isr
	popad



1:	printlnc_ 0xb8, "Debugger: h=help c=continue p=printregisters s=sched m=mutex"

0:	printcharc_ 0xb0, ' '	# force scroll
	call	screen_get_pos
	mov	[debugger_cmdline_pos$], eax

4:	mov	eax, [debugger_cmdline_pos$]
	call	screen_set_pos

	mov	al, [ebp + 8]
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
	cmp	[scrolling$], byte ptr 0
	jnz	66f
	cmp	ax, offset K_PGUP
	jz	66f
7:	# continue checking keys if not scroll key
	.endif
	cmp	ax, offset K_UP
	jz	56f
	cmp	ax, offset K_DOWN
	jz	59f
	cmp	ax, offset K_ESC
	jz	10f
	test	eax, K_KEY_CONTROL | K_KEY_ALT
	jnz	6b
	cmp	ax, offset K_TAB
	jz	13f	# mode
	cmp	al, 'c'
	jz	9f
	# the rest of the keys/commands has print output, so do newline:
	call	newline
	cmp	al, 'p'	# print registers
	jz	2f
	cmp	al, 'h'	# help
	jz	1b
	cmp	al, 's'	# scheduler (tasks)
	jz	55f
	cmp	al, 'm'	# mutex
	jz	69f
	cmp	al, 'u'	# memory
	jz	3f
	cmp	al, 'e' # cmdline
	jz	33f
	jmp	6b

10:	mov	edi, [ebp]
	jmp	62f
59:	add	edi, 4
	jmp	62f
56:	sub	edi, 4
62:	mov	esi, [ebp + 4]
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
	jc	7b	# key not handled (not scroll key)
	jmp	4b
.endif

55:	push	esi
	PUSHSTRING "ps"
	mov	esi, esp
	call	cmd_tasks
	add	esp, 4
	pop	esi
	jmp	0b

69:	call	debugger_print_mutex$
	jmp	0b

# mode
13:	mov	al, [ebp + 8]	# update low 3 bits (8 modes max)
	mov	dl, al
	and	al, 0xf8
	inc	dl
	and	dl, 7
	or	al, dl
	mov	[ebp + 8], al
	jmp	4b

9:
.if DEBUGGER_SWAP_CR3
	pop	eax
	mov	cr3, eax
.endif
	call	scheduler_resume
	pop	ebx
	pop	edi
	pop	esi
	add	esp, 4	# local storage
	pop	edx
	pop	dword ptr [task_queue_sem]
	#pop	dword ptr [mutex]
	pop	eax
	PIC_SET_MASK
	pop	ebp
	pop_	es ds
	ret

2:	call	debug_print_exception_registers$# printregisters
	jmp	0b

3:	call	mem_print_handles
	jmp	0b

33:	call	debugger_handle_cmdline$
	jmp	0b


#######################################
DECLARE_CLASS_BEGIN debugger_cmdline, cmdline
DECLARE_CLASS_METHOD cmdline_api_print_prompt, debugger_print_prompt$, OVERRIDE
DECLARE_CLASS_METHOD cmdline_api_execute, debugger_execute$, OVERRIDE
DECLARE_CLASS_END debugger_cmdline
.data SECTION_DATA_BSS
debugger_cmdline$:	.long 0
.text32

debugger_cmdline_init$:
	mov	eax, [debugger_cmdline$]
	or	eax, eax
	jnz	1f
	mov	eax, offset class_debugger_cmdline
	call	class_newinstance
	jc	9f
	mov	[debugger_cmdline$], eax
	call	[eax + cmdline_constructor]
1:	ret

9:	printlnc 4, "debugger: failed to instantiate cmdline"
	stc
	ret

debugger_print_prompt$:
	LOAD_TXT "debugger"
	mov	ecx, 8
	mov	ah, 12
0:	lodsb
	stosw
	loop	0b
	ret

# in: ebx
debugger_execute$:
	call	cmdline_execute$	# tokenize
	.if 0
		push	ebx
		lea	esi, [ebx + cmdline_tokens]
		mov	ebx, [ebx + cmdline_tokens_end]
		call	printtokens
		pop	ebx
	.endif

	lea	esi, [ebx + cmdline_args]
	lodsd
	or	eax, eax
	jz	9f
	cmp	dword ptr [eax], 'e'|('x'<<8)|('i'<<16)|('t'<<24)
	jnz	9f
	cmp	byte ptr [eax+4], 0
	jnz	9f
	call	cmd_quit$

9:	ret

#############################################################

debugger_handle_cmdline$:
	call	debugger_cmdline_init$
	jc	9f

	mov	ebx, eax
	push	ebp
	push	ebx
	mov	ebp, esp	# shell expects [ebp] = ebx

	jmp	start$		# cmd_quit takes care of popping.

#######################################

# in: [esp+0] index
# in: [esp+4] arrayref
# in: [esp+8] elsize
# in: [esp+12] arrayref name
debug_assert_array_index:
	push	ebp
	lea	ebp, [esp + 8]
	pushf
	push	eax
	push	edx
	push	ebx
	push	ecx
	mov	ebx, [ebp + 4]	# arrayref
	mov	edx, [ebp + 0]	# index

	# check range
	cmp	edx, [ebx + array_index]
	jb	1f
	printc 4, "array index out of bounds: "
	jmp	9f

	# check alignment
1:	xor	eax, eax
	xchg	edx, eax
	mov	ecx, [ebp + 8]	# elsize
	div	ecx
	or	edx, edx
	jz	0f
	printc 4, "array index alignment error: off by: "
	call	printhex8
	printc 4, " relative to "
	mov	edx, eax
	call	printhex8
	jmp	9f

0:	pop	ecx
	pop	ebx
	pop	edx
	pop	eax
	popf
	pop	ebp
	ret	16

9:	printc 4, " array: "
	push	[ebp + 12]	# name
	call	_s_print

	printc 4, " index="
	push	dword ptr [ebp + 0]	# index
	call	_s_printhex8

	printc 4, " max="
	push	dword ptr [ebx + array_index]
	call	_s_printhex8

	call	newline

	printc 4, "caller: "
	mov	edx, [ebp - 4]
	call	printhex8
	call	printspace
	call	debug_printsymbol
	call	newline
	int	3
	jmp	0b

.macro ASSERT_ARRAY_IDX index, arrayref, elsize, mutex=0
	.ifnc 0,\mutex
	MUTEX_SPINLOCK_ \mutex
	.endif
	push_txt "\arrayref"
	push	\elsize
	push	\arrayref
	push	\index
	call	debug_assert_array_index
	.ifnc 0,\mutex
	MUTEX_UNLOCK_ \mutex
	.endif
.endm
