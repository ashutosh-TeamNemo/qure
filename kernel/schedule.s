.intel_syntax noprefix

SCHEDULE_DEBUG = 1

.struct 0
task_addr:	.long 0	# eip of task
task_arg:	.long 0	# value to be passed in edx
task_label:	.long 0	# name of task (for debugging)
task_registrar:	.long 0	# address from which schedule_task was called (for debugging when task_addr=0)
.data SECTION_DATA_BSS
schedule_sem: .long 0
scheduled_tasks: .long 0
SCHEDULE_STRUCT_SIZE = 12
.text32

# This method is called immediately after an interrupt has handled,
# and it is the tail part of the irq_proxy.
schedule:
	push	eax
	push	edx
	call	get_scheduled_task$	# out: eax, edx
	jc	9f

	# keep interrupt flag as before IRQ
	#	test	word ptr [esp + 8 + 4 + 4], 1 << 9	# irq flag; 8:cs:eip, 4:eax, 4:edx
	#	jz	2f
	sti

	pushad
	call	eax	# in: edx; assume the task does not change segment registers
	popad

	.if 1
	mov	eax, edx
	call	mfree
	.endif

9:	pop	edx
	pop	eax
	iret


# nr: 3 = failed to acquire lock
# nr: 2 = lock success, executing task
# nr: 1 = lock success, no task
# nr: 0 = no data
.macro SCHED_UPDATE_GRAPH nr
.if SCHEDULE_DEBUG
	push	eax
	.ifc al,\nr
	movzx	eax, \nr
	.else
	mov	eax, \nr
	.endif
	call	sched_update_graph
	pop	eax
.endif
.endm


# out: eax = task ptr
# out: edx = task arg
# out: esi = task label
# out: CF = 1: no task or cannot lock task list
get_scheduled_task$:
	# schedule_task does spinlock, so we don't, as this
	# method is called regularly.
	mov	eax, 1
	xchg	[schedule_sem], eax
	or	eax, eax
	jnz	9f	# task list locked - abort.

	push	ebx
	push	ecx
########
	# one-shot first-in-list
	mov	ebx, [scheduled_tasks]
	or	ebx, ebx
	jz	1f
	xor	ecx, ecx	# index
########
0:	mov	eax, -1
	xchg	eax, [ebx + ecx + task_addr]
	mov	edx, [ebx + ecx + task_arg]	# ptr
	#mov	esi, [ebx + ecx + task_label]	# label
	cmp	eax, -1
	jnz	0f
########
	add	ecx, SCHEDULE_STRUCT_SIZE
	cmp	ecx, [ebx + array_index]
	jb	0b
########
1:	SCHED_UPDATE_GRAPH 2
	stc
	jmp	1f	# no task
0:	SCHED_UPDATE_GRAPH 3
	clc
########
1:	pop	ecx
	pop	ebx

	mov	dword ptr [schedule_sem], 0	# we have lock so we can write.
	ret

9:	SCHED_UPDATE_GRAPH 1
	stc
	ret



.if SCHEDULE_DEBUG
.data SECTION_DATA_BSS
sched_graph: .space 80	# scoller
.data
sched_graph_symbols:
	.byte ' ', 0
	.byte '-', 0x4f
	.byte '-', 0x3f
	.byte '+', 0x2f
.text32
# in: al = nr
# destroys: eax
sched_update_graph:
	push	ecx
	push	esi
	push	edi
	mov	ecx, 79
	mov	edi, offset sched_graph
	mov	esi, offset sched_graph + 1
	rep	movsb
#	stosb
	mov	byte ptr [sched_graph + 79], al
	PUSH_SCREENPOS
	PRINT_START
	mov	esi, offset sched_graph
	xor	edi, edi
	xor	eax, eax
	mov	ecx, 80
0:	lodsb
	and	al, 3
	xor	ah, ah
	mov	ax, [sched_graph_symbols + eax * 2]
	stosw
	loop	0b
	PRINT_END
	POP_SCREENPOS
	pop	edi
	pop	esi
	pop	ecx
	ret
.endif



# in: cs
# in: eax = task code offset
# in: ecx = size of argument
# in: esi = label for task
# out: eax = argument buffer
schedule_task:
	push	ebx
	push	ecx
	push	edx
	mov	ebx, eax

######## spin lock
	mov	ecx, 0x1000
0:	dec	ecx	# infinite loop limit
	stc
	jz	9f
	mov	eax, 2	# for future debugging - who has lock.
	xchg	[schedule_sem], eax
	or	eax, eax
	pause
	jnz	0b
########
	ARRAY_LOOP [scheduled_tasks], SCHEDULE_STRUCT_SIZE, eax, edx, 9f
	cmp	dword ptr [eax + edx], -1
	jz	1f
	ARRAY_ENDL
9:	ARRAY_NEWENTRY [scheduled_tasks], SCHEDULE_STRUCT_SIZE, 4, 9f
1:	mov	[eax + edx + task_addr], ebx
	mov	[eax + edx + task_label], esi
########
	push	eax
	mov	eax, ecx
	call	malloc
	mov	ecx, eax
	pop	eax
	jnc	1f
	# no mem - unschedule task
	mov	dword ptr [eax + edx], -1
	jmp	9f
########
1:	mov	[eax + edx + task_arg], ecx
	mov	eax, ecx

	mov	dword ptr [schedule_sem], 0

9:	pop	edx
	pop	ecx
	pop	ebx
	ret
