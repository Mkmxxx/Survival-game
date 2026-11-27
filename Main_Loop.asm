.data
print_actions: .string "Choose an action:\n\n(1) Hunt\n(2) Gather water\n(3) Eat\n(4) Drink water\n(5) Explore\n(6) Build shelter\n(7) Sleep\n(8) Cook\n"
input: .string "%d"
number: .word 0
print_bad_action: .string "The action chosen could not be executed.\n"
death: .string "Your health has reached 0 so you have died.\n"
win: .string "Congratulations, you have survived the 30 days with %d health left!\n"


.global main
.text
main:
    stp x19,x20,[sp,#-16]!
    stp x21,x30,[sp,#-16]!
    mov x19,30 // number of days
    mov x20,1 // start day

game_loop:
    bl getHealth
    cmp x0,0
    b.le lose

    cmp x20,x19
    b.gt won
    bl printHealth
    bl printFood
    bl printWater
    bl printShelter
    bl printEnergy
    ldr x0, =print_actions
    bl printf
    mov x21,1 // action count
    b actions_loop

actions_loop:
    cmp x21,5
    b.gt check_food
    ldr x0,=input
    ldr x1,=number
    bl scanf
    ldr x1, =number
    ldr w5, [x1] // stores the user choice
    cmp w5,1
    b.eq hunting
    cmp w5,2
    b.eq gathering
    cmp w5,3
    b.eq eating
    cmp w5,4
    b.eq drinking
    cmp w5,5
    b.eq exploring
    cmp w5,6
    b.eq building
    cmp w5,7
    b.eq sleeping
    cmp w5,8
    b.eq cooking
    b bad_action

hunting:
    bl hunt
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
gathering:
    bl gatherWater
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
eating:
    bl eat
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
drinking:
    bl drinkWater
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
exploring:
    bl explore
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
building:
    bl buildShelter
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop
sleeping:
    b check_food
cooking:
    bl cook
    cmp w0,0
    b.ne bad_action
    add x21,x21,1
    b actions_loop

bad_action:
    ldr x0,=print_bad_action
    bl printf
    add x21,x21,1
    b actions_loop

check_food:
    bl getFood
    cmp x0,0
    b.gt check_water
    bl getHealth
    sub x0,x0,10
    bl setHealth
    b check_water
check_water:
    bl getWater
    cmp x0,0
    b.gt check_health_end
    bl getHealth
    sub x0,x0,10
    bl setHealth
    b check_health_end
check_health_end:
    bl getHealth
    cmp x0,0
    b.gt start_new_day
    b lose

start_new_day:
    bl sleep
    add x20,x20,1
    b game_loop

won:
    bl getHealth
    mov x1,x0
    ldr x0,=win
    bl printf
    b end_game

lose:
    ldr x0, =death
    bl printf
    b end_game

end_game:
    ldp x21,x30,[sp],#16
    ldp x19,x20,[sp],#16
    mov x0,#0
    ret
