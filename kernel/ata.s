###############################################################################
# IDE / ATAPI

.intel_syntax noprefix


ATA_DEBUG = 1

# PCI: class 1.1 (mass storage . ide)
# BAR0: IO_ATA_PRIMARY			0x1F0
# BAR1: IO_ATA_PRIMARY	 base DCR	0x3F4 (+2 for DCR)
# BAR2: IO_ATA_SECONDARY		0x170
# BAR3: IO_ATA_SECONDARY base DCR	0x374 (+2)
# BAR4: Bus Master ID: 16 ports, 8 ports per DMA
# 'Bus':
IO_ATA_PRIMARY		= 0x1F0	# - 0x1F7 DCR: 0x3f6	RM IRQ 14h
IO_ATA_SECONDARY	= 0x170	# - 0x177 DCR: 0x376	RM IRQ 15h
IO_ATA_TERTIARY		= 0x1E8 # - 0x1EF DCR: 0x3E6    (just before PRIMARY)
IO_ATA_QUATERNARY	= 0x168 # - 0x16F DCR: 0x366	(just before SECONDARY)

# Add these to the IO_ATA_ base:
ATA_PORT_DATA		= 0
ATA_PORT_FEATURE	= 1	# write
ATA_PORT_ERROR		= 1	# read
  ATA_ERROR_BBK			= 0b10000000	# Bad Block
  ATA_ERROR_UNC			= 0b01000000	# Uncorrectable Data Error
  ATA_ERROR_MC			= 0b00100000	# Media Changed
  ATA_ERROR_IDNF		= 0b00010000	# ID mark not found
  ATA_ERROR_MCR			= 0b00001000	# Media Change Requested
  ATA_ERROR_ABRT		= 0b00000100	# command Aborted
  ATA_ERROR_TK0NF		= 0b00000010	# Track 0 Not Found
  ATA_ERROR_AMNF		= 0b00000001	# Address Mark Not Found
ATA_PORT_SECTOR_COUNT	= 2	# Interrupt Reason register (DRQ)
ATA_PORT_ADDRESS1	= 3	# sector	/ LBA lo
ATA_PORT_ADDRESS2	= 4	# cylinder low	/ LBA mid    Byte Count
ATA_PORT_ADDRESS3	= 5	# cylinder hi	/ LBA high   Byte Count
ATA_PORT_DRIVE_SELECT	= 6
  ATA_DRIVE_MASTER	= 0xa0
  ATA_DRIVE_SLAVE	= 0xb0
  # bin: 101DHHHH
  # D: drive (0 = master 1 = slace)
  # HHHH: head selection bits
ATA_PORT_COMMAND	= 7	# write
  ATA_COMMAND_PIO_READ			= 0x20	# w/retry; +1=w/o retry
  ATA_COMMAND_PIO_READ_LONG		= 0x22	# w/retry; +1=w/o retry
  ATA_COMMAND_PIO_READ_EXT		= 0x24
  ATA_COMMAND_DMA_READ_EXT		= 0x25
  ATA_COMMAND_PIO_WRITE_		= 0x30	# w/retry; +1=w/o retry
  ATA_COMMAND_PIO_WRITE_LONG		= 0x32	# w/retry; +1=w/o retry
  ATA_COMMAND_DMA_WRITE_EXT		= 0x35
  ATA_COMMAND_DMA_READ			= 0xc8
  ATA_COMMAND_DMA_WRITE			= 0xca
  ATA_COMMAND_CACHE_FLUSH		= 0xe7
  ATA_COMMAND_CACHE_FLUSH_EXT		= 0xea
  ATA_COMMAND_IDENTIFY			= 0xec

  ATAPI_COMMAND_PACKET			= 0xa0
  ATAPI_COMMAND_IDENTIFY		= 0xa1
  # PACKET Command opcodes:
  ATAPI_OPCODE_READ_CAPACITY		= 0x25
  ATAPI_OPCODE_READ			= 0xa8
  ATAPI_OPCODE_EJECT			= 0x1b
ATA_PORT_STATUS		= 7	# read
  ATA_STATUS_BSY		= 0b10000000	# BSY busy
  ATA_STATUS_DRDY		= 0b01000000	# DRDY device ready
  ATA_STATUS_DF			= 0b00100000	# DF device fault
  ATA_STATUS_DSC		= 0b00010000	# DSC seek complete
  ATA_STATUS_DRQ		= 0b00001000	# DRQ data transfer requested
  ATA_STATUS_CORR		= 0b00000100	# CORR data corrected
  ATA_STATUS_IDX		= 0b00000010	# IDX index mark
  ATA_STATUS_ERR		= 0b00000001	# ERR error
