#!/usr/bin/env ruby

require File.join(__FILE__, '..', 'lib/tango')

def defaults
  measurement_ai_fix true # Fix for Adobe Illustrator handling of SVG files.
  inkscape_text_fix true # Fix for Inkscape, where it doesn't support '1em' units for multi-line text.
  units :us
  lead_in 5
  risefall 0.2
  time_scale 5.5
  time_fold_width 2.0
  time_fold_overlap 1.0
  channel_offset 9
  width 2800
  height 400
  show_label_times false
  style(
    measures: { stroke: '#999', stroke_width: 0.4 },
    label_lines: { stroke: 'cyan', stroke_width: 0.5, stroke_dasharray: '5,5' },
    waveform_base: { stroke_width: 1.2 },
  )
  #ruler step: 1, major: 5, decimals: 0
  channel :CLK, initial: false, color: '#f80', subtext: '(Pin 3)'
  channel :DATA, initial: true, color: '#00f', subtext: '(Pin 2)', risefall: 0.5, font_size: 9, text_nudge: [2,0.3]
end

t = Tango::Scope.new do
  defaults
  repeat(2, 'Main Cycle', period: 14400) do |line|
    mark :cycle_start, hide: true
    label("START CYCLE #{line+1}")
    end_measure('Main Cycle')
    start_measure('Main Cycle', y: -1.5, align: :all, units: :ms) #override: '14.4ms')
    measure('Total active time', y: -1.0, align: :all) do
      measure('CLK "front porch"', y: -0.5) do
        sample 0..9, CLK: true
      end
      repeat(8, 'Bytes Loop') do |byte|
        label "Byte #{7-byte}"
        repeat(8, 'Bit Loop') do |bit|
          measure('CLK cycle', y: 0.5) do
            sample 0..1, CLK: false, DATA: "#{63-byte*8-bit}"
            start_measure('CLK high between bytes', y: -0.5) if bit==7
            if bit==7 && byte==7
              start_measure('CLK "back porch"', y: -0.5)
              mark :loop_end, hide: true
            elsif bit==2 && byte==1
              fold :bit_loop_begin
            elsif bit==6 && byte==6
              fold :bit_loop_end
            end
            sample 0..1, CLK: true
          end
        end
        measure('Last bit extra hold time', y: 0.5) do
          sample 1, DATA: true
        end
        step 6.75
        end_measure('CLK high between bytes')
      end
      mark_seek :loop_end, 11.25
      sample 0, CLK: false
      end_measure('CLK "back porch"')
    end # Measure: Total active time.
    step 3
    fold :bit_loop_begin
    mark_seek :cycle_start, 14397 # Seek to 3us before the end of this cycle.
    fold :bit_loop_end
  end
end

t.write_svg('pt1010-CLK-DATA.svg', fold: (:bit_loop_begin..:bit_loop_end))



