//myfir.S
.global myfir_m
//a0=x[n]
//a1=c[]
//a2=y[]
//a3=n
//a4=m

//s2=j
//t0=sum
//s1=i

//making room on stack for a1,a2
myfir_m:
addi sp, sp, -16
sd s1, 0(sp)
sd s2, 8(sp)

li s1, 0 //i=0
li s2, 0 //j=0

//prep for outer loop
sub t5, a3, a4 //t0=n-m
li s2, 0 //j=0

//outer for loop
outer:
bgt s2, t5, done //if j>n-m branch
li t0, 0 //sum=0

//prep for inner loop
li s1, 0//i=0
addi t6, a4, -1 //t6=m-1

//inner for loop
inner:
bgt s1, t6, idone //if i>m-1 branch
slli t1, t6, 2 //t1=i*4
add t1, t1, a1 //addess of c[i]
lw t1, 0(t1) // t1=c[i]
sub t2, s2, s1 //t2=j-i
add t2, t2, t6 //t2=j-i+m-1
//multiply result in t3
slli t3, t2, 2 //t1=(j-1+m-1)*4
add t3, t3, a0 //addess of x[j-1+m-1]
lw t3, 0(t3) // t1=x[j-1+m-1]
mul t3, t3, t1 //t3=c[i]*x[j-1+m-1]
slli t3, t3, 1 // shifts 64 bit product left by 1 bit
srli t3, t3, 32 // shifts 64 bit product right by 32 bits
add t0,t0,t3 //sum+=c[i]*x[j-1+m-1]
addi s1, s1, 1 //i=i+1
j inner

idone:
slli t3, s2, 2 //t3=j*4
add t3, t3, a2 //addess of y[j]
sw t0, 0(t3) // t3=x[j-1+m-1]
addi s2, s2, 1 //i=i+1
j outer
done:
mv a0, a2 //store address of y[0] in a0 for result
ld s1, 0(sp)
ld s2, 8(sp)
addi sp, sp, 16
ret
