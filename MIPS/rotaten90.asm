# NOTE: Memory segments (text, data, ...) are limited to 4MB each starting at their respective base addresses.
		.data
		.align	2			# or .align 2 and .space 16(+4) <- 2 first bytes zeroed
		.space	2			# for proper alignment of fileheader buffer
fileheader:	.space	18			# +4B for DIB header size
		#.align 2 ?
dibheader:	.space	36		# varies!

fname:		.asciiz	"image2.bmp"
rfname:		.asciiz "result2.bmp"
# przy wczytywaniu jako arg. uwazac na newline !!!
#buf:		.space	10240			# auxiliary buffer for writing chunks of bitmap data ..
						# .. into output file
		#10240		# 10kB
# change also in readf !!!
		#2097152	# 2MB	
	
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
		.align	2
BM:		.ascii	"BM"

# Symbol Table:
# $s7 - input file's descriptor	then output	!
# $s6 - size of pixel array (in bytes)		! = $s3 - (18 + $s1)
# $s5 - temp: how many rotations		!
# $s4 - 2 least significant bytes of input n, then output buffer
# $s3 - file size				!
# $s2 - pixel array start (offset)		!
# $s1 - DIB header size				!
# Temporary saved:
# $t9 - bitmap's width in pixels		!!
# $t8 - bitmap's height in pixels		!!
# $t7 - number of bits per pixel		<- choose path
# $t6 - address of allocated memory for pixel array


		.text
		.globl	main
main:		li	$v0, 4
		la	$a0, intro
		syscall
openf:		li	$v0, 13
		la	$a0, fname
		li	$a1, 0			# Open (flags are 0: read, 1: write)
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
		move	$t1, $v0		# number of characters read
		li	$v0, 4
		la	$a0, chars
		syscall
		li	$v0, 1
		move	$a0, $t1
		syscall
	# examine fileheader
		lhu	$t2, BM($zero)		# load "BM" to compare to
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t2
			syscall
			# _debug	
		lhu	$t3, fileheader($zero)	# load expected "BM" starting bytes
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t3
			syscall
			# _debug
		bne	$t3, $t2, close		# not proper BMP format
						# branch to close because both files share the same ..
						# .. register for fd
		# load file size
		li	$t2, 2
		lw	$s3, fileheader($t2)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s3
			syscall
			# _debug
		# load pixel array offset
		li	$t2, 10
		lw	$s2, fileheader($t2)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s2
			syscall
			# _debug
		# load DIB header size
		li	$t2, 14
		lw	$s1, fileheader($t2)
		# [?][TODO]
		addiu	$s1, $s1, -4		# subtract 4 because first 4 bytes of DIB header are ..
						# .. stored in fileheader buffer
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s1
			syscall
			# _debug
			
		# sbrk: allocate memory for DIB header <- $s1(-4) bytes
		
	# read DIB header
		li	$v0, 14
		move	$a0, $s7
		la	$a1, dibheader
		li	$a2, 36
		syscall
		move	$t1, $v0		# number of characters read
		li	$v0, 4
		la	$a0, chars
		syscall
		li	$v0, 1
		move	$a0, $t1
		syscall
	# examine DIB header
		# load width of the bitmap
		lw	$t9, dibheader($zero)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t9
			syscall
			# _debug
		# load height of the bitmap
		li	$t2, 4
		lw	$t8, dibheader($t2)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t8
			syscall
			# _debug
		# load number of bits per pixel
		li	$t2, 10
		lhu	$t7, dibheader($t2)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t7
			syscall
			# _debug
		# load size of pixel array (bitmap data)
		li	$t2, 16
		lw	$s6, dibheader($t2)
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s6
			syscall
			# _debug
		# the rest ...
		
		# sbrk: allocate memory for pixel array
		li	$v0, 9			# sbrk
		move	$a0, $s6		# number of bytes to allocate
		syscall
		move	$t6, $v0		# address of allocated memory
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $t6
			syscall
			# _debug
	# read pixel array		
		li	$v0, 14
		move	$a0, $s7		# pass fd
		move	$a1, $t6		# pass address of input buffer
		move	$a2, $s6		# pass maximum number of characters to read
		syscall
		move	$t1, $v0		# number of characters read
		li	$v0, 4
		la	$a0, chars
		syscall
		li	$v0, 1
		move	$a0, $t1
		syscall
	# close input file
		li	$v0, 16
		move	$a0, $s7		# fd to close
		syscall
				
input:		li	$v0, 4
		la	$a0, in_n
		syscall
		####
		li	$s5, -1
		####
		li	$v0, 4
		la	$a0, fed
		syscall
		li	$v0, 1
		move	$a0, $s5
		syscall
		
