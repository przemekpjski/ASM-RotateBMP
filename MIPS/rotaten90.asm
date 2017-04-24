# NOTE: Memory segments (text, data, ...) are limited to 4MB each starting at their respective base addresses.
	
# Prerequisites for BMP format:
# 24bit/px
# 40B DIB header

# Symbol Table:
# $s7 - input, output fd's
# $s6 - BMP width				 			(in pixels)
# $s5 - BMP height				 			(in pixels)
# $s4 - pixel array size			 			(in bytes)
# $s3 - pixel array address			 			(allocated)
# $s2 - size of row in output file		 			(in bytes)
# $s1 - output buffer for 1 row			 			(size = $s2)
# $s0 - 2 least significant bits of user's input 			(of number of 90* rotations)
#
# $t9 - size of row in input file					(in bytes)
# $t8 - row/column counter, for outer loop iteration
# $t7 - ($s1 + $s2 - row_padding), for inner loop iteration		<- ABSOLUTE ADDR
# $t6 - starting position of pixel array traversal in inner loop	<- ABSOLUTE ADDR
# $t5 - position in output buffer for pixel storing, in inner loop	<- ABSOLUTE ADDR
# $t4 - position in pixel array during traversal, in inner loop		<- ABSOLUTE ADDR
# $t3 -	temp
# $t2 - temp
# $t1 - temp
# $t0 - temp
		
		.data
		.align	2			# or .align 2 and .space 16(+4) <- 2 first bytes zeroed
		.space	2			# for proper alignment of fileheader buffer
fileheader:	.space	18			# +4B for DIB header size
		#.align 2
dibheader:	.space	36
		.align	2
BM:		.ascii	"BM"
fname_buf:	.space	52

	
intro:		.asciiz	"Welcome to Rotaten90 v.1.0! Let's rotate some bitmaps!"
pass_in_file:	.asciiz "\nPass the input image fpath: "
pass_out_file:	.asciiz "\nPass the output image fpath: "
pass_rotations:	.asciiz	"\nPass number of rotations (n * 90deg): "
r180:		.asciiz "\nIt's a one-eighty!"
rneg90:		.asciiz "\nIt's a negative ninety!"
r90:		.asciiz "\nIt's a positive ninety!"
done_mes:	.asciiz "\nDone\n"
ferror_mes:	.asciiz	"\nProgram Rotaten90 could not open given file. Exiting.\n"

		.text
		.globl	main
main:		li	$v0, 4
		la	$a0, intro
		syscall
		
	# read input filename passed by user
		li	$v0, 4
		la	$a0, pass_in_file
		syscall
		li	$v0, 8
		la	$a0, fname_buf
		li	$a1, 52
		syscall
	  # get rid of trailing newline (if present)
		la	$t0, fname_buf		# t0 - actual position
		
loop_fname_in:	lbu	$t1, ($t0)		# t2 - actual char
		addiu	$t0, $t0, 1
		bgeu	$t1, ' ', loop_fname_in
		
		li	$t1, '\0'
		sb	$t1, -1($t0)
	
	# open input file
		li	$v0, 13
		la	$a0, fname_buf
		li	$a1, 0			# Open flag 0 - read
		li	$a2, 0			# mode is ignored
		syscall
		move	$s7, $v0		# file descriptor
		blt	$s7, 0, ferror_exit	# if opening of the file did not succeed
		
	# read fileheader
		li	$v0, 14
		move	$a0, $s7
		la	$a1, fileheader
		li	$a2, 18			# fileheader size
		syscall
	# examine fileheader
		lhu	$t0, BM($zero)		# load "BM" to compare to	
		lhu	$t1, fileheader($zero)	# load expected "BM" starting bytes
		bne	$t1, $t0, close		# not proper BMP format
						# branch to close because both files share the same register for fd
		
	# read DIB header
		li	$v0, 14
		move	$a0, $s7
		la	$a1, dibheader
		li	$a2, 36
		syscall
		
	# examine DIB header
	  # load width of the bitmap
		lw	$s6, dibheader($zero)
	  # load height of the bitmap
		li	$t0, 4
		lw	$s5, dibheader($t0)
	  # load size of pixel array (bitmap data)
		li	$t0, 16
		lw	$s4, dibheader($t0)
		
	# sbrk: allocate memory for pixel array
		li	$v0, 9			# sbrk
		move	$a0, $s4		# number of bytes to allocate
		syscall
		move	$s3, $v0
	# read pixel array		
		li	$v0, 14
		move	$a0, $s7
		move	$a1, $s3
		move	$a2, $s4
		syscall
	# close input file
		li	$v0, 16
		move	$a0, $s7
		syscall
		
	# read output filename passed by user
		li	$v0, 4
		la	$a0, pass_out_file
		syscall
		li	$v0, 8
		la	$a0, fname_buf
		li	$a1, 52
		syscall
	  # get rid of trailing newline (if present)
		la	$t0, fname_buf		# t0 - actual position
		
