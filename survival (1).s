// ============================================================================
//  30-Day Survival Game  -  AArch64 / Linux
//  MAIN GAME SYSTEM (Ryan): main loop, day progression, game state, weather,
//  input parsing, win/lose.  Teammate sections are stubbed at the bottom.
//
//  Build (on AArch64 Linux, or use aarch64-linux-gnu-as/ld + qemu-aarch64):
//      as -o survival.o survival.s && ld -o survival survival.o && ./survival
//
//  TEAM CONVENTIONS (everyone please follow these)
//   * x19 ALWAYS holds the base address of the `player` struct. Never change it.
//   * x19-x28 are callee-saved: push/pop them if you use them.
//   * x0-x18 are caller-saved: any `bl` may clobber them.
//   * Every stat lives in `player` at an offset P_xxx (see below).
//   * Shared helpers:  sub_stat / add_stat   (x0 = offset, w1 = amount)
//                      print_str (x0 = string)   print_num (w0 = number)
//                      rng_next  (returns random 32-bit value in w0)
// ============================================================================

        .global _start

// ---- Linux syscall numbers ------------------------------------------------
        .equ SYS_READ,   63
        .equ SYS_WRITE,  64
        .equ SYS_EXIT,   93
        .equ STDIN,      0
        .equ STDOUT,     1

// ---- Game constants -------------------------------------------------------
        .equ MAX_DAYS,        30
        .equ BASE_ENERGY,     60      // morning energy with no shelter
        .equ SHELTER_BONUS,   10      // extra morning energy per shelter level
        .equ STORM_PENALTY,   20      // morning energy lost on a stormy day
        .equ MIN_ENERGY,      10      // below this the day ends automatically
        .equ HUNGER_DRAIN,    20      // overnight
        .equ THIRST_DRAIN,    25      // overnight
        .equ STARVE_DAMAGE,   15      // health lost if hunger is 0 overnight
        .equ DEHYDRATE_DAMAGE,20      // health lost if thirst is 0 overnight
        .equ STORM_DAMAGE,    10      // health lost in storm with shelter < 2

// ---- Game states ----------------------------------------------------------
        .equ STATE_RUNNING, 0
        .equ STATE_WON,     1
        .equ STATE_LOST,    2
        .equ STATE_QUIT,    3

// ---- Weather values -------------------------------------------------------
        .equ WEATHER_CLEAR,  0
        .equ WEATHER_CLOUDY, 1
        .equ WEATHER_RAIN,   2
        .equ WEATHER_STORM,  3

// ---- Player struct offsets (each field is a 32-bit word) ------------------
        .equ P_DAY,      0
        .equ P_HEALTH,   4
        .equ P_HUNGER,   8            // 100 = full, 0 = starving
        .equ P_THIRST,   12           // 100 = hydrated, 0 = dehydrated
        .equ P_ENERGY,   16
        .equ P_SHELTER,  20           // shelter level
        .equ P_STRENGTH, 24
        .equ P_SPEED,    28
        .equ P_WEATHER,  32
        .equ P_STATE,    36
        .equ P_SEED,     40           // RNG state
        .equ P_FOOD,     44           // inventory (RJ owns these)
        .equ P_WATER,    48
        .equ P_WOOD,     52
        .equ P_SIZE,     56

        .equ STAT_COUNT, 5            // rows in stat_table

// ============================================================================
        .text

_start:
        ldr     x19, =player          // x19 = player base, for the whole game
        bl      init_game
        ldr     x0, =str_intro
        bl      print_str

