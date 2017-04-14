# NOTE: Memory segments (text, data, ...) are limited to 4MB each starting at their respective base addresses.
	
# Prerequisites for BMP format:
# 24bit/px
# 40B DIB header

# Symbol Table:
# $s7 - input, output fd's
# $s6 - BMP width				 (in pixels)
# $s5 - BMP height				 (in pixels)
# $s4 - pixel array size			 (in bytes)
# $s3 - pixel array address			 (allocated)
# $s2 - size of row	in output file		 (in bytes)
# $s1 - output buffer for 1 row			 (size = $s2)
# $s0 - 2 least significant bits of user's input (of number of 90* rotations)
#
# $t9 - size of row in input file	(in bytes)
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

fname:		.asciiz	"samples/image2.bmp"
rfname:		.asciiz "results/rest_180.bmp"
# przy wczytywaniu jako arg. uwazac na newline !!! [TODO]
	
intro:		.asciiz	"Welcome to Rotaten90 v.1.0! Let's rotate some bitmaps!"
in_f:		.asciiz "\nGimme the image fpath: "
chars:		.asciiz "\nThis many bytes: "
in_n:		.asciiz "\nNow, gimme number of nineties!: "
fed:		.asciiz "\nGiven nineties: "
ores:		.asciiz	"\nOpen returned: "
r180:		.asciiz "\nIt's a one-eighty!"
rneg90:		.asciiz "\nIt's a negative ninety!"
r90:		.asciiz "\nIt's a positive ninety!"
ok:		.asciiz	"\nDone"
emes:		.asciiz "\nExit\n"
readcom:	.asciiz "\nRead: "
wrotecom:	.asciiz "\nWrote: "
rowsize:	.asciiz "\nRowsize: "
pix_number:	.asciiz "\nPixel number: "
allocadr:	.asciiz "\nAllocated at addr: "
		.align	2
BM:		.ascii	"BM"

		.text
		.globl	main
main:		li	$v0, 4
		la	$a0, intro
		syscall
openf:		li	$v0, 13
		la	$a0, fname
		li	$a1, 0			# Open flag 0 - read
		li	$a2, 0			# mode is ignored
		syscall
		move	$s7, $v0		# file descriptor
res:		li	$v0, 4
		la	$a0, ores
		syscall
		li	$v0, 1
		move	$a0, $s7
		syscall
		blt	$s7, 0, exit		# opening file did not succeed
readf:		
	# read fileheader
		li	$v0, 14
		move	$a0, $s7
		la	$a1, fileheader
		li	$a2, 18			# fileheader size
		syscall
			# debug
			move	$t1, $v0		# number of characters read
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
	# examine fileheader
		lhu	$t0, BM($zero)		# load "BM" to compare to
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
			# _debug	
		lhu	$t1, fileheader($zero)	# load expected "BM" starting bytes
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
		bne	$t1, $t0, close		# not proper BMP format
						# branch to close because both files share the same ..
						# .. register for fd
		# load file size
		li	$t0, 2
		lw	$t1, fileheader($t0)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
		# load pixel array offset
		li	$t0, 10
		lw	$t1, fileheader($t0)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
		# load DIB header size
		li	$t0, 14
		lw	$t1, fileheader($t0)
		# [?][TODO]
		addiu	$t1, $t1, -4		# subtract 4 because first 4 bytes of DIB header are ..
						# .. stored in fileheader buffer
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
			
		# sbrk: allocate memory for DIB header <- $t1(-4) bytes [?][TODO]
		
	# read DIB header
		li	$v0, 14
		move	$a0, $s7
		la	$a1, dibheader
		li	$a2, 36
		syscall
			# debug
			move	$t0, $v0
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
			# _debug
	# examine DIB header
		# load width of the bitmap
		lw	$s6, dibheader($zero)	#[change] $s2
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s6
			syscall
			# _debug
		# load height of the bitmap
		li	$t0, 4
		lw	$s5, dibheader($t0)	#[change] $s3
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s5
			syscall
			# _debug
		# load number of bits per pixel
		li	$t0, 10
		lhu	$t1, dibheader($t0)	# [TODO] check if 24
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
		# load size of pixel array (bitmap data)
		li	$t0, 16
		lw	$s4, dibheader($t0)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s4
			syscall
			# _debug
		# the rest ...
		
		# sbrk: allocate memory for pixel array
		li	$v0, 9			# sbrk
		move	$a0, $s4		# number of bytes to allocate
		syscall
		move	$s3, $v0		# address of allocated memory
						# [change] $s5
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s3
			syscall
			# _debug
	# read pixel array		
		li	$v0, 14
		move	$a0, $s7		# pass fd
		move	$a1, $s3		# pass address of input buffer
		move	$a2, $s4		# pass maximum number of characters to read
		syscall
			# debug
			move	$t1, $v0		# number of characters read
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
	# close input file
		li	$v0, 16
		move	$a0, $s7		# fd to close
		syscall
				