loop_fname_out:	lbu	$t1, ($t0)		# t2 - actual char
		addiu	$t0, $t0, 1
		bgeu	$t1, ' ', loop_fname_out
		
		li	$t1, '\0'
		sb	$t1, -1($t0)

	# open output file
		li	$v0, 13
		la	$a0, fname_buf
		li	$a1, 1			# Open flag 1 - write with create, not append
		li	$a2, 0			# mode is ignored
		syscall
		move	$s7, $v0		# file descriptor
		blt	$s7, 0, ferror_exit	# if opening of the file did not succeed
		
	# read number of rotations (n*90) passed by user
input:		li	$v0, 4
		la	$a0, pass_rotations
		syscall
		li	$v0, 5
		syscall
		move	$t0, $v0		# number of rotations
		
chck_n:		li	$t1, 0x0003		# divisibility by 4 : 2ls bytes = 0
		and	$s0, $t0, $t1
		
		beq	$s0, 0, same_hdr	# 0* -> write headers without changes
		beq	$s0, 2, same_hdr	# 180*
		
	# calculate new header fields for 90* and 270* rotations (they are the same)
	  # swap width and height (in pixels) [change]
		move	$t0, $s6
		move	$s6, $s5
		move	$s5, $t0
	  # calculate new size of row (in bytes)		
		li	$t3, 3
		multu	$t3, $s6
		mflo	$s2			# size of row, without padding
		move	$t7, $s2		# stop condition for inner loop
		and	$t0, $s2, 0x0003	# row_size mod 4 (bytes)
		move	$t2, $zero
		beqz	$t0, qtrrot_nopad	# no padding
		li	$t1, 4
		subu	$t0, $t1, $t0		# padding (new)
		move	$t2, $t0
		addu	$s2, $s2, $t0		# size of row (in bytes)
qtrrot_nopad:	li	$v0, 9			# allocate buffer for 1 row
		move	$a0, $s2
		syscall
		move	$s1, $v0
	  # calculate new BMP data size (new pixel array size) (in bytes)
		multu	$s2, $s5
		mflo	$t0
	# store new BMP data size
		li	$t1, 16
		sw	$t0, dibheader($t1)
	# store new width and height (in pixels)
		sw	$s6, dibheader($zero)
		li	$t1, 4
		sw	$s5, dibheader($t1)
	# calculate new BMP file size (in bytes)
	  # headers have constant size: together 54 bytes
		addiu	$t0, $t0, 54
	# store new BMP file size
		li	$t1, 2
		sw	$t0, fileheader($t1)
	# write headers
		li	$t1, 54
		li	$v0, 15
		move	$a0, $s7
		la	$a1, fileheader
		move	$a2, $t1
		syscall
			
	# calculate size of old rows (in bytes)
		li	$t3, 3
		multu	$t3, $s5		# mult by old width
		mflo	$t9			# size of old row, without padding
		and	$t0, $t9, 0x0003	# row_size mod 4 (bytes)
		beqz	$t0, qtrrot_nopadold	# no padding
		li	$t1, 4
		subu	$t0, $t1, $t0		# padding (old)
		addu	$t9, $t9, $t0		# size of old row (in bytes)
qtrrot_nopadold:				
		beq	$s0, 3, negqtrrot

qtrrot:	
	# rot90(pos) -- mask AND input=1
	# pixel array : 90*	
		li	$v0, 4
		la	$a0, r90
		syscall		
			
		addiu	$t1, $s5, -1		# old width-1
		li	$t3, 3
		multu	$t1, $t3
		mflo	$t1			# last pixel in first row (old)
		addu	$t4, $s3, $t1		# ABSOLUTE -- input
		move	$t6, $t4		# start pos in input				
		addu	$t5, $s1, $zero		# ABSOLUTE -- output
		addu	$t7, $s1, $t7		# stop condition for inner loop

r90_fillbuf:	lbu	$t1, 0($t4)
		sb	$t1, 0($t5)
		lbu	$t1, 1($t4)
		sb	$t1, 1($t5)
		lbu	$t1, 2($t4)
		sb	$t1, 2($t5)
		
		addu	$t4, $t4, $t9		# move on to next row (downwards)(the same column)
		addiu	$t5, $t5, 3
		bltu	$t5, $t7, r90_fillbuf	# if not end of output row yet
		
	  # write buffer to output file
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s1		# output buffer with 1 row
		move	$a2, $s2
		syscall

		addu	$t5, $s1, $zero		# reset position in buffer ABSOLUTE
		addiu	$t4, $t6, -3
		addiu	$t6, $t6, -3		#;move $t6, $t4
		bgeu	$t4, $s3, r90_fillbuf	# branch if there are more columns left to rotate			
		b close
	
