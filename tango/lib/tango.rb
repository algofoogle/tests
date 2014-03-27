require 'rasem'

# Monkey-patch Rasem::SVGImage so we can add a <defs> block:
class Rasem::SVGImage
  def add_defs(measure_color = 'magenta')
    # Start a <defs> block:
    @output << <<-EOH
      <defs>
        <marker
          id="start-arrow-marker"
          viewBox="0 0 5 16"
          refX="0.5" refY="8"
          markerUnits="strokeWidth"
          markerWidth="12" markerHeight="40"
          orient="auto"
        >
          <path d="M5,3 L5,13 L1,8 L5,3" fill="#{measure_color}" />
          <rect x="0" y="0" width="1" height="16" fill="#{measure_color}" />
        </marker>
        <marker
          id="end-arrow-marker"
          viewBox="0 0 5 16"
          refX="4.5" refY="8"
          markerUnits="strokeWidth"
          markerWidth="12" markerHeight="40"
          orient="auto"
        >
          <path d="M0,3 L0,13 L4,8 L0,3" fill="#{measure_color}" />
          <rect x="4" y="0" width="1" height="16" fill="#{measure_color}" />
        </marker>
      </defs>
    EOH
  end

  alias_method :text_without_inkscape_fix, :text

  def text_with_inkscape_fix(x, y, text, style=DefaultStyles[:text])
    if $use_inkscape_text_fix
      @output << %Q{<text x="#{x}" y="#{y}"}
      style = fix_style(default_style.merge(style))
      @output << %Q{ font-family="#{style.delete "font-family"}"} if style["font-family"]
      @output << %Q{ font-size="#{style.delete "font-size"}"} if style["font-size"]
      fs = (style['font-size'] || '10px')
      font_size_info = fs.match(/^([0-9.]+)([^0-9.].*)?$/).to_a
      font_units = font_size_info.pop
      font_size = font_size_info.pop.to_f
      write_style style
      @output << ">"
      dy = 0 # First line should not be shifted
      text.each_line do |line|
        @output << %Q{<tspan x="#{x}" dy="#{dy * font_size}#{font_units}">}
        dy = 1 # Next lines should be shifted
        @output << line.rstrip
        @output << "</tspan>"
      end
      @output << "</text>"
    else
      text_without_inkscape_fix(x, y, text, style)
    end
  end

  alias_method :text, :text_with_inkscape_fix

end