// ---------------------------- MAIN GAME LOOP --------------------------------
day_loop:
        ldr     w0, [x19, #P_STATE]
        cbnz    w0, game_over         // won / lost / quit -> finish
        bl      begin_day             // roll weather, set morning energy

action_loop:
        bl      print_status
        ldr     x0, =str_menu
        bl      print_str
        bl      read_choice           // w0 = 0 invalid, 1..6 = choice

        cmp     w0, #0
        b.eq    invalid_choice
        cmp     w0, #6
        b.eq    quit_game
        cmp     w0, #5
        b.eq    sleep_now             // sleeping ends the day

        // choices 1..4: look up the subroutine in the action table and call it
        sub     w0, w0, #1
        ldr     x1, =action_table
        ldr     x1, [x1, w0, uxtw #3]
        blr     x1

        bl      check_player          // did that action kill the player?
        ldr     w0, [x19, #P_STATE]
        cbnz    w0, game_over

        ldr     w0, [x19, #P_ENERGY]  // out of energy -> day ends
        cmp     w0, #MIN_ENERGY
        b.hs    action_loop
        ldr     x0, =str_exhausted
        bl      print_str

sleep_now:
        bl      end_day
        b       day_loop

invalid_choice:
        ldr     x0, =str_invalid
        bl      print_str
        b       action_loop

quit_game:
        mov     w0, #STATE_QUIT
        str     w0, [x19, #P_STATE]
        b       game_over

// ------------------------------ GAME OVER -----------------------------------
game_over:
        ldr     w0, [x19, #P_STATE]
        ldr     x1, =end_table
        ldr     x0, [x1, w0, uxtw #3]
        bl      print_str
        mov     x0, #0
        mov     x8, #SYS_EXIT
        svc     #0

// ============================================================================
//  init_game: set starting values
// ============================================================================
init_game:
        mov     w0, #1
        str     w0, [x19, #P_DAY]
        mov     w0, #100
        str     w0, [x19, #P_HEALTH]
        str     w0, [x19, #P_HUNGER]
        str     w0, [x19, #P_THIRST]
        str     w0, [x19, #P_ENERGY]
        str     wzr, [x19, #P_SHELTER]
        str     wzr, [x19, #P_WEATHER]
        mov     w0, #STATE_RUNNING
        str     w0, [x19, #P_STATE]
        mov     w0, #5
        str     w0, [x19, #P_STRENGTH]
        str     w0, [x19, #P_SPEED]
        mov     w0, #3
        str     w0, [x19, #P_FOOD]
        str     w0, [x19, #P_WATER]
        mov     w0, #2
        str     w0, [x19, #P_WOOD]

        mrs     x0, cntvct_el0        // hardware counter = unpredictable seed
        eor     w0, w0, w0, lsr #16
        cbnz    w0, 1f                // xorshift must never have a 0 seed
        mov     w0, #1
1:      str     w0, [x19, #P_SEED]
        ret

// ============================================================================
//  rng_next: xorshift32 using shifts + XOR.  Returns new value in w0.
// ============================================================================
rng_next:
        ldr     w0, [x19, #P_SEED]
        eor     w0, w0, w0, lsl #13
        eor     w0, w0, w0, lsr #17
        eor     w0, w0, w0, lsl #5
        str     w0, [x19, #P_SEED]
        ret

// ============================================================================
//  begin_day: pick weather, compute morning energy, print the day header
//     energy = BASE + shelter*BONUS  (-STORM_PENALTY if stormy), capped at 100
// ============================================================================
begin_day:
        stp     x29, x30, [sp, #-16]!

        bl      rng_next
        and     w0, w0, #3            // low 2 bits -> weather 0..3
        str     w0, [x19, #P_WEATHER]

        ldr     w1, [x19, #P_SHELTER]
        mov     w2, #SHELTER_BONUS
        mov     w3, #BASE_ENERGY
        madd    w3, w1, w2, w3        // w3 = shelter*bonus + base
        cmp     w0, #WEATHER_STORM
        b.ne    .Lno_storm
        sub     w3, w3, #STORM_PENALTY
.Lno_storm:
        mov     w4, #100
        cmp     w3, w4
        csel    w3, w3, w4, ls        // cap at 100
        str     w3, [x19, #P_ENERGY]

        ldr     x0, =str_day_hdr
        bl      print_str
        ldr     w0, [x19, #P_DAY]
        bl      print_num
        ldr     x0, =str_day_mid
        bl      print_str
        ldr     w0, [x19, #P_WEATHER]
        ldr     x1, =weather_table
        ldr     x0, [x1, w0, uxtw #3]
        bl      print_str
        ldr     x0, =str_nl
        bl      print_str

        ldp     x29, x30, [sp], #16
        ret

// ============================================================================
//  end_day: overnight drain, penalties, advance the day, check for the win
// ============================================================================
end_day:
        stp     x29, x30, [sp, #-16]!

        ldr     x0, =str_night
        bl      print_str

        mov     x0, #P_HUNGER
        mov     w1, #HUNGER_DRAIN
        bl      sub_stat
        mov     x0, #P_THIRST
        mov     w1, #THIRST_DRAIN
        bl      sub_stat

        ldr     w0, [x19, #P_HUNGER]  // starving?
        cbnz    w0, .Lnot_starving
        ldr     x0, =str_starving
        bl      print_str
        mov     x0, #P_HEALTH
        mov     w1, #STARVE_DAMAGE
        bl      sub_stat
.Lnot_starving:
        ldr     w0, [x19, #P_THIRST]  // dehydrated?
        cbnz    w0, .Lnot_parched
        ldr     x0, =str_parched
        bl      print_str
        mov     x0, #P_HEALTH
        mov     w1, #DEHYDRATE_DAMAGE
        bl      sub_stat
.Lnot_parched:
        ldr     w0, [x19, #P_WEATHER] // storm hits a weak shelter?
        cmp     w0, #WEATHER_STORM
        b.ne    .Lno_storm_dmg
        ldr     w0, [x19, #P_SHELTER]
        cmp     w0, #2
        b.hs    .Lno_storm_dmg
        ldr     x0, =str_storm_hit
        bl      print_str
        mov     x0, #P_HEALTH
        mov     w1, #STORM_DAMAGE
        bl      sub_stat
.Lno_storm_dmg:
        bl      check_player          // may set STATE_LOST
        ldr     w0, [x19, #P_STATE]
        cbnz    w0, .Lend_day_done    // dead: do not advance the day

        ldr     w0, [x19, #P_DAY]
        add     w0, w0, #1
        str     w0, [x19, #P_DAY]
        cmp     w0, #MAX_DAYS
        b.ls    .Lend_day_done        // still within day 1..30
        mov     w0, #STATE_WON        // survived through the end of day 30
        str     w0, [x19, #P_STATE]
.Lend_day_done:
        ldp     x29, x30, [sp], #16
        ret

// ============================================================================
//  check_player: health == 0  ->  STATE_LOST
// ============================================================================
check_player:
        ldr     w0, [x19, #P_HEALTH]
        cbnz    w0, 1f
        mov     w0, #STATE_LOST
        str     w0, [x19, #P_STATE]
1:      ret

// ============================================================================
//  sub_stat: player[x0] -= w1, clamped at 0        (leaf, clobbers w2)
//  add_stat: player[x0] += w1, clamped at 100      (leaf, clobbers w2, w3)
// ============================================================================
sub_stat:
        ldr     w2, [x19, x0]
        subs    w2, w2, w1
        csel    w2, w2, wzr, hs       // borrow -> 0
        str     w2, [x19, x0]
        ret

add_stat:
        ldr     w2, [x19, x0]
        add     w2, w2, w1
        mov     w3, #100
        cmp     w2, w3
        csel    w2, w2, w3, ls
        str     w2, [x19, x0]
        ret

// ============================================================================
//  print_status: loops over stat_table {label ptr, offset} and prints each
// ============================================================================
print_status:
        stp     x29, x30, [sp, #-48]!
        stp     x20, x21, [sp, #16]
        str     x22, [sp, #32]

        ldr     x0, =str_nl
        bl      print_str
        ldr     x21, =stat_table
        mov     x20, #0
.Lstat_loop:
        add     x2, x21, x20, lsl #4  // each row is 16 bytes
        ldr     x0, [x2]              // label
        ldr     x22, [x2, #8]         // offset into player struct
        bl      print_str
        ldr     w0, [x19, x22]
        bl      print_num
        add     x20, x20, #1
        cmp     x20, #STAT_COUNT
        b.lt    .Lstat_loop
        ldr     x0, =str_nl
        bl      print_str

        ldr     x22, [sp, #32]
        ldp     x20, x21, [sp, #16]
        ldp     x29, x30, [sp], #48
        ret

// ============================================================================
//  read_choice: read a line, return w0 = 1..6, or 0 if invalid.
//     Accepts the digits '1'..'6' or the letters in `keys` (h w e b s q).
//     EOF / read error returns 6 (quit).  Reads byte by byte so piped input
//     works and the rest of each typed line is discarded.
// ============================================================================
read_choice:
        mov     x0, #STDIN            // read ONE byte: the choice
        ldr     x1, =inbuf
        mov     x2, #1
        mov     x8, #SYS_READ
        svc     #0
        cmp     x0, #0
        b.gt    .Lgot_input
        mov     w0, #6                // EOF / error -> quit
        ret
.Lgot_input:
        ldr     x1, =inbuf
        ldrb    w9, [x1]              // w9 = first character typed
        cmp     w9, #10               // just pressed Enter? nothing to drain
        b.eq    .Lparse
.Ldrain:                              // throw away the rest of the line
        mov     x0, #STDIN
        ldr     x1, =inbuf
        mov     x2, #1
        mov     x8, #SYS_READ
        svc     #0
        cmp     x0, #0
        b.le    .Lparse               // EOF: stop draining
        ldr     x1, =inbuf
        ldrb    w3, [x1]
        cmp     w3, #10               // newline ends the line
        b.ne    .Ldrain
.Lparse:
        sub     w3, w9, #49           // 49 = ASCII '1'
        cmp     w3, #5
        b.hi    .Lnot_digit           // outside '1'..'6'
        add     w0, w3, #1
        ret
.Lnot_digit:
        orr     w2, w9, #0x20         // force lowercase
        ldr     x1, =keys
        mov     w0, #1
.Lkey_loop:
        ldrb    w3, [x1], #1
        cbz     w3, .Lno_key
        cmp     w3, w2
        b.eq    .Lkey_found
        add     w0, w0, #1
        b       .Lkey_loop
.Lno_key:
        mov     w0, #0
.Lkey_found:
        ret

// ============================================================================
//  print_str: x0 = NUL-terminated string            (clobbers x0-x3, x8)
// ============================================================================
print_str:
        mov     x1, x0                // buffer
        mov     x2, #0                // length
1:      ldrb    w3, [x1, x2]
        cbz     w3, 2f
        add     x2, x2, #1
        b       1b
2:      mov     x0, #STDOUT
        mov     x8, #SYS_WRITE
        svc     #0
        ret

// ============================================================================
//  print_num: w0 = unsigned number, printed in decimal (clobbers x0-x5, x8)
// ============================================================================
print_num:
        ldr     x1, =numbuf
        add     x1, x1, #11           // fill buffer from the end
        mov     x2, #0                // digit count
        mov     w4, #10
1:      udiv    w3, w0, w4
        msub    w5, w3, w4, w0        // remainder = w0 - (w0/10)*10
        add     w5, w5, #48           // 48 = ASCII '0'
        sub     x1, x1, #1
        strb    w5, [x1]
        add     x2, x2, #1
        mov     w0, w3
        cbnz    w0, 1b
        mov     x0, #STDOUT
        mov     x8, #SYS_WRITE
        svc     #0
        ret

// ============================================================================
//  TEAM STUBS - replace these with the real implementations.
//  Each stub prints a message, spends energy, and nudges one stat so the
//  main loop can be tested end to end.
//     Ethan (actions):  do_hunt, do_gather_water, do_explore, do_build_shelter
//     Maddox/RJ:        stat + inventory updates (use sub_stat / add_stat)
// ============================================================================
        .macro STUB name, msg, cost, stat, amt
\name:
        stp     x29, x30, [sp, #-16]!
        ldr     x0, =\msg
        bl      print_str
        mov     x0, #P_ENERGY
        mov     w1, #\cost
        bl      sub_stat
        mov     x0, #\stat
        mov     w1, #\amt
        bl      add_stat
        ldp     x29, x30, [sp], #16
        ret
        .endm

        STUB do_hunt,          str_hunt,   20, P_HUNGER,  30
        STUB do_gather_water,  str_water,  20, P_THIRST,  30
        STUB do_explore,       str_explore,20, P_SPEED,   0
        STUB do_build_shelter, str_build,  20, P_SHELTER, 1

// ============================================================================
        .data
        .balign 8
action_table:                         // choice 1..4 -> subroutine
        .quad do_hunt, do_gather_water, do_explore, do_build_shelter

weather_table:
        .quad str_w0, str_w1, str_w2, str_w3

end_table:                            // indexed by game state
        .quad str_quit, str_win, str_lose, str_quit

stat_table:                           // { label, offset } rows
        .quad str_lbl_health,  P_HEALTH
        .quad str_lbl_hunger,  P_HUNGER
        .quad str_lbl_thirst,  P_THIRST
        .quad str_lbl_energy,  P_ENERGY
        .quad str_lbl_shelter, P_SHELTER

keys:   .asciz "hwebsq"

str_nl:         .asciz "\n"
str_intro:      .asciz "=== SURVIVE 30 DAYS ===\nManage health, hunger, thirst and energy.\n"
str_day_hdr:    .asciz "\n=== Day "
str_day_mid:    .asciz " of 30 ===\nWeather: "
str_w0:         .asciz "Clear"
str_w1:         .asciz "Cloudy"
str_w2:         .asciz "Rainy"
str_w3:         .asciz "Stormy"
str_lbl_health: .asciz "Health: "
str_lbl_hunger: .asciz "  Hunger: "
str_lbl_thirst: .asciz "  Thirst: "
str_lbl_energy: .asciz "  Energy: "
str_lbl_shelter:.asciz "  Shelter: "
str_menu:       .asciz "\nWhat will you do?\n  [1] (h) Hunt\n  [2] (w) Gather water\n  [3] (e) Explore\n  [4] (b) Build shelter\n  [5] (s) Sleep (end the day)\n  [6] (q) Quit\n> "
str_invalid:    .asciz "That is not a valid choice.\n"
str_exhausted:  .asciz "You are exhausted. The day ends.\n"
str_night:      .asciz "\nNight falls...\n"
str_starving:   .asciz "You are starving and lose health!\n"
str_parched:    .asciz "You are dehydrated and lose health!\n"
str_storm_hit:  .asciz "The storm batters your weak shelter!\n"
str_win:        .asciz "\n*** You survived 30 days. YOU WIN! ***\n"
str_lose:       .asciz "\n*** You did not survive. GAME OVER. ***\n"
str_quit:       .asciz "\nYou gave up. Thanks for playing.\n"
str_hunt:       .asciz "[stub] You hunt for food.\n"
str_water:      .asciz "[stub] You gather water.\n"
str_explore:    .asciz "[stub] You explore the area.\n"
str_build:      .asciz "[stub] You improve your shelter.\n"

// ============================================================================
        .bss
        .balign 8
player: .skip P_SIZE
inbuf:  .skip 16
numbuf: .skip 12
