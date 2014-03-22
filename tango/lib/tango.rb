require 'rasem'

module Tango

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
        self.find {|c| c[:name].to_s.strip == name.to_s.strip}
      else
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
    def <<(label)
      super
      self.sort!
    end
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
        state[c[:name]] = v
      end
      block.call(:initial, state)
      # Now go thru each sample in order and send updated state:
      keys.sort.each do |time|
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

    def initialize(&block)
      @lead_in = 0.0
      @now = 0.0
      units(:us)
      @channels = Channels.new
      @labels = Labels.new
      @samples = Samples.new
      @risefall = 0.0
      @ruler = {}
      @measurements = []
      @zooms = []
      instance_eval(&block)
    end

    # Define the units for this scope.
    # :d, :h, :m, :s, :ms, :us, :ns, :ps, :fs
    def units(u)
      @units = u
    end

    def units_string
      # Make sure "us" is rendered with a mu (micro):
      :us == @units ? '&#956;s' : @units.to_s
    end

    # Create a new channel.
    def channel(name, options = {})
      raise RuntimeError, %(Channel "#{name}" already exists!) if @channels[name]
      new_channel = Channel[options.merge(:name => name)]
      new_channel[:risefall] ||= @risefall
      @channels << new_channel
    end

    def risefall(rate)
      @risefall = rate
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
      ll = Label.new( [now, name] )
      @labels << ll
    end

    def mark
      @labels << Label.new( [now, nil] )
    end

    # Define a block that repeats.
    def repeat(range, name, options={}, &block)
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

    # Nominal peak-to-peak amplitude of a rendered channel.
    def channel_height
      1
    end

    # Spacing between channel baselines.
    def channel_pitch
      3
    end

    # Vertical offset for the first channel.
    def channel_offset
      5
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
      [ [t,baseline_for_channel(-1)], [t,baseline_for_channel(channels.count)], nil ]
    end

    def tick(time, major = false)
      t = scaled_time(time)
      [ [t,0], [t, major ? 1.5 : 0.5], nil]
    end

    def scaled_time(time)
      time * time_scale + time_offset
    end

    def time_scale(set = nil)
      if set
        @time_scale = set
      else
        @time_scale ||= 4
      end
    end

    def time_offset
      60
    end

    def xy(time, value, channel_index)
      if value == true
        y = -1
      elsif value == false
        y = 1
      elsif Float === value
        y = -value
      else
        y = 1
      end
      [scaled_time(time), baseline_for_channel(channel_index) + y*channel_height]
    end

    def measure(*args, &block)
      options = (Hash === args.last) ? args.pop : {}
      name = args.first
      unless @measurements.include?(name)
        start = @now
        block.call
        duration = @now - start
        @measurements << name
        puts "WARNING: measurement rendering not yet implemented; measure(#{name}): #{duration}"
        # TODO: RENDER the measure:
        # * For now, could just be a header/footer "H" bar (e.g.: |---- name: 23us ---- |);
        # * Later, add support for placing between nominated channels, and relating between channels.
      else
        block.call
      end
    end

    def zoom(name, options = {}, &block)
      unless @zooms.include?(name)
        zoom_head = @now - (options[:pad_in] || options[:pad] || 0)
        block.call
        zoom_tail = @now + (options[:pad_out] || options[:pad] || 0)
        @zooms << name
        # TODO: RENDER the zoom. Need to add support for "scale"; i.e. how wide should the zoom window be?
        puts "WARNING: zoom rendering not yet implemented; zoom(#{name}) covers #{(zoom_head..zoom_tail).inspect}"
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
      each_sample do |time, data|
        if :initial == time
          # Load points for initial state:
          data.each_with_index do |cd, ci|
            name,value = cd
            ch = channels[name]
            tp = xy(0, 0.25, ci)
            tp[0] -= time_offset
            points[ci][:text] << [
              tp,
              name.to_s,
              'font-family' => 'helvetica, arial, sans-serif',
              'font-weight' => 'bold',
              'text-decoration' => ch[:negative] ? 'overline' : 'none'
            ]
            points[ci][:main] << xy(0, value, ci)
            # Get rise-fall value for this channel:
            points[ci][:rf] = ch.risefall
          end
        else
          # Load subsequent points:
          data.each_with_index do |cd, ci|
            name,value = cd
            ch = channels[name]
            rf = points[ci][:rf] * time_scale / 2
            last_point = points[ci][:main].last
            # Create the point for this sample:
            sample_point = xy(time, value, ci)
            # Create the point that bridges the previous sample with this one:
            gap_point = [sample_point[0] - rf, last_point[1]]
            # Add both samples to the stream:
            points[ci][:main] << gap_point
            sample_point[0] += rf
            points[ci][:main] << sample_point
            # Render the sample arbitrary text if needed:
            if (String === value || Symbol === value)
              # We're in an arbitrary sample value...
              if points[ci][:sub][-1].nil?
                points[ci][:sub] << points[ci][:main][-4]
                nextum = xy(time, true, ci)
                nextum[0] = points[ci][:main][-3][0]
                #jump_point = xy(time, true, ci)
                #jump_point[0] -= rf
                #points[ci][:sub] << jump_point
                points[ci][:sub] << nextum
              end

              # points[ci][:sub] << last_point
              # jump_point = xy(time, true, ci)
              # jump_point[0] -= rf
              # points[ci][:sub] << jump_point
              # points[ci][:sub] << nil
              if value.to_s != last_sample[name].to_s
                # This is the start of a new arbitrary sample value...
                nextum = xy(time, true, ci)
                nextum[0] -= rf
                points[ci][:sub] << nextum
                nextum = xy(time, false, ci)
                nextum[0] += rf
                points[ci][:sub] << nextum
                points[ci][:sub] << nil
                # Do the text:
                font_size = ch[:font_size] || '10px'
                font_size = font_size.to_s + 'px' unless String === font_size
                text_point = xy(time, -0.15, ci)
                text_point[0] += 1
                points[ci][:text] << [
                  text_point,
                  value.to_s,
                  'font-family' => 'helvetica',
                  'font-size' => font_size,
                ]
                # # Was the previous sample value also arbitrary?
                # # If so, we put in a division:
                # ls = last_sample[name]
                # if String === ls || Symbol === ls
                #   top = xy(time, true, ci)
                #   bot = xy(time, false, ci)
                #   points[ci][:sub] += [top, bot, nil]
                # end
              end
            end
          end
          if @guidelines
            # Generate guide lines:
            @guides += guide(time)
          end
        end
        last_sample = data.clone
      end
      # Convert labels into an extra "channel":
      labels.each do |time, text|
        line = guide(time)
        points[cc][:main] += line
        if text
          text_item = [
            [line[0][0], 2.5],
            "#{'%0.3f' % (time-@lead_in)}#{units_string}\n#{text}",
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

    def rasem_scale_vertex(vertex, options = {})
      offset = options[:offset] || [0,0]
      [(vertex[0]+offset[0])*14/9, (vertex[1]+offset[1])*20+5]
    end

    def waveform_style(set = nil)
      if set
        @waveform_style = waveform_style.merge(set)
      else
        @waveform_style || { stroke_width: 0.7 }
      end
    end

    def write_svg(filename, options = {})
      case (options[:engine] || 'rasem').to_s
      when 'rasem'
        render_to_points
        cc = channels.count
        base_colors = %w(black blue green red)
        colour_set = []
        channels.each do |c|
          colour_set << (c[:color] || base_colors.first)
          base_colors.rotate!
        end
        base_styles = colour_set.map{|c| waveform_style.merge( stroke: c ) }
        styles =
          base_styles + [
            { stroke: 'cyan', stroke_width: 0.40 },
            { stroke: 'gray', stroke_width: 0.25 },
          ] +
          base_styles
        points = @points
        guides = @guides
        scope = self
        style = nil
        # TODO: Default width and height should be based on extents of the data.
        svg = Rasem::SVGImage.new(options[:width] || width, options[:height] || height) do
          point_streams = [*points.map{|c| c[:main]}, guides, *points.map{|c| c[:sub]}]
          point_streams.each_with_index do |point_stream, index|
            style = styles.shift.merge(fill: 'none') unless styles.empty?
            # Break the stream into arrays of points, splitting on nil:
            paths = point_stream.chunk{|p| p ? true : nil}.map{|_,v| v}
            paths.each do |path|
              raise "Path needs at least 2 vertices, but it has: #{path.count}" unless path.count >= 2
              polyline(*(path.map{|v| scope.rasem_scale_vertex(v)}), style)
            end
          end
          # Show data values (text):
          points.map{|c| c[:text]}.flatten(1).each do |item|
            text_info = scope.rasem_scale_vertex(item[0]) + item[1..-1]
            text(*text_info)
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


