#!/usr/bin/env ruby

require File.join(__FILE__, '..', 'lib/tango')

t = Tango::Scope.new do
  units :us
  lead_in 5
  risefall 0.2
  #guidelines true
  time_scale 6.5
  #time_scale 0.05
  channel_offset 9
  #channel_pitch 4
  width 2800
  height 400
  ruler step: 1, major: 5, decimals: 0
  #point_size 1.5
  channel :CLK, initial: false, color: '#369'
  channel :DATA, initial: true, risefall: 0.5, font_size: 9, text_nudge: [1.5,0.3]
  channel :LATCH, initial: false, negative: true
  channel :STROBE, initial: false, negative: true
  mark
  repeat(:n, 'lines', period: 14400) do |line|
    measure('Line active time', y: -1.5, align: :all) do
      measure('CLK lead-in', y: -0.5, align: :center) do
        # CLK goes high for 9us:
        sample 0..9, CLK: true
      end
      # 8 bytes get pumped out:
      measure('Line SPI bytes loop', y: -1.0, align: :all) do
        repeat(8, 'bytes') do |byte|
          label "Start byte ##{7-byte}"
          # 8 bits per byte. NOTE: "compress: false" is a hint that, when
          # trying to render a compressed version of this timing, we DON'T
          # want this block to be subject to time compression.
          measure('Last byte (inc. trailing gap)', select: (byte==7), y: -0.5, align: :center) do
            zoom('Pushing a byte via SPI', pad: 2) do
              measure('Bit loop', y: 1.5, align: :center) do
                repeat(8, 'bits', compress: false) do |bit|
                  measure('CLK half-cycle', y: 0.5) do
                    # CLK goes low at this point, for 1us, as this bit is stabilised:
                    sample 0..1, CLK: false, DATA: "b#{63-byte*8-bit}"
                  end
                  # CLK goes high for 1us; rising edge clocks the data in:
                  sample 0..1, CLK: true
                end # Bit loop.
              end
            end
            # Hold DATA for 1us longer at the end of the byte, then raise it:
            label "End byte ##{7-byte}"
            measure('Gap between bytes', y: -0.5) do
              measure('DATA trailing time', y: 0.5) do
                sample 1, DATA: true
              end
              measure('(Prep next byte)', y: 1.5, align: :right) do
                # Pause for a further 6.75us before starting the next byte:
                step 6.75
              end
            end
          end
        end # Byte loop.
      end
      measure('CLK back porch', y: 0.5, align: :right) do
        # Wait an EXTRA 2.5us before dropping CLK low.
        sample 2.5, CLK: false
      end
      measure('Delay before LATCH', y: 1.5, align: :left) do
        # Wait 8.5us before asserting /LATCH:
        sample 8.125, LATCH: true
      end
      measure('LATCH pulse', y: 2.5, align: 2.5, align: :left) do
        # Keep it asserted for 1.875us:
        sample 1.875, LATCH: false
      end
      measure('Delay before STROBE', y: 3.5, align: :left) do
        # Wait before asserting /STROBE:
        step 2.375
      end
      label "Start heater; burn line"
      sample 0, STROBE: true
    end
    measure('STROBE asserted', y: -0.5, align: :all, units: :ms) do
      y = 0.5
      {
        CLK: 5,
        DATA: 6,
        LATCH: 7
      }.each do |ch, sam|
        untimed do
          repeat(3..35, 'test', samples: sam) do |num, pct, time|
            mark :start_timediv
            start_measure('Time-div test', y: -1.0, align: :center)
            end_measure("#{ch}-cycle")
            start_measure("#{ch}-cycle", y: y, align: :right)
            #mark
            sample 0..1, ch => false
            sample 0, ch => true
          end
          # Pad out to the end of the window:
          sample 0, ch => true
          mark :end_timediv
          end_measure('Time-div test')
        end
        y += 1
      end
      # Keep it asserted for 5.68ms, then raise it again:
      sample 5680, STROBE: false
      #sample 2, STROBE: false
    end
  end
end

#t.write_csv('example.csv')
t.write_svg('example.svg')
