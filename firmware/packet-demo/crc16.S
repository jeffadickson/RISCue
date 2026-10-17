/* CRC-16/IBM-3740 (CCITT-FALSE): poly 0x1021, caller seed,
 * no reflection or final XOR. a0=bytes, a1=length, a2=seed; returns a0.
 * Uses standard Zbb zext.h and Zbs bexti. No custom opcode or SMC. */
.text
.globl crc16_packet
.type crc16_packet,@function
crc16_packet:
    zext.h t0,a2
    li t1,0x1021
    beqz a1,.Ldone
.Lbyte:
    lbu t2,0(a0)
    slli t2,t2,8
    xor t0,t0,t2
    li t3,8
.Lbit:
    bexti t4,t0,15
    slli t0,t0,1
    neg t4,t4
    and t4,t4,t1
    xor t0,t0,t4
    zext.h t0,t0
    addi t3,t3,-1
    bnez t3,.Lbit
    addi a0,a0,1
    addi a1,a1,-1
    bnez a1,.Lbyte
.Ldone:
    mv a0,t0
    ret
.size crc16_packet,.-crc16_packet
