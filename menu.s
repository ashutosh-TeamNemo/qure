.intel_syntax noprefix


# menu uses in textmode:
# - list vesa video modes
# - list drives to install
# - browse ramdisk
# expect es:di at line start


.struct 0
menu_title:
.struct 32
menu_code:
.struct 32 + 4
menu_item_size:
.macro MENUITEM code, title
	s = .
	. = s + menu_title
	.asciz "\title"
	. = s + menu_code
	.long \code
.endm

.data
menusel: .byte 0
menuitems:
MENUITEM printregisters	"Print Registers"
MENUITEM gfxmode	"Graphics Mode"
MENUITEM listdrives	"List Drives"
MENUITEM writebootsector "Write Bootsector"
MENUITEM inspectmem	"InspectMem"
MENUITEM inspecthdd	"Inspect HDD"
MENUITEM protected_mode	"Protected Mode"
menuitemcount:.byte ( . - menuitems ) / menu_item_size
.text
menu:	mov	ax, 0x0f00
	call	cls

drawmenu$:
	mov	dh, [menuitemcount]

	movsx	ax, byte ptr [menusel]
	or	ax, ax
	jns	0f
	xor	ax, ax
0:	div	dh
	mov	[menusel], ah

	mov	di, 160 * 3
	xor	dl, dl
0:	mov	ax, 0xf000 #mov	si, offset menu_color
	cmp	dl, [menusel]
	jnz	1f
	xor	ah, 0x20
1:	add	di, 20
	push	di
	mov	cx, menu_code # MUST be after menu_title!
	rep	stosw
	pop	di

	push	ax
	mov	ax, menu_item_size
	mul	dl
	mov	si, ax
	push	dx
	mov	dx, ax
	mov	ah, 0xf1
	call	printhex
	pop	dx
	pop	ax
	add	si, offset menuitems
	push	si
	add	si, menu_title
	call	println
	pop	si

	inc	dl
	cmp	dl, dh  
	jb	0b

	xor	ah, ah
	int	0x16
	mov	dx, ax
	mov	ah, 0xf4
	PRINT	"KeyCode: "
	call	printhex
	call	newline

	mov	ah, 0xf3

	PRINT	"MenuItemOffset: "
	mov	ah, [menusel]
	mov	al, menu_item_size
	mul	ah
	mov	si, offset menuitems
	add	si, ax
	push	dx
	mov	dx, ax
	mov	ah, 0xf3
	call	printhex
	PRINT	"Code: "
	mov	dx, [si + menu_code]
	call	printhex
	pop	dx


	cmp	dx, K_DOWN
	jne	1f
	inc	byte ptr [menusel]
	jmp	drawmenu$
1:
	cmp	dx, K_UP
	jne	1f
	dec	byte ptr [menusel]
	jmp	drawmenu$
1:
	cmp	dx, K_ENTER
	jne	1f

	#relocate offset
	mov	ax, ds
	shl	ax, 4
	add	ax, [si + menu_code]
	call	ax

	jmp	drawmenu$
1:
	cmp	dx, K_ESC
	je	2f
	cmp	dl, 'q'
	jz	2f

	mov	ah, 0xfb
	.data
	9: .asciz "Unknown key: "
	.text
	mov	si, 9b
	call	println
	
	call	printhex
	mov	ah, 0xf4
	stosw
	jmp	drawmenu$

2:	ret
