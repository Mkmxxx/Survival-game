// action for hunting
.global hunt
hunt:
    stp x19, x30, [sp, -16]!

    bl getEnergy
    mov w19, w0

    // if less than 15, performs actions at a cost
    cmp w19, 15
    b.lt hunt_low_energy

    // performs action if player has at least 15 energy
    sub w0, w19, 15
    bl setEnergy

    // gain 3 meat
    mov w0, 0
    mov w1, 2
    bl add_inventory

    mov w0, 0
    b hunt_end

hunt_low_energy:
    // depletes energy
    mov w0, 0
    bl setEnergy

    // lose 10 health
    bl getHealth
    sub w0, w0, 10
    cmp w0, 0
    b.ge hunt_health_checked
    mov w0, 0
    // error here, if health is 0 should likely end the game

// gain 1 meat if remaining health is greater than 0
hunt_health_checked:
    bl setHealth

    // gain 1 meat
    mov w0, 0
    mov w1, 1
    bl add_inventory
    mov w0, 0

hunt_end:
    ldp x19, x30, [sp], 16
    ret

// action for collecting water
.global gatherWater
gatherWater:
    stp x19, x30, [sp, -16]!

    bl getEnergy
    mov w19, w0

    cmp w19, 10
    b.lt gatherWater_low_energy

    sub w0, w19, 10
    bl setEnergy

    // add 25 water
    bl getWater
    add w0, w0, 25
    cmp w0, 100
    b.le gatherWater_limit_checked
    mov w0, 100
    b gatherWater_limit_checked

gatherWater_limit_checked:
    bl setWater

    mov w0, 0
    b gatherWater_end

gatherWater_low_energy:
    mov w0, -1
    \\ error here, this does nothing

gatherWater_end:
    ldp x19, x30, [sp], 16
    ret

// action for eating food
.global eat
eat:
    stp x19, x30, [sp, -16]!

    // eat 1 meat
    mov w0, 0
    mov w1, 1
    bl take_inventory
    cmp w0, 0
    b.eq eat_has_food

    // if no meat in inventory, eat 1 berry
    mov w0, 1
    mov w1, 1
    bl take_inventory
    cmp w0, 0
    b.lt eat_no_food

eat_has_food:
    bl getHealth
    add w0, w0, 15
    cmp w0, 100
    b.le eat_health_checked
    mov w0, 100
    b eat_health_checked

eat_health_checked:
    bl setHealth

    mov w0, 0
    b eat_end

eat_no_food:
    mov w0, -1
    // error, does nothing

eat_end:
    ldp x19, x30, [sp], 16
    ret

// action for drinking water
.global drinkWater
drinkWater:
    stp x19, x30, [sp, -16]!

    // take 1 water
    mov w0, 4
    mov w1, 1
    bl take_inventory

    cmp w0, 0
    b.lt drink_no_water

    // restore health
    bl getHealth
    add w0, w0, 10

    cmp w0, 100
    b.le drink_health_checked
    mov w0, 100
    b drink_health_checked

drink_health_checked:
    bl setHealth

    mov w0, 0
    b drink_end

drink_no_water:
    mov w0, -1
    // error, does nothing

drink_end:
    ldp x19, x30, [sp], 16
    ret

// action for exploring, gathers wood and berries
.global explore
explore:
    stp x19, x30, [sp, -16]!

    // check energy
    bl getEnergy
    mov w19, w0

    // does not perform action if not enough energy
    cmp w19, 20
    b.lt explore_low_energy

    // subtract energy
    sub w0, w19, 20
    bl setEnergy

    // collect 2 wood
    mov w0, 2
    mov w1, 2
    bl add_inventory

    // collect 2 berries
    mov w0, 1
    mov w1, 2
    bl add_inventory

    mov w0, 0
    b explore_end

explore_low_energy:
    mov w0, -1
    // error, does nothing

explore_end:
    ldp x19, x30, [sp], 16
    ret

// action for building or upgrading shelter
.global buildShelter
buildShelter:
    stp x19, x30, [sp, -16]!

    bl getEnergy
    mov w19, w0

    cmp w19, 20
    b.lt build_no_resources

    // take 10 wood
    mov w0, 2
    mov w1, 10
    bl take_inventory
    cmp w0, 0
    b.lt build_no_resources

    // subtract energy
    sub w0, w19, 20
    bl setEnergy

    // upgrade shelter
    bl getShelter
    add w0, w0, 20
    cmp w0, 100
    b.le build_shelter_limit_checked
    mov w0, 100
    b build_shelter_limit_checked

build_shelter_limit_checked:
    bl setShelter

    mov w0, 0
    b build_end

build_no_resources:
    mov w0, -1
    // error, does nothing

build_end:
    ldp x19, x30, [sp], 16
    ret

.global sleep
sleep:
    stp x19, x30, [sp, -16]!

    bl getEnergy
    mov w19, w0
    add w19,w19,20
    cmp w19, 100
    b.le sleep_checked
    mov w0, 100
    b sleep_energy

sleep_energy:
    bl setEnergy

    bl getFood
    mov w19,w0
    sub w19,w19,10
    cmp w19,0
    b.le die
    bl setFood

    bl getWater
    mov w19,w0
    sub w19,w19,10
    cmp w19,0
    b.le die
    bl setWater
    b sleep_end

sleep_end:
    ldp x19, x30, [sp], 16
    mov w0,0
    ret