ATA_PORT_DCR		= 0x206	# (206-8 for TERT/QUAT) device control register
  ATA_DCR_nIEN			= 1	# no INT ENable
  ATA_DCR_SRST			= 2	# software reset (all ata drives on bus)
  ATA_DCR_HOB			= 7	# cmd: read High Order Byte of LBA48


.struct 0			#ATAPI: M = mandatory, u=unused, O=optional
				#                         /---- ATAPI
ATA_ID_CONFIG:			.word 0 	#0     0  M 2 Fixed
	# 15:14: protocol type: 0? = ATA, 10 = atapi, 11 = reserved
	# 13: reserved
	# 12:8: device type
	# 7: removable
	# 6:5 CMD DRQ type:
	#    00=microprocessor DRQ (DRQ within 3 ms of 0xA0 packet cmd)
	#    01=Interrupt DRQ: within 10 ms)
	#    10=accellerated DRQ: assert DRQ within 50us
	#    11=reserved
	# 4:2 reserved
	# 1:0 command packet size: 00=12 bytes, 01=16 bytes, 1X=reserved
	#    
ATA_ID_NUM_CYLINDERS:		.word 0		#1     2  u 2
ATA_ID_RESERVED1:		.word 0		#2     4  u 2
ATA_ID_NUM_HEADS:		.word 0		#3     6  u 2
ATA_ID_BYTES_PER_TRACKu:	.word 0 	#4     8  u 2 unformtd bytes/trk
ATA_ID_BYTES_PER_SECTORu:	.word 0 	#5     10 u 2 unformtd bytes/sec
.struct 12
ATA_ID_SECTORS_PER_TRACK:	.word 0		#6     12 u 2
ATA_ID_VENDOR_SPEC1:		.word 0,0,0 	#7-9   14	u 6
.struct 20
ATA_ID_SERIAL_NO:		.space 20 	#10-19 20 O 10 Fixed
ATA_ID_BUFFER_TYPE:		.word 0 	#20    40 u 2
ATA_ID_BUFFER_SIZE:		.word 0 	#21    42 u 2
ATA_ID_NUM_ECC_BYTES:		.word 0 	#22    44 u 2
ATA_ID_FIRMWARE_REV:		.space 8 	#23-26 46 M 8 #Fixed ASCII (18c)
.struct 54
ATA_ID_MODEL_NAME:		.space 40 	#27-46 54 M 40 # ASCII
ATA_ID_MULTIPLE_SEC_PER_INT:	.word 0 	#47    94 u 2
ATA_ID_DWIO:			.word 0 	#48    96 u 2 # reserved
ATA_ID_LBADMA:/*CAPABILITIES*/	.word 0 	#49    98 M 2 
	# bit 15: reserved for itnerleaved DMA
	# bit 14: reserved for proxy itnerrupt
	# bit 13: overlap operation supported
	# bit 12: reserved
	# bit 11: IORDY supported
	# bit 10: IORDY can be disabled
	# bit  9: LBA supported
	# bit  8: DMA supported
ATA_ID_RESERVED2:		.word 0 	#50   100 u 2 # reserved
ATA_ID_PIO_TI_MODE:		.word 0 	#51   102 M 2 # PIO cycle timing
ATA_ID_DMA_TI_MODE:		.word 0 	#52   104 M 2 # DMA cycle timing
.struct 106
ATA_ID_RESERVED3:/*FIELDVALID*/	.word 0 	#53   106 M 2
	# bits 15:2 reserved (fixed)
	# bit 1: fields in words 64-70 valid (fixed)
	# bit 0: fields in words 54-58 valid (variable)
ATA_ID_AP_NUM_CYLINDERS:	.word 0 	#54    108 u 2 cur Cylinders
ATA_ID_AP_NUM_HEADS:		.word 0 	#55    110 u 2 cur Heads
ATA_ID_AP_SECTORS_PER_TRACK:	.word 0 	#56    112 u 2 cur Sectors
ATA_ID_CAPACITY:		.word 0,0 	#57-58 114 u 4 cur capacity
ATA_ID_SECTORS_PER_INT:		.word 0 	#59    118 u 2 reserved 
.struct 120
ATA_ID_LBA_SECTORS:/*MAX_LBA*/	.word 0,0 	#60-61 120 u 4 usr addrsble sect
ATA_ID_SIN_DMA_MODES:		.word 0 	#62    124 M 2
	# high byte: singleword DMA transfer mode active (variable)
	# low byte:  singleword DMA transfer modes supported (fixed)
