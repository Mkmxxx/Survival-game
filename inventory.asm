 //inventory system functions 
 //IF UPDATING, EDIT INDEX(LINE 6) AND OUTPUT(LINE 9)
 //ALSO UPDATE VIEW_INVENTORY FOR NOW

define(fp, x29) 
define(lr, x30)
.equ    index, 5

        .data 
output: .string "\nCooked Meat:%d\nRaw Meat:%d\nBerries:%d\nWood:%d\nWater:%d\n"     //string to improve 

        .bss 
        .balign 4 
inv:    .zero index*4

        .text 
        .balign 4 
        .global view_inventory
        .global add_inventory
        .global take_inventory

//TODO: improve print statement!!! (try stack arguments instead?)
view_inventory:
        stp     x29, x30, [sp, -16]!            //stp because of bl printf
        ldr     x14, =inv 
        ldr     x0, =output 
        ldr     w1, [x14] 
        ldr     w2, [x14, 4] 
        ldr     w3, [x14, 8] 
        ldr     w4, [x14, 12] 
        ldr     w5, [x14, 16]
        bl      printf 
        ldp     x29, x30, [sp], 16
        mov     x0, 0
        ret

//add_inventory(index, num) adds num to inv[index]
add_inventory: 
        cmp     w0, 0                           //if index < 0 or index >= len(inv), return -1
        b.lt    bad_input 
        cmp     w0, index
        b.ge    bad_input 
        lsl     w9, w0, 2                       //index = index * 4 for address calculating
        uxtw    x9, w9
        ldr     x10, =inv 
        add     x10, x10, x9 
        ldr     w11, [x10] 
        cmp     w11, 0                          //if inv[index] < 0, go bad_input
        b.lt    bad_input 
        add     w11, w11, w1                    //inv[index] = inv[index] + num
        str     w11, [x10] 
        mov     w0, 0 
        ret 

//take_inventory(index, num) takes num from inv[index]
take_inventory: 
        cmp     w0, 0                           //if index < 0 or index >= len(inv), return -1
        b.lt    bad_input 
        cmp     w0, index
        b.ge    bad_input 
        lsl     w9, w0, 2                       //index = index * 4 for address calculating
        uxtw    x9, w9
        ldr     x10, =inv 
        add     x10, x10, x9 
        ldr     w11, [x10] 
        cmp     w11, w1                         //if inv[index] < num, return -1 (not enough material)
        b.lt    bad_input 
        sub     w11, w11, w1                    //inv[index] = inv[index] - num
        str     w11, [x10] 
        mov     w0, 0 
        ret 

bad_input: 
        mov     w0, -1
        ret 
        