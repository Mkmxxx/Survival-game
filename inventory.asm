 //inventory system functions 

define(fp, x29) 
define(lr, x30) 

        .data 
output: .string "\n Meat:%d\n Berries:%d\n Wood:%d\n Hide:%d\n"     //string to improve 

        .bss 
        .balign 4 
inv:    .zero 16        //add more indices when we figure out how many items

        .text 
        .balign 4 

//improve when more indices are added

view:
        stp     x29, x30, [sp, -16]!
        ldr     x14, =inv 
        ldr     x0, =output 
        ldr     x1, [x14] 
        ldr     x2, [x14, 4] 
        ldr     x3, [x14, 8] 
        ldr     x4, [x14, 12] 
        bl      printf 
        ldp     x29, x30, [sp], 16
        mov     x0, 0
        ret

adding: 
        cmp     x0, 0 
        b.lt    bad_input 
        cmp     x0, 4 
        b.ge    bad_input 
        lsl     x9, x0, 2 
        ldr     x10, =inv 
        add     x10, x10, x9 
        ldr     x11, [x10] 
        cmp     x11, 0 
        b.lt    bad_input 
        add     x11, x11, x1 
        str     x11, [x10] 
        mov     x0, 0 
        ret 

taking: 
        cmp     x0, 0 
        b.lt    bad_input 
        cmp     x0, 4 
        b.ge    bad_input 
        lsl     x9, x0, 2 
        ldr     x10, =inv 
        add     x10, x10, x9 
        ldr     x11, [x10] 
        cmp     x11, x1 
        b.lt    bad_input 
        sub     x11, x11, x1 
        str     x11, [x10] 
        mov     x0, 0 
        ret 

bad_input: 
        mov     x0, -1
        ret 