ATA_ID_MUL_DMA_MODES:		.word 0 	#63    126 M 2
	# high byte: multiword DMA transfer mode active (var)
	# low byte: multiword DMA transfer modes supported (fixed)
ATA_ID_ADV_PIO_MODE:		.word 0		# 64   128 M
	# high byte: reserved
	# low byte: Advanced PIO transfer mode supported (fixed)
ATA_ID_MIN_MWORD_DMA_TCT:	.word 0		# 65   130 M
	# minimum multiword DMA transfer cycle time per word (ns)
ATA_ID_RECOMMENDED_MWORD_DMA_TCT:.word 0	# 66   132 o Fixed
	# manufacturers recommended multiword dma transfer cycle time (ns)
ATA_ID_MIN_PIO_TCT_WO_FLOWCTL:	.word 0		# 67	   o Fixed
ATA_ID_MIN_PIO_TCT_W_IORDY_FLOWCTL:.word 0	# 68	   o Fixed
ATA_ID_RESERVED5:		.word 0,0	# 69-70	   u
ATA_ID_OVERLAP_RELEASE_TIME:	.word 0		# 71 O fixed, (microsec)
ATA_ID_SERVICE_RELEASE_TIME:	.word 0		# 72 O fixed, (microsec)
ATA_ID_MAJOR_REVISION:		.word 0		# 73 O fixed (-1 = unsupp)
ATA_ID_MINOR_VERSION:		.word 0		# 74 O fixed (-1 = unsupp)
ATA_ID_RESERVED6:		.space 127-75	# reserved unused
.struct 164
ATA_ID_COMMANDSETS:		.word 0		# 164
.struct 200
ATA_ID_MAX_LBA_EXT:		.word 0		# 200
.struct 256
ATA_ID_VENDOR_SPEC2:		.space 64 	# 256	64
ATA_ID_RESERVED7:		.word 0 	# 320

.data
ata_bus_presence: .byte 0	# bit x: IDEx
ata_buses:
	.word IO_ATA_PRIMARY
	.word IO_ATA_SECONDARY
	.word IO_ATA_TERTIARY
	.word IO_ATA_QUATERNARY
ata_bus_dcr_rel:
	.word ATA_PORT_DCR
	.word ATA_PORT_DCR
	.word ATA_PORT_DCR - 8
	.word ATA_PORT_DCR - 8


.data
	TYPE_ATA = 1
	TYPE_ATAPI = 2
ata_drive_types: .space 8
.text
.code32


ata_list_drives:

	#cli

	# Detect 'floating bus': unwired, status register will read 0xFF

	# print	"Detecting ATA buses:"

	xor	ecx, ecx
1:	mov	dx, [ata_buses + ecx * 2]
	add	dx, ATA_PORT_STATUS
	in	al, dx
	mov	dl, al
	inc	dl	# 0xFF: 'floating bus'
	jz	0f
	mov	al, 1
	shl	al, cl
	or	byte ptr [ata_bus_presence], al
	PRINT " IDE"
	mov	dl, cl
	call	printhex1
0:
	inc	cx
	cmp	cx, 4
	jb	1b

	mov	dl, [ata_bus_presence]

	or	dl, dl
	jnz	0f
	PRINTc	4, "None."
0:	call	newline


	# For all detected buses, check master and slave:

	xor	cl, cl
0:	mov	al, 1
	shl	al, cl
	test	byte ptr [ata_bus_presence], al
	jz	1f

	mov	ah, cl
	xor	al, al

3:	push	cx
	push	ax
	call	ata_list_drive
	pop	ax
	pop	cx
	inc	al
	cmp	al, 2
	jb	3b

1:	inc	cl
	cmp	cl, 4
	jb	0b

2:	#sti

	# list array of ata_drive_types
	mov	esi, offset ata_drive_types
	mov	ecx, 8
	mov	dh, -1
0:	lodsb
	mov	dl, al
	call	printhex2

	cmp	dl, TYPE_ATAPI
	jne	1f
	mov	dh, 8
	sub	dh, cl
1:
	mov	al, ' '
	call	printchar
	loop	0b
	call	newline

	mov	dl, dh
	call	printhex2

	cmp	dh, -1
	je	0f

	println "Attempting to read CDROM (press key)"
	xor	ah, ah
	call	keyboard

	mov	ah, dh
	mov	al, ah
	shr	ah, 1
	and	al, 1
	call	ata_get_ports$

	push	edx
	call	atapi_read_capacity$
	pop	edx

	mov	ebx, 16	# LBA
	mov	ecx, 1	# number of sectors
	call	atapi_read12$

	
