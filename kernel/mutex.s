###############################################################################
# Semaphores and Mutexes
#
.intel_syntax noprefix

MUTEX_DEBUG = 1	# registers lock owners

_MUTEX_LOCAL = 0	# experimental feature
################################################################
# Mutex - mutual exclusion
#
.data SECTION_DATA_SEMAPHORES
.align 4
mutex:		.long 0 # -1	# 32 mutexes, initially unlocked #locked.
	MUTEX_SCHEDULER	= 0
#	MUTEX_SCREEN	= 1
	MUTEX_MEM	= 2
	MUTEX_KB	= 3
	MUTEX_FS	= 4
	MUTEX_NET	= 5
	MUTEX_TCP_CONN	= 6
	MUTEX_SOCK	= 7

	NUM_MUTEXES	= 8

mutex_owner:	.space 4 * NUM_MUTEXES

mutex_names:
mutex_name_SCHEDULER:	.asciz "SCHEDULER"
mutex_name_MEM:		.asciz "MEM"
mutex_name_SCREEN:	.asciz "SCREEN"
mutex_name_KB:		.asciz "KB"
mutex_name_FS:		.asciz "FS"
mutex_name_NET:		.asciz "NET"
mutex_name_TCP_CONN:	.asciz "TCP_CONN"
mutex_name_SOCK:	.asciz "SOCK"

.tdata
tls_mutex: .long 0
.tdata_end
.text32

.macro YIELD
	KAPI_CALL yield
.endm




.macro MUTEX_LOCAL_TEST name
.if _MUTEX_LOCAL
	push	eax
	call	tls_get
	bt	[eax + tls_mutex], MUTEX_\name
	pop	eax
.endif
.endm

.macro MUTEX_LOCAL_SETC_ name
.if _MUTEX_LOCAL
	push	eax
	call	tls_get
	.print "MUTEX_\name"
	or	dword ptr [eax + tls_mutex], 1<< MUTEX_\name
	pop	eax
.endif
.endm


.macro MUTEX_LOCAL_SETC name
.if _MUTEX_LOCAL
	jnc	109f
	MUTEX_LOCAL_SETC_ \name
	stc
109:
.endif
.endm

.macro MUTEX_LOCAL_CLEARC_ name
.if _MUTEX_LOCAL
	push	eax
	call	tls_get
	and	dword ptr [eax + tls_mutex], 1#~(1<< MUTEX_\name)
	pop	eax
.endif
.endm


.macro MUTEX_LOCAL_CLEARC name
.if _MUTEX_LOCAL
	jc	109f
	MUTEX_LOCAL_CLEARC_ \name
	stc
109:
.endif
.endm



# out: CF = 1: fail, mutex was already locked.
.macro MUTEX_LOCK name, nolocklabel=0, locklabel=0, debug=0
	lock bts dword ptr [mutex], MUTEX_\name
	MUTEX_LOCAL_SETC \name

	.if MUTEX_DEBUG
		jc	100f
		call	101f
	101:	pop	[mutex_owner + MUTEX_\name * 4]
	100:
	.endif

	.if \debug
		jnc	100f
		printc 5, "MUTEX LOCK \name: fail"
		stc
	100:	
	.endif
	.ifnc 0,\nolocklabel
	jc	\nolocklabel
	.endif
	.ifnc 0,\locklabel
	jnc	\locklabel
	.endif
.endm

# out: CF = 1: it was locked (ok); 0: another thread unlocked it (err)
.macro MUTEX_UNLOCK name, debug=0
	lock btr dword ptr [mutex], MUTEX_\name
	MUTEX_LOCAL_CLEARC \name
	.if MUTEX_DEBUG > 1
		mov	[mutex_owner + MUTEX_\name * 4], dword ptr 0
	.endif

	.if \debug
		jc	100f
		printc 4, "MUTEX_UNLOCK \name: unlock error"
		clc
	100:
	.endif
.endm


.macro MUTEX_SPINLOCK_ name
	jmp	1990f
1999:	lock btr dword ptr [mutex], MUTEX_\name	# clear mutex on fail
	YIELD
1990:	lock bts dword ptr [mutex], MUTEX_\name
	jc	1999b
	MUTEX_LOCAL_SETC_ \name
	call	1999f
