.data
.balign 4

// global variables for all stats

.global health
.global food
.global water
.global shelter
.global energy
.global strength
.global speed

health: .word 100
food: .word 100
water: .word 100
shelter: .word 0
energy: .word 100
strength: .word 100
speed: .word 100

healthString: .string "Health is %d"
foodString: .string "Food is %d"
waterString: .string "Water is %d"
shelterString: .string "Shelter is %d"
energyString: .string "Energy is %d"
strengthString: .string "Strength is %d"
speedString: .string "Speed is %d"


.text
.global getHealth
.global setHealth
.global getFood
.global setFood
.global getWater
.global setWater
.global getShelter
.global setShelter
.global getEnergy
.global setEnergy
.global getStrength
.global setStrength
.global getSpeed
.global setSpeed

.global printHealth
.global printFood
.global printWater
.global printShelter
.global printEnergy
.global printStrength
.global printSpeed
// getters and setters for global variables

getHealth:
ldr x1,=health
ldr w0,[x1]
ret

setHealth:
ldr x1, =health
str w0,[x1]
ret

getFood:
ldr x1,=food
ldr w0,[x1]
ret

setFood:
ldr x1, =food
str w0,[x1]
ret

getWater:
ldr x1,=water
ldr w0,[x1]
ret

setWater:
ldr x1, =water
str w0,[x1]
ret

getShelter:
ldr x1,=shelter
ldr w0,[x1]
ret

setShelter:
ldr x1, =shelter
str w0,[x1]
ret

getEnergy:
ldr x1,=energy
ldr w0,[x1]
ret

setEnergy:
ldr x1, =energy
str w0,[x1]
ret

getStrength:
ldr x1,=strength
ldr w0,[x1]
ret

setStrength:
ldr x1, =strength
str w0,[x1]
ret

getSpeed:
ldr x1,=speed
ldr w0,[x1]
ret

setSpeed:
ldr x1, =speed
str w0,[x1]
ret

// print the variables

printHealth:
bl getHealth
mov w1,w0
ldr x0,=healthString
bl printf
mov w0,0
ret

printFood:
bl getFood
mov w1,w0
ldr x0,=foodString
bl printf
mov w0,0
ret

printWater:
bl getWater
mov w1,w0
ldr x0,=waterString
bl printf
mov w0,0
ret

printShelter:
bl getShelter
mov w1,w0
ldr x0,=shelterString
bl printf
mov w0,0
ret

printEnergy:
bl getEnergy
mov w1,w0
ldr x0,=energyString
bl printf
mov w0,0
ret

printStrength:
bl getStrength
mov w1,w0
ldr x0,=strengthString
bl printf
mov w0,0
ret

printSpeed:
bl getSpeed
mov w1,w0
ldr x0,=speedString
bl printf
mov w0,0
ret