0:
	ret

# in: ah = ata bus
# out: edx = [DCR, Base]
ata_get_ports$:
	push	eax
	movzx	edx, ah
	mov	ax, [ata_buses + edx * 2]
	mov	dx, [ata_bus_dcr_rel + edx * 2]
	add	dx, ax
	shl	edx, 16
	mov	dx, ax
	pop	eax
	ret

# in: ah = ATA bus index (0..3)
# in: al = drive (0 or 1)
ata_list_drive:
	COLOR 7
	call	ata_get_ports$
	# EDX: DSR, Base

	shl	ah, 1
	add	al, ah
	mov	bl, al

	# Proposed algorithm from osdev:
	# 1) select drive
	# 2) write 0 to sector_count, and the 3 LBA registers
	# 3) send IDENTIFY command
	# 4) read status port (same port)
	# 5) if 0, drive doesnt exist, abort.
	# 6) poll status port until BSY is clear
	# 7) check LBAmid/hi ports: if nonzero: not ATA, abort.
	# 8) continue polling until DRQ or ERR
	# 9) read 256 words from data port.

	# implemented:
	# 1) wait for RDY
	# 2) select drive
	# 3) wait BSY clear
	# 4) write nIEN 
	# 5) set PIO
	# 6) clear sector_count and the 3 LBA registers
	# 7) send IDENTIFY command (0xEC)
	# 8) read status port. if 0, abort
	# 9) wait status RDY clear
	# 10) wait DRQ
	# 11) if DRQ times out, send ATAPI IDENTIFY (0xA1)
	# 12) wait BSY clear RDY set
	# 13) wait DRQ

	push	dx
	PRINTc	15, "* ATA"
	mov	dl, ah
	call	printhex1
	PRINTc	15, " Drive "
	mov	dl, al
	call	printhex1
	PRINTc	15, ": "
	pop	dx

	push	ax
	call	ata_select_drive$
	pop	ax
	jc	ata_timeout$
	jz	nodrive$

	mov	ax, ATA_STATUS_BSY << 8
	call	ata_wait_status$
	jc	ata_timeout$

	push	edx
	ror	edx, 16
	mov	al, 0b0001010 # 'nIEN'(1000b) - skip INTRQ_WAIT
	out	dx, al	
	ror	edx, 16


	add	dx, ATA_PORT_FEATURE 
	mov	al, 0	# 0 = PIO, 1 = DMA
	out	dx, al

	# Set to 0: Sector count, LBA lo, LBA mid, LBA hi
	xor	eax, eax
	add	dx, ATA_PORT_SECTOR_COUNT - ATA_PORT_FEATURE
	out	dx, eax		# out DWORD = 4x out byte to 4 consec. ports
	pop	edx

	# Send ID command
	push	dx
	add	dx, ATA_PORT_COMMAND
	mov	al, ATA_COMMAND_IDENTIFY
	out	dx, al	# write command
	in	al, dx	# read status
	pop	dx
	.if ATA_DEBUG
		call	ata_print_status$
	.endif
	
	or	al, al
	jz	nodrive$	# drive doesnt exist	
	# this should work but ATAPI is returning RDY.
	#test	al, ATA_STATUS_ERR	# ATAPI / SATA
	#jnz	atapi$

	# Check registers:
	push	dx
	add	dx, ATA_PORT_ADDRESS2
	in	ax, dx	# read port ADDR2 and ADDR3
	mov	dx, ax
	.if ATA_DEBUG
		call	printhex4
		PRINTCHAR ' '
	.endif
	pop	dx

	# ax=0000 : PATA
	# ax=c33c : SATA
	# ax=EB14 : PATAPI
	# ax=9669 : SATAPI

	or	ax, ax
	jz	ata$
	cmp	ax, 0xeb14
	jz	atapi$
	cmp	ax, 0xc33c
	jz	sata$

	# try atapi anyway
	jmp	atapi$


sata$:	PRINT "SATA - not implemented"
	jmp	done$

ata$:	mov	bh, TYPE_ATA
	call	ata_wait_ready$
	jc	ata_timeout$
	call	ata_wait_DRQ1$
	LOAD_TXT "ATA   "
	jnc	read$	# has data!

	# DRQ fail: fallthrough to try atapi

