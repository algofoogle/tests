#!/usr/bin/env ruby

require 'chunky_png'

pad_to_512_tiles = false
color_map_line = nil
arg_errors = []

args = ARGV.dup
bare_args = []
until args.empty?
	arg = args.shift
	if '-' == arg[0,1]
		case arg
		when '-8'
			pad_to_512_tiles = true
		when '-m'
			# The last line of the source PNG contains the 'colour map', where
			# pixels X(0..3) of that line define which RGB colours (used in the rest of the image)
			# map to which NES pixel values 0..3. The pixel in X(4) defines the default NES pixel
			# value to use for all other undefined colours encountered, as follows:
			# #FF0000 (red)   => Use 1
			# #00FF00 (green) => Use 2
			# #0000FF (blue)  => Use 3
			# Everything else => Use 0
			color_map_line = -1
		else
			arg_errors << "Unknown switch: #{arg}"
		end
	else
		bare_args << arg
	end
end
bac = bare_args.count
arg_errors << "Too many arguments (expected 2, got #{bac})" if bac > 2
arg_errors << "Not enough arguments (expected 2, got #{bac})" if bac < 2
unless arg_errors.empty?
	puts <<-EOH

ERROR: BAD COMMAND LINE:
  * #{arg_errors.join("\n  * ")}

---
Usage: #{$0} [-8] [-m] sourceimage.png targetrom.bin
Where:
  -8               = Pad the file out to 8KiB (i.e. add 256 extra blank tiles, to make up the standard CHR-ROM size).
  -m               = The last line of the source PNG defines the 'colour map'.
  sourceimage.png  = Source PNG file, 128x128 pixels.
  targetrom.bin    = CHR-ROM binary file to write; will be 4KiB or 8KiB depending on -8 switch.

EOH
	exit 1
end

source_image, target_rom = bare_args

puts "Source file: #{source_image}"

src = ChunkyPNG::Image.from_file(source_image)

# Get the palette as an array of unique colours:
colors = src.palette.to_a
hex = colors.map{ |c| ChunkyPNG::Color.to_hex(c, false) }
puts "Colours used in the source image:"
puts hex.inspect

if color_map_line == -1
	# Use the last line:
	line = src.height + color_map_line
	case ChunkyPNG::Color.to_hex(src[4,line], false).upcase
	when '#FF0000'
		d = 1
	when '#00FF00'
		d = 2
	when '#0000FF'
		d = 3
	else
		d = 0
	end
	DEFAULT_COLOR_MAPPING = d
	COLOR_MAP = {
		src[0, line] => 0,
		src[1, line] => 1,
		src[2, line] => 2,
		src[3, line] => 3,
	}
else
	DEFAULT_COLOR_MAPPING = 0
	COLOR_MAP = Hash[{
		'#ffffff' => 0,
		'#c0c0c0' => 1,
		'#808080' => 2,
		'#000000' => 3,
	}.map { |k,v| [ChunkyPNG::Color.from_hex(k), v] }]
end
puts "Colour map:"
COLOR_MAP.each do |k,v|
	puts "  #{ChunkyPNG::Color.to_hex(k,false)} => #{v}"
end
puts "  Default:   #{DEFAULT_COLOR_MAPPING}"

class NesChar
	@@dots = { 0 => ' ', 1 => '.', 2 => ':', 3 => '#' }
	def [](a, b = nil)
		@pixels[pixel_index(a,b)]
	end
	def []=(x, y, c)
		@pixels[pixel_index(x,y)] = c
	end
	def pixels
		@pixels
	end
	def initialize(*args)
		options = args.last.is_a?(Hash) ? args.pop : {}
		src = args.first
		# There are 64 pixels in the 8x8 tile, but note that each pixel is 4 bits => 16 bytes per tile:
		@pixels = [0] * 64
		case src
		when ChunkyPNG::Image
			tx = (options[:tile_x] || 0) << 3
			ty = (options[:tile_y] || 0) << 3
			8.times.each do |x|
				8.times.each do |y|
					self[x,y] = src[tx+x, ty+y]
				end
			end
		end
	end
	def ascii_render(wide = true)
		d = wide ? 2 : 1
		out = ''
		8.times.each do |y|
			out << self[y].map{ |c| (@@dots[c] || 'X') * d }.join << "\n"
		end
		out
	end
	def map_colors!(the_map)
		@pixels.map!{ |p| COLOR_MAP[p] || DEFAULT_COLOR_MAPPING }
	end
	# Convert raw pixel data into a binary stream.
	def bin
		# Note that the CHR-ROM binary format is arranged as two bit planes of 8 bytes each,
		# where the first plane is the LSBs of each pixel, and the 2nd plane is the MSBs.
		# In other words, the data stream is as follows:
		# * 8 bytes; each byte, with each bit (in order of MSB to LSB) representing the LSB
		#   of each pixel, from left-to-right, starting with the 1st byte for the top row,
		#   and the 8th byte for the bottom row.
		# * 8 bytes again, this time with each bit representing the MSB (2nd bit) of each pixel.
		#NOTE: This is possibly NOT the most efficient way to do this:
		lsb_plane = @pixels.map{ |b| b & 1}  # Get the LSBs of each pixel.
		msb_plane = @pixels.map{ |b| (b>>1) & 1 } # Get the MSBs.
		# Convert the planes into one long joined binary string:
		[(lsb_plane + msb_plane).join].pack('B*')
	end
	# Express the char's raw binary stream as an array of bytes.
	def bytes
		bin.unpack('C*')
	end
private
	def pixel_index(a, b = nil)
		if b
			# Get a pixel, X by Y:
			a + (b*8)
		else
			# Get a line of pixels, by Y:
			b = (a*8)
			b..(b+7)
		end
	end
end

class NesCharRom
	def initialize
		@chars = [nil] * 16 * 16
		@counter = 0
	end
	def <<(char)
		raise 'Character ROM is full' if @counter >= 256
		@chars[@counter] = char
		@counter += 1
		char
	end
	def seek(index)
		@counter = index
	end
	def [](index)
		c = index.is_a?(String) ? index.ord : index
		@chars[c]
	end
	def inspect
		n = -1
		'[' + @chars.map{ |c| n+=1; c ? n : -1 }.join(', ') + ']'
	end
	def ascii_render(msg, wide = true)
		chars = msg.split('').map{|c| self[c].ascii_render(wide).split("\n")}
		chars.shift.zip(*chars).map{ |row| row.join('')}
	end
	def bin(pad_to_512 = false)
		empty_char_bin = "\x00" * 16
		extra = pad_to_512 ? empty_char_bin * 256 : ''
		@chars.map{ |c| c ? c.bin : empty_char_bin }.join + extra
	end
end

chars = NesCharRom.new

# Break the image up into 8x8 chunks:
16.times.each do |ty|
	16.times.each do |tx|
		print '.'; STDOUT.flush
		c = NesChar.new(src, :tile_x => tx, :tile_y => ty)
		c.map_colors!(COLOR_MAP)
		chars << c
	end
end

File.open(target_rom, 'wb') do |f|
	f.write chars.bin(pad_to_512_tiles)
end