write:	# open
		li	$v0, 13
		la	$a0, rfname
		li	$a1, 1			# Open for write with create, not append
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
		
chck_n:		li	$t0, 0x0003		# divisibility by 4 : 2ls bytes = 0
		and	$s4, $s5, $t0
		beq	$s4, 0, same_hdr	# write without changes [TODO]
		beq	$s4, 2, same_hdr
		#beq	$t0, 3, rotneg
		
	# calculate new header fields for 90* and 270* rotations (they are the same)
	# swap width and height (in pixels)
		move	$t0, $t9
		move	$t9, $t8
		move	$t8, $t0
	# calculate new size of row (in bytes)
		# prerequisite: 24bit/px
		# $t9 - new width in pixels
		# $t8 - new height in pixels
		# $t7 - bits/px
		# $t6 - input pixel array
		srl	$t2, $t7, 3		# bytes/px (divide by 8)
		multu	$t2, $t9
		mflo	$t3			# size of row, without padding
		and	$t5, $t3, 0x0003	# row_size mod 4 (bytes)
		move	$t7, $zero		# [TODO][temp] padding
		beqz	$t5, qtrrot_nopad	# no padding
		li	$t4, 4
		subu	$t5, $t4, $t5		# padding
		move	$t7, $t5		# [TODO][temp] padding
		addu	$t3, $t3, $t5		# size of row (in bytes)
qtrrot_nopad:	#li	$v0, 9			# allocate buffer for 1 row
		#move	$a0, $t3
		#syscall
		#move	$s4, $v0
			# debug
			#li	$v0, 4
			#la	$a0, readcom
			#syscall
			#li	$v0, 1
			#move	$a0, $s4
			#syscall
			# _debug
	# calculate new BMP data size (new pixel array size) (in bytes)
		# $t3 - size of row (in bytes)
		multu	$t3, $t8
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
		sw	$t9, dibheader($zero)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $t9
			syscall
			# _debug
		li	$t1, 4
		sw	$t8, dibheader($t1)
			# debug
			li	$v0, 4
			la	$a0, wrotecom
			syscall
			li	$v0, 1
			move	$a0, $t8
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
		addu	$t1, $s1, 18		#[?][TODO] : simply 54 (14+40) >?
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
		beq	$s4, 3, negqtrrot	
qtrrot:	
	#rot90(pos) -- mask-and result=1
	# pixel array : 90*	
		li	$v0, 4
		la	$a0, r90
		syscall		
#post qtrrot_nopad:
		# NOTE: for now it's just a copy of halfrot algorithm !!
		# $t3 - size of row (in bytes)
		# $t2 - bytes/px
		# $s4 - output buffer (for 1 row)
			# debug
			li	$v0, 4
			la	$a0, rowsize
			syscall
			li	$v0, 1
			move	$a0, $t3
			syscall
			# _debug
		addiu	$t0, $t8, -1
		multu	$t0, $t3
		mflo	$t0			# start byte of last row
		addiu	$t1, $t9, -1
		multu	$t1, $t2
		mflo	$t1			# byte offset to last pixel in row
		addu	$t4, $t0, $t1
		# $t4 - current position (byte)	in pixel array
			# debug
			li	$v0, 4
			la	$a0, pix_number
			syscall
			li	$v0, 1
			move	$a0, $t4
			syscall
			# _debug
		addu	$t4, $t6, $t4		# ABSOLUTE	-- input
			# move	$t5, $zero	
		addu	$t5, $s4, $zero		# ABSOLUTE	-- output
		# $t5 - current position (byte) in output buffer ABSOLUTE
		addu	$t0, $t6, $t0
		# $t0 - start byte of current row ABSOLUTE
		# write 2ms bytes of pixel to buffer
r90_fillbuf:	lbu	$t1, 0($t4)
		sb	$t1, 0($t5)
		lbu	$t1, 1($t4)
		sb	$t1, 1($t5)
		lbu	$t1, 2($t4)
		sb	$t1, 2($t5)
		addiu	$t4, $t4, -3
		addiu	$t5, $t5, +3
		bgeu	$t4, $t0, r90_fillbuf	# not end of row yet
		# reached end of row
	# [TODO]	...			# add necessary padding (zeros)
		# write buffer to output file
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s4		# output buffer with 1 row
		move	$a2, $t3
		syscall
			# check
			#move	$v1, $v0	# number of characters written
			#li	$v0, 4
			#la	$a0, chars
			#syscall
			#li	$v0, 1
			#move	$a0, $v1
			#syscall
		# $t7 - padding (in bytes)
		# move to next row (upwards)
		subu	$t0, $t0, $t3		# start byte of the next row
		addu	$t5, $s4, $zero		# reset position in buffer ABSOLUTE
		subu	$t4, $t4, $t7
		subu	$t4, $t4, $t2		# set position in pixel array to next pixel to load
		bgeu	$t0, $t6, r90_fillbuf	# branch if there are more rows left to rotate			
		b close
	# or branch to done