negqtrrot:	
	# pixel array : 270*
		li	$v0, 4
		la	$a0, rneg90
		syscall		
				
		addiu	$t1, $s6, -1		# old height-1
		multu	$t1, $t9
		mflo	$t1			# first pixel in last row (old)
		addu	$t4, $s3, $t1		# ABSOLUTE -- input
		move	$t6, $t4		# start pos in input
				
		addu	$t5, $s1, $zero		# ABSOLUTE -- output
		addu	$t7, $s1, $t7		# stop condition for inner loop
		move	$t8, $zero		# iter var for outer loop (column counter)

r270_fillbuf:	lbu	$t1, 0($t4)
		sb	$t1, 0($t5)
		lbu	$t1, 1($t4)
		sb	$t1, 1($t5)
		lbu	$t1, 2($t4)
		sb	$t1, 2($t5)
		
		subu	$t4, $t4, $t9		# move on to next row (upwards)(the same column)
		addiu	$t5, $t5, 3
		bltu	$t5, $t7, r270_fillbuf	# if not end of output row yet
		
	  # write buffer to output file
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s1		# output buffer with 1 row
		move	$a2, $s2
		syscall

		addu	$t5, $s1, $zero		# reset position in buffer ABSOLUTE
		addiu	$t4, $t6, 3
		addiu	$t6, $t6, 3		#;move $t6, $t4	
		addiu	$t8, $t8, 1		# increment column counter
		bltu	$t8, $s5, r270_fillbuf	# branch if there are more columns left to rotate
		b close
	
same_hdr:
	# write headers
		li	$t1, 54
		li	$v0, 15
		move	$a0, $s7
		la	$a1, fileheader
		move	$a2, $t1
		syscall
		beq	$s0, 2, halfrot
		
	# pixel array : 0*
	# write unmodified bmp data
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s3
		move	$a2, $s4
		syscall
		b close			
halfrot:	
	# pixel array : 180*	
		li	$v0, 4
		la	$a0, r180
		syscall	
		
		li	$t3, 3
		multu	$t3, $s6
		mflo	$s2			# size of row, without padding
		move	$t7, $s2
		and	$t0, $s2, 0x0003	# row_size mod 4 (bytes)
		beqz	$t0, halfrot_nopad	# no padding
		li	$t1, 4
		subu	$t0, $t1, $t0		# padding
		addu	$s2, $s2, $t0		# size of row (in bytes)
halfrot_nopad:	li	$v0, 9			# allocate buffer for 1 row
		move	$a0, $s2
		syscall
		move	$s1, $v0
		
	  # NOTE: output row size = input row size
		addiu	$t0, $s5, -1
		multu	$t0, $s2
		mflo	$t0			# start byte of last row
		addiu	$t1, $s6, -1
		li	$t3, 3
		multu	$t1, $t3
		mflo	$t1			# byte offset to last pixel in row
		addu	$t4, $t0, $t1		# starting pos: last pixel in last row RELATIVE
		addu	$t4, $s3, $t4		# ABSOLUTE -- input
		move	$t6, $t4		# starting position
		addu	$t5, $s1, $zero		# ABSOLUTE -- output
		addu	$t7, $s1, $t7		# stop condition for inner loop
		move	$t8, $zero		# init row counter

	  # write bytes of current pixel to buffer
r180_fillbuf:	lbu	$t0, 0($t4)
		sb	$t0, 0($t5)
		lbu	$t0, 1($t4)
		sb	$t0, 1($t5)
		lbu	$t0, 2($t4)
		sb	$t0, 2($t5)
		addiu	$t4, $t4, -3
		addiu	$t5, $t5, 3
		bltu	$t5, $t7, r180_fillbuf	# if not end of output row yet
		
	  # write buffer to output file		
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s1		# output buffer with 1 row
		move	$a2, $s2
		syscall

		addu	$t5, $s1, $zero		# reset position in buffer ABSOLUTE
		subu	$t4, $t6, $s2		# move on to next row (upwards)
		move 	$t6, $t4	
		addiu	$t8, $t8, 1		# increment row counter
		bltu	$t8, $s5, r180_fillbuf	# branch if there are more rows left to rotate
	
close:		
	# close output file
		li	$v0, 16
		move	$a0, $s7
		syscall
		
done_exit:	li	$v0, 4
		la	$a0, done_mes
		syscall
		li	$v0, 10
		syscall
		
ferror_exit:	li	$v0, 4
		la	$a0, ferror_mes
		syscall
		li	$v0, 10
		syscall
