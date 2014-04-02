#!/usr/bin/env ruby

require File.join(__FILE__, '..', 'lib/tango')

def common
  measurement_ai_fix true # Fix for Adobe Illustrator handling of SVG files.
  inkscape_text_fix true # Fix for Inkscape, where it doesn't support '1em' units for multi-line text.
  units :us
  lead_in 4
  risefall 0.2
  time_scale 5.5
  time_fold_width 1.0
  time_fold_overlap 0.5
  time_offset 30
  channel_offset 9
  fade_out 100
  width 960
  height 280
  show_label_times false
  ruler step: 1, major: 5, decimals: 0
  channel :CLK, initial: false, color: '#3a0', subtext: '(Pin 3)'
  channel :DATA, initial: true, color: '#00f', subtext: '(Pin 2)', risefall: 0.5, font_size: 9, text_nudge: [2,0.3]
  channel_name_nudge [2,0]
end

# This creates a yellow-backgrounded image with a zig-zag "rip"-style time fold:
def yellow_with_rip
  common
  background_color '#ffe'
  fold_type type: :saw2, gap_color: '#eec', teeth: 8, gap_width: 15, gap_corner: 'miter'
  style(
    measures: { stroke: '#999', stroke_width: 0.4 },
    label_lines: { stroke: 'cyan', stroke_width: 0.5, stroke_dasharray: '5,5' },
    waveform_base: { stroke_width: 1.5 },
    fold_band: { stroke: 'none', fill: background_color },
    fold_edge: { stroke_dasharray: nil, fill: 'none', stroke: '#fff', stroke_width: 12, stroke_linecap: 'round' }
  )
end

# This creates a more plain white-background image with a grey zig-zag time fold:
def white_with_zigzag
  common
  fold_type type: :saw2, gap_color: '#eee', teeth: 10
  style(
    measures: { stroke: '#999', stroke_width: 0.4 },
    label_lines: { stroke: 'cyan', stroke_width: 0.5, stroke_dasharray: '5,5' },
    waveform_base: { stroke_width: 1.5 },
    fold_edge: { stroke_dasharray: nil, fill: 'none', stroke: '#aaa', stroke_width: 4, stroke_linecap: 'round' }
  )
end



t = Tango::Scope.new do
  yellow_with_rip
  repeat(2, 'Main Cycle', period: 14400) do |line|
    mark :cycle_start, hide: true
    label("START\nCYCLE ##{line+1}")
    end_measure('Inactive time')
    end_measure('Main Cycle')
    start_measure('Main Cycle', y: -1.5, align: %w(left right), units: :ms)
    measure('Total active time', y: -1.0, align: :left) do
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
        measure('Last bit extra hold time', y: 0.5, outer: true) do
          sample 1, DATA: true
        end
        step 6.75
        end_measure('CLK high between bytes')
      end
      mark_seek :loop_end, 11.25
      sample 0, CLK: false
      end_measure('CLK "back porch"')
    end # Measure: Total active time.
    start_measure('Inactive time', y: 0.5, align: :left, override: '~ 14.2ms')
    step 7
    fold :bit_loop_begin
    mark_seek :cycle_start, 14396 # Seek to 4us before the end of this cycle.
    fold :bit_loop_end
  end
end

f = 'pt1010-CLK-DATA.svg'
puts f
t.write_svg(f, fold: (:bit_loop_begin..:bit_loop_end))


# Adding in pin 4:
t = Tango::Scope.new do
  yellow_with_rip
  fold_type type: :saw2, gap_color: '#eec', teeth: 10, gap_width: 15, gap_corner: 'miter'
  height 330
  channel :P4, initial: false, color: '#f90', subtext: '(Pin 4)', negative: true
  repeat(2, 'Main Cycle', period: 14400) do |line|
    mark :cycle_start, hide: true
    label("START\nCYCLE ##{line+1}")
    end_measure('Inactive time')
    end_measure('Main Cycle')
    start_measure('Main Cycle', y: -1.5, align: %w(left right), units: :ms)
    measure('Total CLK activity', y: -1.0, align: :left) do
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
            elsif bit==2 && byte==7
              fold :bit_loop_end
            end
            sample 0..1, CLK: true
          end
        end
        label 'End byte 0' if byte==7
        measure('Last bit extra hold time', y: 0.5, outer: true) do
          sample 1, DATA: true
        end
        step 6.75
        end_measure('CLK high between bytes')
      end
      mark_seek :loop_end, 11.25
      sample 0, CLK: false
      end_measure('CLK "back porch"')
    end # Measure: Total active time.
    measure('Gap before pin 4 pulse', y: 0.5) do
      sample 8.125, P4: true
    end
    measure('Pin 4 pulse width', y: 1.5) do
      sample 1.875, P4: false
    end
    start_measure('Inactive time', y: -0.5, align: :left, override: '~ 14.2ms')
    step 6
    fold :bit_loop_begin
    mark_seek :cycle_start, 14397 # Seek to 4us before the end of this cycle.
    fold :bit_loop_end
  end
end

f = 'pt1010-LATCH.svg'
puts f
t.write_svg(f, fold: (:bit_loop_begin..:bit_loop_end))
