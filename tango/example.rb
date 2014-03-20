#!/usr/bin/env ruby

require File.join(__FILE__, '..', 'lib/tango')

t = Tango::Scope.new do
  units :us
  lead_in 5
  risefall 0.1
  #guidelines true
  time_scale 6
  width 2250
  height 350
  ruler step: 1, major: 5, decimals: 0
  channel :CLK, initial: false, color: '#369'
  channel :DATA, initial: true, font_size: 9
  channel :LATCH, initial: false, negative: true
  channel :STROBE, initial: false, negative: true
  repeat(:n, 'lines', period: 14400) do |line|
    measure('line active time') do
      # CLK goes high for 9us:
      sample 0..9, CLK: true
      # 8 bytes get pumped out:
      measure('byte loop') do
        repeat(8, 'bytes') do |byte|
          label "Start byte #{7-byte}"
          # 8 bits per byte. NOTE: "compress: false" is a hint that, when
          # trying to render a compressed version of this timing, we DON'T
          # want this block to be subject to time compression.
          measure('bit loop') do
            repeat(8, 'bits', compress: false) do |bit|
              # CLK goes low at this point, for 1us, as this bit is stabilised:
              sample 0..1, CLK: false, DATA: "b#{63-byte*8-bit}"
              # CLK goes high for 1us; rising edge clocks the data in:
              sample 0..1, CLK: true
            end # Bit loop.
          end
          # Hold DATA for 1us longer at the end of the byte, then raise it:
          sample 1, DATA: true
          # Pause for a further 6.75us before starting the next byte:
          step 6.75
        end # Byte loop.
      end
      # Wait an EXTRA 2.5us before dropping CLK low.
      sample 2.5, CLK: false
      # Wait 8.5us before asserting /LATCH:
      sample 8.125, LATCH: true
      # Keep it asserted for 1.875us:
      sample 1.875, LATCH: false
      # Wait for 11us before asserting /STROBE:
      step 2.375
      label "Start heater; burn line"
      sample 0, STROBE: true
    end
    # Keep it asserted for 5.68ms, then raise it again:
    sample 5680, STROBE: false
  end
end

#t.write_csv('example.csv')
t.write_svg('example.svg')