atapi$:	mov	bh, TYPE_ATAPI
	push	ax
	push	dx
	add	dx, ATA_PORT_COMMAND
	mov	al, ATAPI_COMMAND_IDENTIFY
	out	dx, al
	pop	dx
	pop	ax

	# wait IRQ / poll BSY/DRQ
	call	ata_wait_ready$
	jc	ata_timeout$
	call	ata_wait_DRQ1$
	jc	ata_timeout$

	LOAD_TXT "ATAPI "

######## 512 bytes of data ready!
read$:	call	print

	.data
		parameters_buffer$: .space 512
	.text
	push	dx
	add	dx, ATA_PORT_DATA
	push	es
	push	ds
	pop	es
	mov	ecx, 0x100
	mov	edi, offset parameters_buffer$
	rep	insw
	pop	es
	pop	dx

	# store drive type 
	mov	al, bh
	movzx	ebx, bl
	mov	[ata_drive_types + ebx], al

	.if ATA_DEBUG > 1
		PRINTLNc 14, "Raw Data: "
		mov	esi, offset parameters_buffer$
		mov	ecx, 256
	0:	lodsb
		PRINTCHAR al
		loop	0b
		call	newline
	.endif

	.macro ATA_ID_STRING_PRINT
		push	esi
		push	ecx
	0:	lodsw
		xchg	al, ah
		mov	[esi-2], ax
		loop	0b
		pop	ecx
		pop	esi

		PRINT_START
	0:	lodsb
		stosw
		cmp	al, ' '	# if current char is not space, update pos
		je	1f
		mov	[screen_pos], edi
	1:	loop	0b
		PRINT_END ignorepos=1	# effectively trim space
	.endm

	PRINTc	15, "Model: "
	mov	esi, offset parameters_buffer$
	add	esi, ATA_ID_MODEL_NAME
	mov	ecx, 40 / 2
	ATA_ID_STRING_PRINT
0:
	PRINTc	15, " Serial: "
	mov	esi, offset parameters_buffer$
	add	esi, ATA_ID_SERIAL_NO
	mov	ecx, 20 / 2
	ATA_ID_STRING_PRINT

	PRINTc	15, " Firmware rev: "
	mov	esi, offset parameters_buffer$
	add	esi, ATA_ID_FIRMWARE_REV
	mov	ecx, 8 / 2
	ATA_ID_STRING_PRINT

	call	newline

	###
	COLOR 8

	##################################################
	PRINTc	7, "Word 0: "
	mov	dx, [parameters_buffer$ + ATA_ID_CONFIG]
	call	printhex
	# 15:14: protocol type: 0? = ATA, 10 = atapi, 11 = reserved
	test	dh, 1 << 7
	jnz	0f
	PRINT	" ATA "
	jmp	2f
0:	test	dh, 1 << 6
	jnz	0f
	PRINT	" ATAPI "
	jmp	2f
0:	PRINT	" Reserved "
2:
	# 12:8: device type
	push	dx
	shr	dx, 8
	and	dl, 0b11111
	PRINT	"DevType: "
	call	printhex1
	pop	dx

	# 7: removable
	test	dl, 1<<7
	jz	0f
	PRINT	" Removable "
0:	

	# 6:5 CMD DRQ type:
	#    00=microprocessor DRQ (DRQ within 3 ms of 0xA0 packet cmd)
	#    01=Interrupt DRQ: within 10 ms)
	#    10=accellerated DRQ: assert DRQ within 50us
	#    11=reserved
	mov	al, dl
	shr	al, 5
	and	al, 3
	jnz	0f
	PRINT " mDRQ "
	jmp	1f
0:	cmp	al, 1
	jnz	0f
	PRINT " intDRQ "
	jmp	1f
0:	cmp	al, 2
	jnz	1f
	PRINT " aDRQ "
1:
	# 1:0 command packet size: 00=12 bytes, 01=16 bytes, 1X=reserved
	and	edx, 3
	shl	dl, 2
	add	dl, 12
	PRINT "CMDPacketSize: "
	call	printdec32

	##################################################
	

	mov	dx, [parameters_buffer$ + 2* 83]
	test	dx, 1<<10
	jz	0f
	PRINTc	7, " LBA48 "
0:	
	mov	dx, [parameters_buffer$ + 2* 88]
	PRINTc	7, " UDMA: "
	call	printhex4

	# if master drive:
	mov	dx, [parameters_buffer$ + 2* 93]
	test	dx, 1<<12
	jz	0f
	PRINTc	7, " 80-pin cable "
