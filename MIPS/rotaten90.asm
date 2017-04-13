# NOTE: Memory segments (text, data, ...) are limited to 4MB each starting at their respective base addresses.
	.data
fname:	.asciiz	"picmono.bmp"
rfname:	.asciiz "result.bmp"
# przy wczytywaniu jako arg. uwazac na newline !!!
buf:	.space	2097152
		#10240		# 10kB
# change also in readf !!!
#2097152		# 2MB		
intro:	.asciiz	"Welcome to Rotaten90 v.1.0! Let's rotate some bitmaps!"
in_f:	.asciiz "\nGimme the image fpath: "
chars:	.asciiz "\nThis many bytes: "
in_n:	.asciiz "\nNow, gimme number of nineties!: "
fed:	.asciiz "\nGiven nineties: "
ores:	.asciiz	"\nOpen returned: "
r180:	.asciiz "\nIt's a one-eighty!"
rneg90:	.asciiz "\nIt's a negative ninety!"
r90:	.asciiz "\nIt's a positive ninety!"
ok:	.asciiz	"\nDone"
emes:	.asciiz "\nExit\n"

	.text
	.globl	main
main:	li	$v0, 4
	la	$a0, intro
	syscall
openf:	li	$v0, 13
	la	$a0, fname
	li	$a1, 0			# Open (flags are 0: read, 1: write)
	li	$a2, 0			# mode is ignored
	syscall
	move	$s7, $v0	# file descriptor
res:	li	$v0, 4
	la	$a0, ores
	syscall
	li	$v0, 1
	move	$a0, $s7
	syscall
	blt	$s7, 0, exit	# opening file did not succeed
readf:	li	$v0, 14
	move	$a0, $s7	# pass fd
	la	$a1, buf		# pass address of input buffer
	li	$a2, 2097152	# pass maximum number of characters to read
	syscall
	move	$s6, $v0	# number of characters read
	li	$v0, 4
	la	$a0, chars
	syscall
	li	$v0, 1
	move	$a0, $s6
	syscall
	
	
input:	li	$v0, 4
	la	$a0, in_n
	syscall
	####
	li	$s5, 13
	####
	li	$v0, 4
	la	$a0, fed
	syscall
	li	$v0, 1
	move	$a0, $s5
	syscall
	
zerodg:	li	$t0, 0x0003	# divisibility by 4 : 2ls bytes = 0
	and	$t0, $s5, $t0
	beq	$t0, 0, close	# write #zerodg!!!!
	beq	$t0, 2, halfrot
	beq	$t0, 3, rotneg
#rot90(pos) -- mask-and result=1
	li	$v0, 4
	la	$a0, r90
	syscall	
	# do processing
	b close
	# or branch to done
	
halfrot:li	$v0, 4
	la	$a0, r180
	syscall	
	# do processing
	b close
	
rotneg:	li	$v0, 4
	la	$a0, rneg90
	syscall	
	# do processing
	#b close
	
# process (czesc wspolna)
# end of process
	
close:	li	$v0, 16
	move	$a0, $s7	# file descriptor to close
	syscall
	
# or process here, if whole file loaded into memory
	
write:	# open
	li	$v0, 13
	la	$a0, rfname
	li	$a1, 1			# Open for write with create, not append
	li	$a2, 0			# mode is ignored
	syscall
	move	$s4, $v0	# file descriptor
	# open result
	li	$v0, 4
	la	$a0, ores
	syscall
	li	$v0, 1
	move	$a0, $s4
	syscall
	blt	$s4, 0, exit	# opening file did not succeed
	# write bitmap from memory
	li	$v0, 15
	move	$a0, $s4	# pass fd
	la	$a1, buf	# pass address of output buffer
	move	$a2, $s6	# pass number of characters to write
	syscall
	# check
	move	$t0, $v0	# number of characters written
	li	$v0, 4
	la	$a0, chars
	syscall
	li	$v0, 1
	move	$a0, $t0
	syscall
	# close
	li	$v0, 16
	move	$a0, $s4	# file descriptor to close
	syscall
	
	
done:	li	$v0, 4
	la	$a0, ok
	syscall
exit:	li	$v0, 4
	la	$a0, emes
	syscall
	li	$v0, 10
	syscall