1999:	pop	dword ptr [mutex_owner + MUTEX_\name * 4]
.endm

.macro MUTEX_UNLOCK_ name
	pushf
	lock btr dword ptr [mutex], MUTEX_\name
	MUTEX_LOCAL_CLEARC_ \name
	mov	dword ptr [mutex_owner + MUTEX_\name * 4], 0
	popf
.endm

.macro MUTEX_SCHEDLOCK name
1999:	lock bts dword ptr [mutex], MUTEX_\name
	jnc	1999f
	call	schedule_near
	jmp	1999b
1999:	call	1999f
1999:	pop	dword ptr [mutex_owner + MUTEX_\name * 4]
.endm

.macro MUTEX_SPINLOCK name, nolocklabel=0, locklabel=0, debug=0
	push	ecx
	mov	ecx, 10
9101:	MUTEX_LOCK \name, 0, 9102f
	YIELD
	loop	9101b
	.if \debug
		printc 5, "MUTEX_SPINLOCK \name: fail"
		.if MUTEX_DEBUG > 1
			print " owner: "
			push edx
			mov edx,	dword ptr [mutex_owner + MUTEX_\name * 4]
			call printhex8
			call newline
			print "MUTEX: "
			mov edx, [mutex]
			call printbin8
			call printspace
			pop edx
		.endif
	.endif
	stc
9102:	pop	ecx
	.ifnc 0,\locklabel
	jnc	\locklabel
	.endif
	.ifnc 0,\nolocklabel
	jc	\nolocklabel
	.endif
.endm


#####################################################################
# Semaphores (shared variable)
#

# Semaphore/mutex relevant mnemonics:
# lock, cmpxchg, xadd, mov, inc, dec, adc, sbb, bt, bts, btc, btr, not, neg, or, and

# A fail-fast semaphore lock.
#
# This macro does a single check, leaving the semaphore in a locked state
# regardless of whether the lock succeeded.
# When the lock does not succeed, control is transferred to \nolocklabel.
# out: ZF = 1: have lock
# out: eax = 0 (have locK), other value: no lock.
.macro SEM_LOCK sem, nolocklabel=0
	.if INTEL_ARCHITECTURE > 4
		push	ebx
		mov	ebx, 1
		xor	eax, eax
		lock	cmpxchg \sem, ebx
		pop	ebx
	.else
		mov	eax, 1
		xchg	\sem, eax
		or	eax, eax
	.endif
	.ifnc 0,\nolocklabel
		jnz	\nolocklabel	# task list locked - abort.
	.endif
.endm


# This is a semi-spinlock, as it does not use CPU time when it fails
# to acquire a lock. A lock is typically not going to become free unless
# an interrupt occurs (unless perhaps on SMP systems).
# Therefore, when lock acquisition fails, interrupts are enabled and
# the cpu is halted.
# Since the timer interrupt is essential for scheduling,
# and since this is the only way the scheduler is called,
# and since on a single-CPU system the scheduler is the only 'process'
# that can obtain a lock,
# halting is the most efficient way to wait for a semaphore to become free
# besides triggering the scheduler.
#
# On an SMP system, potentially [pit_timer_interval] milliseconds are wasted,
# in the case where IRQ's are only executed by one CPU at a time,
# and where two or more CPU's are competing to register a task, where one
# has obtained a lock, and the other enters halt.
# I have not researched SMP implementation yet, thus, it is possible that even though
# any IRQ is only executed on a single CPU at a time, that two different IRQ's,
# such as the timer and the network, are executed simultaneously. In this case,
# since all IRQ's (except exceptions), are mapped to the scheduler, it is
# possible that the scheduler is called concurrently. However, the 'fail-fast'
# lock mechanism would take care of attempting any task switch.
#
# out: CF = ZF (1: no lock; 0: lock)
# destroys: eax, ecx
.macro SEM_SPINLOCK sem, locklabel=0, nolocklabel=0
	.ifc 0,\locklabel
	_LOCKLABEL = 109f
	.else
	_LOCKLABEL = \locklabel
	.endif

	mov	ecx, 0x1000
100:
	.if INTEL_ARCHITECTURE > 4
		push	ebx
		mov	ebx, 1
		xor	eax, eax
		lock	cmpxchg \sem, ebx
		pop	ebx
		jz	109f
	.else
		xchg	\sem, eax
		or	eax, eax
		jz	109f
	.endif

	YIELD
	loop	100b

	.ifc 0,\nolocklabel
		or	eax, eax
		stc
	.else
		jmp \nolocklabel
	.endif