0:

	PRINTc	7, " LBA28 sectors: "
	mov	edx, [parameters_buffer$ + 2* 60]
	call	printhex8

	PRINTc	7, " LBA48 sectors: "
	mov	edx, [parameters_buffer$ + 2* 100 + 4]
	call	printhex8
	mov	edx, [parameters_buffer$ + 2* 100 + 0]
	call	printhex8

	PRINTCHAR ' '
	mov	dx, bx
	call	printhex
	call	newline
	###

done$:	ret

ata_timeout$:
	LOAD_TXT "Timeout"
	jmp	1f
nodrive$:
	LOAD_TXT "None"
1:	PRINT_START 12
	call	__println
	PRINT_END
	stc
	jmp	done$

ata_error$:
	PRINTc	4, "ERROR "
	push	dx
	add	dx, ATA_PORT_ERROR
	in	al, dx
	call	ata_print_error$
	pop	dx
	stc
	ret

######################################################################

# in: al = status register byte
ata_print_status$:
	.data
	9:	.ascii "BSY\0 DRDY\0DF\0  DSC\0 DRQ\0 CORR\0IDX\0 ERR\0\0"
	.text
	push	esi
	mov	esi, offset 9b
	pushcolor 8
	call	ata_print_bits$
	popcolor
	pop	esi
	ret

ata_print_error$:
	.data
	9: .ascii "BBK\0 UNC\0 MC\0  IDNF\0MCR\0 ABRT\0T0NF\0AMNF\0"
	.text
	push	esi
	mov	esi, offset 9b
	pushcolor 4
	call	ata_print_bits$
	popcolor
	pop	esi
	ret


ata_print_bits$:
	push	ax
	push	dx
	mov	dl, al
	call	printhex2
	pop	dx
	pop	ax
	PRINT_START 
0:	shl	al, 1
	jnc	1f
	push	ax
	push	esi
	call	__print
	pop	esi
	pop	ax
	add	edi, 2
1:	add	esi, 5
	test	al, al
	jnz	0b
	PRINT_END
	ret

# in: edx = [DCR, base]
# in: ah = status bits to be 0
# in: al = status bits to be 1
ata_wait_status$:
	push	bx
	mov	bx, ax

	.if ATA_DEBUG > 2
	push	dx
	PRINTc	5 "[Wait1:"
	mov	al, bl
	call	ata_print_status$
	PRINTc	5 " Wait0:"
	mov	al, bh
	call	ata_print_status$
	PRINTc	5, "]"
	pop	dx
	.endif

	# by default error bits should be 0
	or	bh, ATA_STATUS_ERR | ATA_STATUS_CORR

	push	ecx
	push	dx
	add	dx, ATA_PORT_STATUS
	mov	ecx, 5 # 0x1000

0:	in	al, dx
	mov	ah, bh
	and	ah, al	# test for bits to be 0
	jnz	2f
	and	al, bl
	cmp	al, bl	# test for bits to be 1
	jz	0f
2:	loop	0b

1:	call	ata_print_status$
	test	al, ATA_STATUS_ERR
	jz	1f
	add	dx, ATA_PORT_ERROR - ATA_PORT_STATUS
	in	al, dx
	call	ata_print_error$
1:	stc
0:	pop	dx
	pop	ecx
	pop	bx
	ret

# Waits BSY=0 DRDY=1 ERR=0
# in: edx = HI = DCR, LO (dx) = base port
# out: CF ZF
ata_wait_ready$:
	mov	ax, (ATA_STATUS_BSY << 8) 
	call	ata_wait_status$
	mov	ax, ATA_STATUS_DRDY
	call	ata_wait_status$
	ret

# Waits DRQ = 1 (Device has data to send)
# in: edx = HI = DCR, LO (dx) = base port
ata_wait_DRQ1$:
	mov	ax, ATA_STATUS_DRQ
	call	ata_wait_status$
	ret

# Waits for DRQ=0 (device ready to read data from host)
ata_wait_DRQ0$:
	mov	ax, ATA_STATUS_DRQ << 8
	call	ata_wait_status$
	ret

# in: al = drive number
# in: edx = HI = DCR, LO (dx) = base port
# out: nothing.
ata_select_drive$:
	push	ax
	mov	ax, ATA_STATUS_BSY << 8
	call	ata_wait_status$
	pop	ax
	jc	1f

	push	edx
	add	dx, ATA_PORT_DRIVE_SELECT
	shl	al, 4
	or	al, 0xA0 	# (B0 for slave)
	#or	al, 0xef	#  all bits 1, bit 4=0 drive 0, 1=drive 1
	out	dx, al
	
	add	dx, ATA_PORT_STATUS - ATA_PORT_DRIVE_SELECT
	in	al, dx
	.if ATA_DEBUG
		call	ata_print_status$
	.endif
	or	al, al
	pop	edx
