.section .init, "ax"
.global _start

_start:
    /* Set stack pointer to the top of the CPU's Block RAM (8KB = 0x2000) */
    li sp, 0x00002000  
    
    /* Jump into the C game loop */
    call main          

    /* Infinite loop if the game ever accidentally crashes or returns */
1:  j 1b