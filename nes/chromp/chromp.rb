#!/usr/bin/env ruby

require 'chunky_png'

raise "Usage: #{$0} sourcefile.png" unless ARGV.count == 1

puts "Source file: #{ARGV.first}"

src = ChunkyPNG::Image.from_file(ARGV.first)

# Get the palette as an array of unique colours:
colors = src.palette.to_a
hex = colors.map{ |c| ChunkyPNG::Color.to_hex(c, false) }
puts "Colours used in the source image:"
puts hex.inspect

COLOR_MAP = Hash[{
	'#ffffff' => 0,
	'#ffff00' => 0,
	'#fffbf0' => 0,
	'#c0c0c0' => 1,
	'#808080' => 2,
	'#000000' => 3,
}.map { |k,v| [ChunkyPNG::Color.from_hex(k), v] }]

puts COLOR_MAP.inspect

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
		@pixels.map!{ |p| COLOR_MAP[p] || -1 }
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

puts

puts chars.inspect

puts chars.ascii_render("The Quick Brown Fox Jumps Over The Lazy Dog")