negqtrrot:	
	# pixel array : 270*
		li	$v0, 4
		la	$a0, rneg90
		syscall	
		
		b close
	
same_hdr:
	# write headers
		addu	$t1, $s1, 18		#[?][TODO] : simply 54 (14+40) >?
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
		beq	$s4, 2, halfrot
	# pixel array : 0*
	# write unmodified bmp data
		li	$v0, 15
		move	$a0, $s7		# pass fd
		move	$a1, $t6		# pass address of output buffer
		move	$a2, $s6		# pass number of characters to write
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
	# write pixels in loop
		# prerequisite: 24bit/px
		# $t9 - width in pixels
		# $t8 - height in pixels
		# $t7 - bits/px
		# $t6 - input pixel array
		srl	$t2, $t7, 3		# bytes/px (divide by 8)
		multu	$t2, $t9
		mflo	$t3			# size of row, without padding
		and	$t5, $t3, 0x0003	# row_size mod 4 (bytes)
		move	$t7, $zero		# [TODO][temp] padding
		beqz	$t5, halfrot_nopad	# no padding
		li	$t4, 4
		subu	$t5, $t4, $t5		# padding
		move	$t7, $t5		# [TODO][temp] padding
		addu	$t3, $t3, $t5		# size of row (in bytes)
halfrot_nopad:	li	$v0, 9			# allocate buffer for 1 row
		move	$a0, $t3
		syscall
		move	$s4, $v0
			# debug
			li	$v0, 4
			la	$a0, readcom
			syscall
			li	$v0, 1
			move	$a0, $s4
			syscall
			# _debug	
		# $t3 - size of row (in bytes)
		# $t2 - bytes/px
		# $s4 - output buffer (for 1 row)
			# debug
			li	$v0, 4
			la	$a0, rowsize
			syscall
			li	$v0, 1
			move	$a0, $t3
			syscall
			# _debug
		addiu	$t0, $t8, -1
		multu	$t0, $t3
		mflo	$t0			# start byte of last row
		addiu	$t1, $t9, -1
		multu	$t1, $t2
		mflo	$t1			# byte offset to last pixel in row
		addu	$t4, $t0, $t1
		# $t4 - current position (byte)	in pixel array
			# debug
			li	$v0, 4
			la	$a0, pix_number
			syscall
			li	$v0, 1
			move	$a0, $t4
			syscall
			# _debug
		addu	$t4, $t6, $t4		# ABSOLUTE	-- input
			# move	$t5, $zero	
		addu	$t5, $s4, $zero		# ABSOLUTE	-- output
		# $t5 - current position (byte) in output buffer ABSOLUTE
		addu	$t0, $t6, $t0
		# $t0 - start byte of current row ABSOLUTE
		# write 2ms bytes of pixel to buffer
r180_fillbuf:	lbu	$t1, 0($t4)
		sb	$t1, 0($t5)
		lbu	$t1, 1($t4)
		sb	$t1, 1($t5)
		lbu	$t1, 2($t4)
		sb	$t1, 2($t5)
		addiu	$t4, $t4, -3
		addiu	$t5, $t5, +3
		bgeu	$t4, $t0, r180_fillbuf	# not end of row yet
		# reached end of row
	# [TODO]	...			# add necessary padding (zeros)
		# write buffer to output file
		li	$v0, 15
		move	$a0, $s7
		move	$a1, $s4		# output buffer with 1 row
		move	$a2, $t3
		syscall
			# check
			#move	$v1, $v0	# number of characters written
			#li	$v0, 4
			#la	$a0, chars
			#syscall
			#li	$v0, 1
			#move	$a0, $v1
			#syscall
		# $t7 - padding (in bytes)
		# move to next row (upwards)
		subu	$t0, $t0, $t3		# start byte of the next row
		addu	$t5, $s4, $zero		# reset position in buffer ABSOLUTE
		subu	$t4, $t4, $t7
		subu	$t4, $t4, $t2		# set position in pixel array to next pixel to load
		bgeu	$t0, $t6, r180_fillbuf	# branch if there are more rows left to rotate			
		b close
	
rotneg:		li	$v0, 4
		la	$a0, rneg90
		syscall	
	# do processing
		#b close
	
# process (common part)
# end of process
	
close:		
	# close output file
		li	$v0, 16
		move	$a0, $s7		# fd to close
		syscall
		
done:		li	$v0, 4
		la	$a0, ok
		syscall
exit:		li	$v0, 4
		la	$a0, emes
		syscall
		li	$v0, 10
		syscall
