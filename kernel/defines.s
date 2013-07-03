# .data layout
SECTION_DATA		= 0	# leave at 0 as there is still .data used.
SECTION_DATA_SEMAPHORES	= 1
SECTION_DATA_TLS	= 2
SECTION_DATA_CONCAT	= 3
SECTION_DATA_STRINGS	= 4
SECTION_DATA_SHELL_CMDS	= 5
SECTION_DATA_CLASSES	= 7
SECTION_DATA_CLASS_M_DECLARATIONS= 8
SECTION_DATA_CLASS_M_OVERRIDES= 9
SECTION_DATA_CLASS_M_STATIC= 10
SECTION_DATA_CLASSES_END = 10
SECTION_DATA_PCI_DRIVERINFO	= 18
SECTION_DATA_FONTS	= 19
SECTION_DATA_KAPI_IDX	= 20
SECTION_DATA_KAPI_PTR	= 21
SECTION_DATA_KAPI_STR	= 22
SECTION_DATA_KAPI_ARG	= 23
SECTION_DATA_BSS	= 99
SECTION_DATA_SIGNATURE	= SECTION_DATA_BSS +1

# .text layout
SECTION_CODE_TEXT16	= 0
SECTION_CODE_DATA16	= 1	# keep within 64k
SECTION_CODE_TEXT16_END	= 2
SECTION_CODE_TEXT32	= 3