1:	pushf
	call	ata_dbg$
	popf
	ret


# simulate 400ns delay
# in: edx = HI = DCR, LO (dx) = base port
ata_select_delay:
	push	ax
	push	edx
	ror	edx, 16
	and	dx, 0xff0	# dx = DCR
	in	al, dx
	in	al, dx
	in	al, dx
	in	al, dx
	pop	edx
	pop	ax
	ret

# in: edx = [DCR, Base]
ata_software_reset:
	ror	edx, 16
	# NOTE: DCR is a readonly register, so the other bits (nIEN, HOB)
	# need to be remembered.
	mov	al, ATA_DCR_SRST
	out	dx, al	# reset both drives on bus and select master drive
	xor	al, al
	out	dx, al
	ror	edx, 16
	ret

ata_dbg$:
	PRINTc	9 "STATUS["
	push	dx
	add	dx, ATA_PORT_STATUS
	in	al, dx
	call	ata_print_status$
	add	dx, ATA_PORT_ERROR - ATA_PORT_STATUS
	in	al, dx
	call	ata_print_error$
	pop	dx
	PRINTc	9 "]"
	ret



################################################################ ATAPI ######
ATAPI_SECTOR_SIZE = 2048

atapi_packet_clear$:
	push	edi
	push	eax
	mov	edi, offset atapi_packet
	xor	eax, eax
	stosd
	stosd
	stosd
	pop	eax
	pop	edi
	ret

# out: ebx = last LBA
# out: eax = block length
atapi_read_capacity$:
	call	atapi_packet_clear$
	mov	[atapi_packet_opcode], byte ptr ATAPI_OPCODE_READ_CAPACITY
	mov	esi, offset atapi_packet
	mov	ecx, 8
	call	atapi_packet_command
	mov	edx, ecx
	PRINT "Received "
	call	printdec32
	PRINT " bytes: "
	lodsd
	xchg	al, ah
	ror	eax, 16
	xchg	al, ah
	mov	edx, eax
	mov	ebx, eax
	PRINT	"LBA: 0x"
	call	printhex8
	lodsd
	xchg	al, ah
	ror	eax, 16
	xchg	al, ah
	mov	edx, eax
	PRINT	" Block Length: 0x"
	call	printhex8
	call	newline

	push	eax
	mov	eax, edx
	inc	ebx
	mul	ebx
	dec	ebx
	PRINT " Capacity: "
	call	printhex8
	mov	edx, eax
	call	printhex8
	pop	eax
	ret

atapi_print_packet$:

	push	dx
	push	esi
	mov	ecx, 12
	PRINT "ATAPI PACKET: "
0:	lodsb
	mov	dl, al
	call	printhex2
	mov	al, ' '
	call	printchar
	loop	0b
	call	newline
	pop	esi
	pop	dx

	ret



# in: edx [DCR, Base], ebx=LBA
# read 1 sector
# out: esi = offset to buffer, ecx = data in buffer
atapi_read12$:
	call	atapi_packet_clear$

	.if ATA_DEBUG > 1
		push	edx
		mov	edx, ebx
		PRINT "LBA: "
		call	printhex8
		pop	edx

		mov	esi, offset atapi_packet
		call	atapi_print_packet$
		call	newline
	.endif

	# convert to MSB:
	xchg	bl, bh
	ror	ebx, 16
	xchg	bl, bh

	mov	[atapi_packet_opcode], byte ptr ATAPI_OPCODE_READ
	mov	[atapi_packet_LBA], ebx
	mov	[atapi_packet_ext_transfer_length + 3], byte ptr 1
	mov	esi, offset atapi_packet

	mov	ecx, ATAPI_SECTOR_SIZE
	call	atapi_packet_command
	ret

.data
atapi_packet: 
	atapi_packet_opcode: .byte 0
		# bits 7,6,5: group code
		# bits 4:0: command code
	atapi_packet_reserved: .byte 0
	atapi_packet_LBA: .long 0	# MSB, base 0
	atapi_packet_ext_transfer_length: .byte 0	# 4 bytes
	atapi_packet_transfer_length: .word 0 # MSB (translen/paramlen/alloclen)
	# 0 means no data transfer...
	# transfer length: number of blocks or number of bytes
	# parameter list length: number of bytes.
	# allocation length:  host buffer size
	atapi_packet_reserved2: .byte 0,0,0
	# normal commands use _length, not _ext_length
	# extended commands use ext_length (4 bytes) where the middle 2 bytes
	# overlap the _length
	# Since most fields are reserved, the following parameters apply:
	# - db opcode
	# - dd lba
	# - dd transfer length (or dw)