input:		li	$v0, 4
		la	$a0, in_n
		syscall
		####
		li	$t0, 2
		####
			# debug
			li	$v0, 4
			la	$a0, fed
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
			# _debug
		
#write:	# open
		li	$v0, 13
		la	$a0, rfname
		li	$a1, 1			# Open flag 1 - write with create, not append
		li	$a2, 0			# mode is ignored
		syscall
		move	$s7, $v0		# file descriptor
	# open result
		li	$v0, 4
		la	$a0, ores
		syscall
		li	$v0, 1
		move	$a0, $s7
		syscall
		blt	$s7, 0, exit		# opening file did not succeed
		
chck_n:		li	$t1, 0x0003		# divisibility by 4 : 2ls bytes = 0
		and	$s0, $t0, $t1
		
	# calculate padding of rows in pixel array of input file [TODO][?][MAYBE]
		
		beq	$s0, 0, same_hdr	# write without changes [TODO]
		beq	$s0, 2, same_hdr
		#;beq	$t0, 3, rotneg
		
	# calculate new header fields for 90* and 270* rotations (they are the same)
	# swap width and height (in pixels) [TODO] -not
		move	$t0, $s6
		move	$s6, $s5
		move	$s5, $t0
	# calculate new size of row (in bytes)		
		li	$t3, 3			# bbb
		multu	$t3, $s6
		mflo	$s2			# size of row, without padding
		move	$t7, $s2	# stop condition for inner loop
		and	$t0, $s2, 0x0003	# row_size mod 4 (bytes)
		move	$t2, $zero		# [TODO][temp] padding
		beqz	$t0, qtrrot_nopad	# no padding
		li	$t1, 4
		subu	$t0, $t1, $t0		# padding (new)
		move	$t2, $t0		# [TODO][temp] padding (new)(in bytes)
		addu	$s2, $s2, $t0		# size of row (in bytes)