module Tango

  class Peak; end
  class Trough; end
  class Tristate; end

  class Fold
    def initialize(options = {})
      @tag = options[:tag]
    end
    def self.[](tag)
      self.new( tag: tag )
    end
    def tag
      @tag
    end
  end

  # This is a special channel "name" used for control data (e.g. folds):
  class ControlChannel
    class << self
      def to_s
        "(Internal ControlChannel)"
      end
      def to_sym
        # SMELL: This is a kludge to shoe-horn ControlChannel support in:
        self
      end
    end
  end

  # Describes a channel:
  class Channel < Hash
    def risefall
      self[:risefall] || 0.25
    end
  end

  # Collects all channels:
  class Channels < Array
    def [](name)
      if String === name || Symbol === name
        # Find by :name
        self.find {|c| c[:name].to_s.strip == name.to_s.strip}
      elsif name == ControlChannel
        # Find THE ControlChannel:
        self.find {|c| c[:name] == name}
      else
        # Find by Array index:
        super
      end
    end
  end

  # Describes a label:
  class Label < Array
    # def initialize(time, label)
    #   self[:time] = time
    #   self[:label] = label
    # end
  end

  # Collects all labels:
  class Labels < Array
    # def <<(label)
    #   super
    #   self.sort!
    # end
  end

  # Describes a sample, for one or more channels, recorded at a point in time:
  class Sample < Hash
  end

  # Collects all samples:
  class Samples < Hash
    def time_range
      kk = keys.sort
      (kk.first..kk.last)
    end
    def earliest
      time_range.first
    end
    def latest
      time_range.last
    end
    def new(time, data)
      # Make sure channel keys are symbols:
      new_data = {}
      data.each {|k,v| new_data[k.to_sym] = v}
      # If a sample already exists for this time, grab it. Otherwise, create one:
      if self[time]
        # Check this sample record to reject any conflicting channel samples:
        conflicting = self[time].keys & new_data.keys
        raise "Simultaneous sample (#{conflicting}) recorded at #{time} for channel(s): #{conflicting.join(', ')} -- Data: #{self[time].inspect}" unless conflicting.empty?
        # Update the sample with extra channel(s):
        self[time].merge!(new_data)
      else
        # Create a new sample record.
        s = Sample.new
        s.merge!(new_data)
        self[time] = s
      end
    end
    def each_sample(channels, &block)
      # Establish the initial state:
      state = {}
      channels.each do |c|
        v = c[:initial]
        if c[:negative]
          # Apply negative logic:
          v = !v if true == v || false == v
        end
        state[c[:name]] = v unless c[:name] == ControlChannel
      end
      block.call(:initial, state)
      # Now go thru each sample in order and send updated state:
      keys.sort.each do |time|
        # We remove the PRIOR ControlChannel value, and let it be replaced only if it changed
        # (since the ControlChannel is not considered to be stateful):
        state.delete(ControlChannel)
        # Update state, applying negative logic where required:
        self[time].each do |c, v|
          if channels[c][:negative]
            # Apply negative logic:
            v = !v if true == v || false == v
          end
          state[c] = v
        end
        # Send this off to the caller's block:
        block.call(time, state)
      end
    end
  end


  class Scope
    attr_reader :now
    attr_reader :channels
    attr_reader :labels
    attr_reader :samples
    attr_accessor :units

    def self.attr_helper(*args)
      # Check correct arg count:
      raise ArgumentError, "attr_helper: Wrong number of arguments (#{args.count} for 1..2)" unless (1..2).cover?(args.count)
      # Determine var name:
      name = args.shift
      vn = "@#{name}"
      # Determine reader method, with default handling (where specified):
      if args.empty?
        reader_def = vn
      else
        reader_def = "defined?(#{vn}) ? #{vn} : #{args.first}"
      end
      # Define the method that reads, and that implicitly writes, the var:
      self.class_eval <<-EOH
        def #{name}(*args)
          if args.empty?
            #{reader_def}
          elsif args.count == 1
            #{vn} = args.first
          else
            raise ArgumentError, "Too many arguments for #{name}(): \#{args.count} for 0..1"
          end
        end
      EOH
    end

    # Size of point markers (false => off):
    attr_helper :point_size, false

    # Default rise/fall time (if not overridden by channel):
    attr_helper :risefall, 0.0

    # Amount of time to render before t=0.0
    attr_helper :lead_in, 0.0

    # Nominal 0-to-peak amplitude of a rendered channel.
    attr_helper :channel_height, 1

    # Spacing between channel baselines:
    attr_helper :channel_pitch, 3

    # Vertical offset for the first channel.    
    attr_helper :channel_offset, 5

    # How much to multiply time (i.e. pixels-per-unit):
    attr_helper :time_scale, 4

    # Number of pixels to indent waveforms, to make space for labels:
    attr_helper :time_offset, 60

    # Define the units for this scope.
    # :d, :h, :m, :s, :ms, :us, :ns, :ps, :fs
    attr_helper :units, :us

    # When rendering labels, do we want to see the time on them?
    attr_helper :show_label_times, true

    # This fixes a problem when Adobe Illustrator tries to interpret lines
    # that have markers applied, which otherwise causes measurement lines
    # to disappear:
    attr_helper :measurement_ai_fix, false

    # By default, compact points which don't actually add any value
    # to the waveform, to produce a more efficient (and cleaner) output file:
    attr_helper :compact_points, true

    def inkscape_text_fix(set = nil)
      if set.nil?
        $use_inkscape_text_fix
      else
        $use_inkscape_text_fix = set
      end
    end


    def initialize(&block)
      @now = 0.0
      @channels = Channels.new
      # Pre-define a special control channel:
      channel ControlChannel, initial: nil
      @labels = Labels.new
      @samples = Samples.new
      @ruler = {}
      @measurements = {}
      @partial_measurements = {}
      @zooms = []
      @styles = {
        label_lines: { stroke: 'cyan', stroke_width: 0.40 },
        ruler_lines: { stroke: 'gray', stroke_width: 0.25 },
        measures: { stroke: 'magenta', stroke_width: 0.40 },
        waveform_base: { stroke_width: 0.85 }
      }
      instance_eval(&block)
    end

    def style(set)
      @styles.merge!(set)
    end

    UNIT_MAP = [
      [:fs, 1000.0],
      [:ps, 1000.0],
      [:ns, 1000.0],
      [:us, 1000.0],
      [:ms, 1000.0],
      [:s, 1000.0],
      [:m, 60.0],
      [:h, 60.0],
      [:d, 24.0]
    ]

    def scale_units(value, from_units, to_units)
      v = value.to_f
      range = (
        UNIT_MAP.find_index {|e| e[0] == from_units} ..
        UNIT_MAP.find_index {|e| e[0] == to_units}
      )
      if range.first < range.last
        # We're going from small units to bigger units:
        range.to_a[1..-1].map{|e| UNIT_MAP[e][1]}.each { |m| v /= m }
      else
        # We're going from big units to smaller units:
        range.first.downto(range.last).map{|e| UNIT_MAP[e][1]}[0..-2].each { |m| v *= m }
      end
      v
    end

    def debug(msg)
      puts "DEBUG: #{msg}"
    end

    def notimp(msg)
      puts "NOT IMPLEMENTED: #{msg}"
    end

    def units_string(my_units = nil)
      uu = my_units || @units
      # Make sure "us" is rendered with a mu (micro):
      :us == uu ? '&#956;s' : uu.to_s
    end

    # Create a new channel.
    def channel(name, options = {})
      raise RuntimeError, %(Channel "#{name}" already exists!) if @channels[name]
      new_channel = Channel[options.merge(:name => name)]
      new_channel[:risefall] ||= @risefall
      @channels << new_channel
    end

    # Record a sample.
    # sample(Hash): Record a sample at the current time.
    # - It is an error to record a sample for a channel that already has one AT THIS TIME.
    # sample(Fixnum, Hash): Advance the timer, then record a sample.
    # sample(Range, Hash): Advance timer to Range.first, record a sample, then advance the timer again.
    # at(Fixnum): TEMP seek to Fixnum time (in scope of current repeat, if any) for just our block.
    def sample(*args, channel_data)
      raise RuntimeError, %(Invalid channel_data: #{channel_data.inspect}) unless Hash === channel_data
      if args.empty?
        timeframe = now
      else
        timeframe = args.shift
      end
      # Advance to the START of this sample:
      @now += (Range === timeframe) ? timeframe.first : timeframe
      s = @samples.new(@now, channel_data)
      # Advance to the END of this sample (if provided):
      @now += timeframe.last if Range === timeframe
      # Return the sample:
      s
    end

    # step(Fixnum): Advance the timer.
    def step(time)
      raise RuntimeError, %(Timer step must be >= 0, but #{time} was given!) unless time >= 0
      @now += time
    end

    def lead_in(time)
      raise RuntimeError, "Timer must be at 0 when using lead_in, but it was at #{time}" unless (@now || 0) == 0
      @now = time
      @lead_in = time
    end

    # 'Push' @now and offset it for the block we'll run, then wind it back.
    def at(*args); end

    # Mark the current time with a label:
    def label(name)
      @labels << Label.new( [now, name, nil, {}] )
    end

    def mark(tag = nil, options = {})
      if options[:hide]
        # NOTE: Hidden marks don't get "repeat rejection" because they're needed for
        # time tracking instead of rendering:
        found = @labels.find { |m| tag && (m[2] == tag) }
      else
        found = @labels.find { |m| !m[3][:hide] && (m[0] == now || (tag && (m[2] == tag))) }
      end
      if found
        if options[:hide]
          # Hidden marks get overridden:
          found[0] = now
          found[3] = options
          return found
        else
          debug "Rejecting repeated mark " + ((tag && (found[2] == tag)) ? "with tag #{tag.inspect}" : "at #{now}")
          return nil
        end
      end
      @labels << Label.new( [now, nil, tag, options] )
    end

    def mark_seek(tag, time = 0)
      # First, look up the given mark tag:
      found = @labels.find {|m| (tag && (m[2] == tag))}
      raise RuntimeError, "Cannot find a mark with tag #{tag.inspect}" unless found
      seek(found[0] + time)
    end

    # Add a fold point to the ControlChannel:
    def fold(tag, options = {})
      sample 0, ControlChannel => Fold[tag]
    end

    # Define a block that repeats.
    def repeat(range, *args, &block)
      if Hash === args.last
        options = args.pop
      else
        options = {}
      end
      name = args.empty? ? nil : args.first
      base_time = now
      if Range === range
        start = (@now += range.first)
        # This repeats to fill a time range.
        if options[:samples]
          # Repeat for a specific number of time divisions.
          size = (range.last-range.first).to_f
          count = options[:samples]
          # NOTE: By default, we don't sample the maximum point, but we still
          # do advance @now to this point:
          value = nil
          inc = options[:inclusive]
          count.times do |index|
            pct = (index.to_f/(count - (inc ? 1 : 0)))
            time = pct * size
            new_time = start + time
            raise RuntimeError, "Overlapping time in sample-based repeat!" if @now > new_time
            @now = start + time
            # NOTE: When we support other scales, we have to modify the 2nd argument ('pct') below:
            block.call(index, pct, time)
          end
          @now = start + size unless inc
        else
          # Repeat until we're over the range limit.
          n = 0
          until @now >= start+range.last
            yield n
            n += 1
          end
        end
      else
        # This is a simple loop:
        num = (:n == range) ? 1 : range
        p = options[:period]
        num.times do |n|
          @now = base_time + n*p if p
          yield n
        end
        @now = base_time + num*p if p
      end
    end

    def each_sample(&block)
      @samples.each_sample(@channels, &block)
    end

    def write_csv(filename)
      File.open(filename, 'w') do |f|
        each_sample do |time, data|
          if :initial == time
            time = -1
            f.puts "time,#{data.keys.join(',')}"
          end
          f.puts "#{time},#{data.values.join(',')}"
        end
      end
    end

    def seek(time)
      @now = time
    end

    def guidelines(state)
      @guidelines = state
    end

    def untimed
      time = @now
      yield
      @now = time
    end

    def baseline_for_channel(channel_index)
      channel_pitch * channel_index + channel_offset
    end

    def guide(time)
      t = scaled_time(time)
      [ [t,2.0], [t,baseline_for_channel(channels.count)], nil ]
    end

    def tick(time, major = false)
      t = scaled_time(time)
      [ [t,0], [t, major ? 1.5 : 0.5], nil]
    end

    def scaled_time(time)
      time * time_scale + time_offset
    end

    def xy(time, value, channel_index)
      if value == true || Peak == value
        y = 1
      elsif value == false || Trough == value
        y = 0
      elsif Float === value || Fixnum === value
        y = value.to_f
      elsif value == Tristate
        y = 0.5
      else # Arbitrary value:
        y = 0
      end
      y = -y
      [scaled_time(time), baseline_for_channel(channel_index) + y*channel_height]
    end

    def measure(*args, &block)
      options = (Hash === args.last) ? args.pop : {}
      name = args.first
      unless @measurements[name] || (options.has_key?(:select) && !options[:select])
        start = @now
        block.call
        duration = @now - start
        @measurements[name] = {
          begin: start,
          end: @now,
          y: (options[:y] || (channels.count-0.5)),
          align: (options[:align] || :left),
          units: (options[:units] || units),
          override: options[:override]
        }
      else
        block.call
      end
    end

    def start_measure(*args)
      options = (Hash === args.last) ? args.pop : {}
      name = args.first
      # Reject this if we already have a measure of that name;
      # OR if it's not selected;
      # OR if a partial measurement is already started with that name:
      return nil if @measurements[name] || (options.has_key?(:select) && !options[:select]) || @partial_measurements[name]
      @partial_measurements[name] = {
          begin: @now,
          y: (options[:y] || (channels.count-0.5)),
          align: (options[:align] || :left),
          units: (options[:units] || units),
          override: options[:override]
      }
    end

    def end_measure(*args)
      options = (Hash === args.last) ? args.pop : {}
      name = args.first
      # Reject this if we don't already have a partial measurement of that name;
      # OR if it's not selected:
      return nil if !@partial_measurements[name] || (options.has_key?(:select) && !options[:select])
      new_measurement = @partial_measurements.delete(name)
      new_measurement[:end] = @now
      @measurements[name] = new_measurement
    end

    def zoom(name, options = {}, &block)
      unless @zooms.include?(name)
        zoom_head = @now - (options[:pad_in] || options[:pad] || 0)
        block.call
        zoom_tail = @now + (options[:pad_out] || options[:pad] || 0)
        @zooms << name
        # TODO: RENDER the zoom. Need to add support for "scale"; i.e. how wide should the zoom window be?
        notimp "Zoom rendering not yet implemented; zoom(#{name}) covers #{(zoom_head..zoom_tail).inspect}"
      else
        block.call
      end
    end


    def render_to_points
      # Build a structure that will hold all the point data we need to render, per channel:
      cc = @channels.count
      # NOTE: We make cc+1 point streams because the extra one is for misc. lines/text:
      points = (cc+1).times.map do |x|
        Hash[*(%w(main sub text).inject([]) { |a,k| a+[k.to_sym, []]})]
      end
      @guides = []
      # NOTE: each_sample will give us the time of the sample, and the values for
      # ALL channels at that sample time:
      last_sample = nil
      wait_for_fold = nil
      each_sample do |time, data|
        if :initial == time
          # Load points for initial state:
          data.each_with_index do |cd, ci|
            name,value = cd

            if name == ControlChannel
              # This is the ControlChannel; normal rendering doesn't apply.
              next
            end

            ch = channels[name]
            tp = xy(0, 0.25, ci)
            tp[0] -= time_offset
            points[ci][:text] << [
              tp,
              name.to_s,
              'font-family' => 'helvetica, arial, sans-serif',
              'font-weight' => 'bold',
              'text-decoration' => ch[:negative] ? 'overline' : 'none',
            ]
            if ch[:subtext]
              points[ci][:text] << [
                tp,
                "\n#{ch[:subtext]}",
                'font-family' => 'helvetica, arial, sans-serif',
                'font-weight' => 'bold',
                'font-size' => '10px',
              ]
            end
            points[ci][:main] << xy(0, value, ci)
            # Get rise-fall value for this channel:
            points[ci][:rf] = ch.risefall
          end
        else
          control = data[ControlChannel]
          if Fold === control
            puts control.inspect
            if control.tag == wait_for_fold
              # Clear old Fold wait:
              wait_for_fold = nil
            else
              # Set new Fold wait:
              wait_for_fold = :byte_loop_end #control.tag
            end
          end

          # Don't do anything, so long as we're waiting for a fold.
          next if wait_for_fold

          # Load subsequent points:
          data.each_with_index do |cd, ci|
            name,value = cd

            if name == ControlChannel
              # This is the ControlChannel; normal rendering doesn't apply.
              if Fold === value
                seek time
                mark
              end
              next
            end

            ch = channels[name]
            rf = points[ci][:rf] * time_scale / 2

            # Is this sample an arbitrary value?
            is_arb = (String === value || Symbol === value)
            # Was the previous sample arbitrary?
            last = last_sample[name]
            was_arb = (String === last || Symbol === last)
            # Is this sample different from the last?
            changed = (value != last)

            if is_arb
              # Calculate our TARGETS for top & bottom:
              bot_target = xy(time, Trough, ci)
              top_target = xy(time, Peak, ci)
              # This is an arbitrary value...
              if was_arb
                # Previous point was arbitrary too... is it maybe unchanged?
                if changed
                  # OK, we've got a change, so break the lines and reset:
                  new_main = [nil, points[ci][:sub].last.clone]
                  new_sub = [nil, points[ci][:main].last.clone]
                  points[ci][:main] += new_main
                  points[ci][:sub] += new_sub
                  # Gap points:
                  points[ci][:main] << [bot_target[0]-rf, bot_target[1]]
                  points[ci][:sub] << [top_target[0]-rf, top_target[1]]
                  # Final switch points:
                  bot_target[0] += rf
                  top_target[0] += rf
                  points[ci][:main] << top_target
                  points[ci][:sub] << bot_target
                else # Still arbitrary, and NOT changed...
                  # Hasn't changed, so just extend it.
                  # Now just use the new target points:
                  bot_target[0] += rf
                  top_target[0] += rf
                  points[ci][:main] << top_target
                  points[ci][:sub] << bot_target
                end # changed
              else # NOT arbitrary...
                # Previous point was NOT arbitrary.
                last_point = points[ci][:main].last
                # Determine the gap point:
                gap = [bot_target[0]-rf, last_point[1]]
                # This is needed for both :main and :sub...
                points[ci][:main] << gap
                points[ci][:sub] << gap
                # OK, now put the target in both, and break the respective lines:
                bot_target[0] += rf
                top_target[0] += rf
                points[ci][:main] << top_target
                points[ci][:sub] << bot_target
              end # was_arb
              if changed
                # Do the text:
                fs = ch[:font_size] || 10
                nudge = ch[:text_nudge] || [1,0]
                text_point = xy(time, nudge[1], ci)
                text_point[0] += nudge[0]
                points[ci][:text] << [
                  text_point,
                  value.to_s,
                  'font-family' => 'helvetica',
                  'font-size' => "#{fs}px",
                ]
              end # changed
            else # NOT arbitrary...
              # This is NOT an arbitrary value...
              last_point = points[ci][:main].last
              # Create the point for this sample:
              sample_point = xy(time, value, ci)
              # Create the point that bridges the previous sample with this one:
              gap_point = [sample_point[0] - rf, last_point[1]]
              # Add both samples to the stream:
              points[ci][:main] << gap_point
              sample_point[0] += rf
              points[ci][:main] << sample_point
              # Was the previous an arbitrary, tho?
              if was_arb
                # OK, at this point, :main has the peak point, and :sub has the trough...
                # We always prefer :main, so just collapse both to our NEW :main point:
                penultimate = xy(time, Trough, ci)
                penultimate[0] -= rf
                ultimate = points[ci][:main].last.clone
                points[ci][:sub] << penultimate
                points[ci][:sub] << ultimate
                points[ci][:sub] << nil
              end # was_arb, but not now.
            end # non-arbitrary.
          end # data.each_with_index
          if @guidelines
            # Generate guide lines:
            @guides += guide(time)
          end
        end
        last_sample = data.clone
      end
      # Convert labels into an extra "channel":
      labels.each do |time, text, tag, op|
        next if op[:hide]
        line = guide(time)
        points[cc][:main] += line
        if text
          label_text = show_label_times ? "#{'%0.3f' % (time-@lead_in)}#{units_string}\n#{text}" : text
          text_item = [
            [line[0][0], 2.5], # This places the label TEXT comfortably beneath the ruler.
            label_text,
            'font-family' => 'helvetica',
            'font-size' => '10px',
          ]
          points[cc][:text] << text_item
        end
      end
      @points = points
      if @ruler[:enabled]
        x = @lead_in
        last = samples.latest
        major_counter = 0
        while (x <= last)
          major = ( 0 == major_counter % (@ruler[:major] || 5) )
          t = tick(x, major)
          @guides += t
          major_counter += 1
          if major
            points[cc][:text] << [
              t[1],
              "#{"%0.#{@ruler[:decimals] || 2}f" % (x-@lead_in)}#{units_string}",
              'font-family' => 'helvetica',
              'font-size' => '10px',
            ]
          end
          x += @ruler[:step] || 1
        end
      end
      # Render measurements:
      @mezdata = {}
      @measurements.each do |name,mez|
        start = xy(mez[:begin], 0.5, mez[:y])
        stop = xy(mez[:end], 0.5, mez[:y])
        usuffix = units_string(mez[:units])
        size = scale_units(mez[:end]-mez[:begin], units, mez[:units])
        md = {
          y: start[1], height: channel_height,
          in: start[0], out: stop[0],
          text: "#{name}:\n" + ( mez[:override] || (('%0.3f' % size) + usuffix) ),
          align: mez[:align]
        }
        @mezdata[name] = md
      end
      true
    end

    def width(set = nil)
      if set
        @image_width = set
      else
        @image_width || 1000
      end
    end

    def height(set = nil)
      if set
        @image_height = set
      else
        @image_height || 500
      end
    end

    def ruler(*args)
      @ruler = (Hash === args.last) ? args.pop : {}
      raise RuntimeError, "Too many arguments for ruler definition (#{args.count+1} for 0..2)" if args.count > 1
      @ruler[:enabled] = args.empty? ? true : args.first unless @ruler.has_key?(:enabled)
    end

    # Transform a point from "channel units" to SVG canvas pixel units:
    def scale_vertex(vertex, options = {})
      offset = options[:offset] || [0,0]
      [(vertex[0]+offset[0])*14/9, (vertex[1]+offset[1])*20+5]
    end

    def write_svg(filename, options = {})
      case (options[:engine] || 'rasem').to_s
      when 'rasem'
        render_to_points
        cc = channels.count
        base_colors = %w(#f80 blue green red purple teal)
        colour_set = []
        channels.each do |c|
          colour_set << (c[:color] || base_colors.first)
          base_colors.rotate!
        end
        base_styles = colour_set.map{|c| @styles[:waveform_base].merge( stroke: c ) }
        styles =
          base_styles + [
            # Style for marks/labels:
            @styles[:label_lines],
            # Style for ruler:
            @styles[:ruler_lines],
          ] +
          base_styles + [
            # Style for SECONDARY marks/labels (should be unused!)
            { stroke: 'red', stroke_width: 2.0 },
            # Style for measurements:
            @styles[:measures],
          ]
        # SMELL: Instead of setting all these, just define s = self and reference that:
        points = @points
        guides = @guides
        scope = self
        style = nil
        compact = compact_points
        measures = @mezdata
        measures_color = @styles[:measures][:stroke]
        ai = measurement_ai_fix
        sp = point_size
        # TODO: Default width and height should be based on extents of the data.
        svg = Rasem::SVGImage.new(options[:width] || width, options[:height] || height) do
          # Rasem::SVGImage#add_defs: Add a <defs> block that describes arrow markers, etc:
          add_defs(measures_color)
          point_streams = [*points.map{|c| c[:main]}, guides, *points.map{|c| c[:sub]}]
          point_streams.each_with_index do |point_stream, index|
            group do
              style = styles.shift.merge(fill: 'none') unless styles.empty?
              # Break the stream into arrays of points, splitting on nil:
              paths = point_stream.chunk{|p| p ? true : nil}.map{|_,v| v}
              paths.each do |path|
                raise "Path needs at least 2 vertices, but it has: #{path.count}" unless path.count >= 2
                if compact
                  # "Compact" the points by removing points which don't change the shape of the line.
                  # This also fixes glitches when using "repeat(..., samples: X)" inside an "untimed" block,
                  # though I should really get to the bottom of that (which seems to have something to do
                  # with incorrectly applying the rise/fall-time offset).
                  flat_path = []
                  path.each_with_index do |pt, index|
                    if index == 0 || index == path.count-1
                      flat_path << pt
                    else
                      flat_path << pt unless flat_path.last[1] == pt[1] && pt[1] == path[index+1][1]
                    end
                  end
                  path = flat_path
                end
                # Render the line:
                polyline(*(path.map{|v| scope.scale_vertex(v)}), style)
                if sp
                  # Render the points of the line:
                  group do
                    path.each do |pt|
                      circle(*(scope.scale_vertex(pt)), sp, style.merge(:fill => style[:stroke]))
                    end # points loop.
                  end # points sub-group.
                end # render points?
              end # paths.each
            end # channel lines group.
          end
          # Show data values (text):
          points.map{|c| c[:text]}.each do |text_group|
            group do
              text_group.each do |item|
                text_info = scope.scale_vertex(item[0]) + item[1..-1]
                text(*text_info)
              end
            end
          end
          # TODO: Rendering for measures:
          # * For now, could just be a header/footer "H" bar (e.g.: |---- name: 23us ---- |);
          # * Later, add support for placing between nominated channels, and relating between channels.
          style = styles.shift || { stroke: 'red', stroke_width: 2.0 }
          group do
            measures.each do |name, mez|
              group do
                y = mez[:y]
                hh = mez[:height] / 2.0
                # Render head & tail bars:
                horiz = []
                [:in, :out].each do |x|
                  t = scope.scale_vertex( [mez[x], y-hh] )
                  b = scope.scale_vertex( [mez[x], y+hh] )
                  horiz << scope.scale_vertex( [mez[x], y] )
                  #line(*(t+b), style.merge( stroke_width: 1.0 ))
                end
                # Now render the joining line:
                markers = { 'marker-start' => 'url(#start-arrow-marker)', 'marker-end' => 'url(#end-arrow-marker)' }
                ss = style.merge(markers)
                line(*(horiz.flatten), ss)
                # Repeat the line WITHOUT markers for Adobe Illustrator's benefit:
                line(*(horiz.flatten), style) if ai
                # ...and the label(s):
                align_set = (mez[:align] == :all) ? %w(left center right) : mez[:align]
                [*align_set].each do |align|
                  case align.to_sym
                  when :left
                    text_point = [ horiz[0][0]-2, horiz[0][1] ]
                    anchor = 'end'
                  when :center, :mid, :middle
                    text_point = [ (horiz[0][0]+horiz[1][0])/2.0, horiz[0][1] ]
                    anchor = 'middle'
                  when :right
                    text_point = [ horiz[1][0]+2, horiz[0][1] ]
                    anchor = 'start'
                  else
                    raise RuntimeError, "Unknown measurement align: #{mez[:align].inspect}"
                  end
                  text(
                    *text_point, mez[:text],
                    'font-family' => 'helvetica',
                    'font-size' => '9px',
                    'text-anchor' => anchor
                  )
                end
              end
            end
          end
        end # svg
        File.open(filename, 'w') do |file|
          file.write svg.output
        end
      else
        raise "Unsupported SVG engine: #{options[:engine].inspect}"
      end
    end

  end
end