.text


####### ATAPI Packet Command
# in: edx = [DCR, Base]
# in: esi = 6 word packet data
# in: ecx = max transfer size
# out: esi = offset to buffer, ecx = data in buffer
atapi_packet_command:
	cmp	ecx, ATAPI_SECTOR_SIZE
	jbe	0f

	PRINTc	4, "ATAPI Packet Command: Transfer length too large"
	stc
	ret
0:
	.if ATA_DEBUG > 1
		PRINT "Select Drive "
	.endif
	call	ata_select_drive$
	jc	ata_timeout$


	mov	ax, ( ATA_STATUS_BSY | ATA_STATUS_DRQ ) << 8
	call	ata_wait_status$
	jc	ata_timeout$

	.if ATA_DEBUG > 1
		call	ata_dbg$
		call	newline

		PRINT "PIO Mode "
	.endif

	push	dx
	add	dx, ATA_PORT_FEATURE 
	mov	al, 0	# 0 = PIO, 1 = DMA
	out	dx, al
	pop	dx

	.if ATA_DEBUG > 1
		call	ata_dbg$
		call	newline

		PRINT "Transfer Size "
	.endif

	push	dx
	add	dx, ATA_PORT_ADDRESS2
	mov	ax, cx
	out	dx, ax
	pop	dx

	.if ATA_DEBUG > 1
		call	ata_dbg$
		call	newline

		PRINT "Command PACKET "
	.endif

	# Send command
	push	dx
	add	dx, ATA_PORT_COMMAND
	mov	al, ATAPI_COMMAND_PACKET
	out	dx, al	# write command
	in	al, dx	# read status
	pop	dx

	.if ATA_DEBUG > 1
		call	ata_dbg$
		call	newline
	.endif
	
	# TODO: check IO clear and CoD set

	.macro WAIT_DATAREADY
	.if ATA_DEBUG > 1
		PRINT "Wait ready "
	.endif
	mov	ax, (ATA_STATUS_BSY << 8) | ATA_STATUS_DRQ
	call	ata_wait_status$
	jc	ata_timeout$

	.if ATA_DEBUG > 1
		call	ata_dbg$
	.endif
	# DRQ is set, so read size:
	push	dx
	add	dx, ATA_PORT_ADDRESS2
	in	ax, dx
	mov	dx, ax
	mov	dx, ax
	.if ATA_DEBUG > 1
		PRINT "Transfer size: "
		call	printhex4
		call	newline
	.endif
	pop	dx
	.endm

	WAIT_DATAREADY

	.if ATA_DEBUG > 0
	PRINT "Write Packet "
		push	dx
		push	esi
		.rept 12
		lodsb
		mov	dl, al
		call	printhex2
		mov	al, ' '
		call	printchar
		.endr
		call	newline
		pop	esi
		pop	dx
	.endif

	# write packet data
	push	dx
	push	ecx
	add	dx, ATA_PORT_DATA
	mov	ecx, 6
	rep	outsw
	pop	ecx
	pop	dx

	.if ATA_DEBUG > 1
	call	ata_dbg$
	.endif

	# TODO: check IO set and CoD clear
	WAIT_DATAREADY

	xor	ecx, ecx
	mov	cx, ax

	.if ATA_DEBUG > 1
	push	edx
	mov	edx, ecx
	PRINT "Reading "
	call	printdec32
	PRINT " bytes"
	pop	edx
	.endif

	.data
		data_buffer$: .space ATAPI_SECTOR_SIZE
	.text

	push	ecx
	push	dx
	add	dx, ATA_PORT_DATA
	push	es
	push	ds
	pop	es
	mov	edi, offset data_buffer$
	inc	ecx
	shr	ecx, 1
	rep	insw
	pop	es
	pop	dx
	pop	ecx

	push	dx
	add	dx, ATA_PORT_STATUS
	in	al, dx
	pop	dx
	test	al, ATA_STATUS_BSY | ATA_STATUS_DRQ

	# drq 0. If more data then device sets BSY: goto 'wait for data ready'
	# device sets CoD, IO, DRDY, clears BSY and DRQ.

	.if ATA_DEBUG > 1
		PRINTln "Data read."
	.endif

	mov	esi, offset data_buffer$
	clc
	ret