109:
.endm


.macro SEM_UNLOCK sem
	mov	dword ptr \sem, 0
.endm



################################################################################
# Read/Write Locking
#

################################################################################
# Jcc breakdown:
#
# SZCO | G GE NG NGE L LE NL NLE A AE NA NAE BE NBE |
# ---- | ------------------------------------------ |---------------------------
#      | G GE             NL NLE A AE           NBE |INC DEC ADD SUB            
#   C  | G GE             NL NLE      NA NAE BE     |                SUB-1 ADD-1
#  Z   |   GE NG       LE NL       AE NA     BE	    |INC DEC     SUB SUB-1 
#  ZC  |   GE NG       LE NL          NA NAE BE	    |        ADD           ADD-1
# S    |      NG NGE L LE        A AE           NBE |INC DEC ADD SUB       ADD-1
# S C  |      NG NGE L LE             NA NAE BE     |                SUB-1 ADD-1
# S  O | G GE             NL NLE A AE           NBE | add 7fffffff
#    O |      NG NGE L LE        A AE           NBE | sub 7fffffff
#   CO | ???
#  Z O | ???
#
# JG/JNLE: ZF == 0 && SF == OF  - or - NOT(SF!=OF || ZF==1)
################################################################################

#		 DEC 	ADD-1	SUB 1
#		----- + ----- + -----
#  2 ->  1:	      |     C |  
#  1 ->  0:	  Z   |   Z C |   Z  
#  0 -> -1:	S     |	S     | S   C	LOCK_WRITE success
# -1 -> -2:	S     | S   C | S
#
# LOCK_WRITE: sub [sem], 1; jc success

.macro LOCK_WRITE sem
990:	lock sub dword ptr \sem, 1
	jc	999f
	lock inc dword ptr \sem
	YIELD
	jmp	990b
999:	
.endm

#		 INC    ADD 1
#		----- + ----- + -----
#  1 ->  2:	      |       |      	LOCK_READ success
#  0 ->  1:	      |       |      	LOCK_READ success
# -1 ->  0:	  Z   |   Z C |      
# -2 -> -1:	S     | S     |      
#
# LOCK_READ: inc [sem]; jg success

.macro LOCK_READ sem
990:	lock inc dword ptr \sem
	jg	999f
	lock dec dword ptr \sem
	YIELD
	jmp	990b
999:
.endm

.macro UNLOCK_READ sem
	lock dec dword ptr \sem
	# SF = 0: lock is >=0: jns success.
	# SF = 1: sem was <=0. Causes:
	# 1) too many read unlocks (bug), or:
	# 2) write lock attempted: interrupted at 2nd line (jc) in LOCK_WRITE.
	#    It will resolve on LOCK_WRITE's inc which will set sem to 0. 
	# x) LOCK_READ's DEC cannot be a cause due to it being preceeded by
	#    an INC resulting in a zero or positive contribution that cannot
	#    cannot make sem too negative.
.endm


.macro UNLOCK_WRITE sem
	lock inc dword ptr \sem
	# ZF = 1: success. Otherwise, ZF = 0, and:
	# SF = 0: sem was 0+. Causes:
	# 1) too many UNLOCK_WRITE (bug), or:
	# 2) read lock attempted (inc -1->0, released write lock, now 0->1).
	#    LOCK_READ will decrement (1->0) and try again.
	# x) LOCK_WRITE's INC cannot be a cause since it is preceeded by a SUB,
	#    which results in a zero or negative change that cannot contribute
	#    to sem being too positive.
	# SF = 1: sem was -2. Causes:
	# 1) too many UNLOCK_READ (bug), or:
	# 2) LOCK_WRITE attempted (dec -1->-2, now -2->-1).
	#    LOCK_WRITE will increment (-1->0) and try again.
	# x) LOCK_READ's DEC is not a cause as it is preceeded by INC, resulting
	#    in a change of 0 or +1 and thus cannot cause negativity.
.endm


# scheduler specific:

.macro YIELD_SEM sem
	# TODO: make system call.
	push	\sem
	call	task_wait_io
.endm