qtrrot_nopad:	li	$v0, 9			# allocate buffer for 1 row
		move	$a0, $s2
		syscall
		move	$s1, $v0
			# debug
			li	$v0, 4
			la	$a0, allocadr
			syscall
			li	$v0, 1
			move	$a0, $s1
			syscall
			# _debug
	# calculate new BMP data size (new pixel array size) (in bytes)
		multu	$s2, $s5
		mflo	$t0
	# store new BMP data size
		li	$t1, 16
		sw	$t0, dibheader($t1)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
			# _debug
	# store new width and height (in pixels)
		sw	$s6, dibheader($zero)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $s6
			syscall
			# _debug
		li	$t1, 4
		sw	$s5, dibheader($t1)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $s5
			syscall
			# _debug
	# calculate new BMP file size (in bytes)
		# headers have constant size: together 54 bytes
		addiu	$t0, $t0, 54
	# store new BMP file size
		li	$t1, 2
		sw	$t0, fileheader($t1)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
			# _debug
	# write headers
		#;addu	$t1, $s1, 18		#[?][TODO] : simply 54 (14+40) >?
		li	$t1, 54
		li	$v0, 15
		move	$a0, $s7		# pass fd
		la	$a1, fileheader		# pass address of output buffer
		move	$a2, $t1		# pass number of characters to write
		syscall
			# check
			move	$t1, $v0		# number of characters written
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			
	# calculate size of old rows (in bytes)
		li	$t3, 3			# bbb
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
	#rot90(pos) -- mask-and result=1
	# pixel array : 90*	
		li	$v0, 4
		la	$a0, r90
		syscall		
			# debug
			li	$v0, 4
			la	$a0, rowsize
			syscall
			li	$v0, 1
			move	$a0, $s2
			syscall
			# _debug
			
		addiu	$t1, $s5, -1	# old width-1
		li	$t3, 3			# bbb
		multu	$t1, $t3
		mflo	$t1			# last pixel in first row (old)
			# debug
			li	$v0, 4
			la	$a0, pix_number	# RELATIVE
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
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
		bltu	$t5, $t7, r90_fillbuf	# not end of output row yet
		
		# reached end of column
	# [TODO]	...			# add necessary padding (zeros)
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
			# debug
			li	$v0, 4
			la	$a0, rowsize
			syscall
			li	$v0, 1
			move	$a0, $s2
			syscall
			# _debug
				
		addiu	$t1, $s6, -1		# old height-1
		multu	$t1, $t9
		mflo	$t1			# first pixel in last row (old)
			# debug
			li	$v0, 4
			la	$a0, pix_number	# RELATIVE
			syscall
			li	$v0, 1
			move	$a0, $t1
			syscall
			# _debug
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
		bltu	$t5, $t7, r270_fillbuf	# not end of output row yet
		
		# reached end of column
	# [TODO]	...			# add necessary padding (zeros)
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
		#;addu	$t1, $s1, 18		#[?][TODO] : simply 54 (14+40) >?
		li	$t1, 54
		li	$v0, 15
		move	$a0, $s7		# pass fd
		la	$a1, fileheader		# pass address of output buffer
		move	$a2, $t1		# pass number of characters to write
		syscall
			# check
			move	$t0, $v0		# number of characters written
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall	
		beq	$s0, 2, halfrot
	# pixel array : 0*
	# write unmodified bmp data
		li	$v0, 15
		move	$a0, $s7		# pass fd
		move	$a1, $s3		# pass address of output buffer
		move	$a2, $s4		# pass number of characters to write
		syscall
			# check
			move	$t0, $v0		# number of characters written
			li	$v0, 4
			la	$a0, chars
			syscall
			li	$v0, 1
			move	$a0, $t0
			syscall
		b close			
halfrot:	
	# pixel array : 180*	
		li	$v0, 4
		la	$a0, r180
		syscall	
	# ...
		li	$t3, 3			# bbb
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
			# debug
			li	$v0, 4
			la	$a0, allocadr
			syscall
			li	$v0, 1
			move	$a0, $s1
			syscall
			# _debug	
			# debug
			li	$v0, 4
			la	$a0, rowsize
			syscall
			li	$v0, 1
			move	$a0, $s2
			syscall
			# _debug
		# NOTE: output row size = input row size
			# [TODO] In this case: row_size = pixel_arr_size / height
		addiu	$t0, $s5, -1		# from now $t0 == s18
		multu	$t0, $s2
		mflo	$t0			# start byte of last row
		addiu	$t1, $s6, -1
		li	$t3, 3			# bbb
		multu	$t1, $t3
		mflo	$t1			# byte offset to last pixel in row
		addu	$t4, $t0, $t1		# starting pos: last pixel in last row RELATIVE
			# debug
			li	$v0, 4
			la	$a0, pix_number
			syscall
			li	$v0, 1
			move	$a0, $t4
			syscall
			# _debug
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
		bltu	$t5, $t7, r180_fillbuf	# not end of output row yet
		
		# reached end of row
	# [TODO]	...			# add necessary padding (zeros)
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
		
done:		li	$v0, 4
		la	$a0, ok
		syscall
exit:		li	$v0, 4
		la	$a0, emes
		syscall
		li	$v0, 10
		syscall
