MEMORY {
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 8192 
}

SECTIONS {
    .text : {
        *(.init)
        *(.text)
    } > RAM
    .data : { *(.data) } > RAM
    .bss : { *(.bss) } > RAM
}