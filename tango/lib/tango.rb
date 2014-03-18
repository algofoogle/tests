require 'xrvg'
require 'rasem'

include XRVG

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
  class Label < Hash
    def initialize(time, label)
      self[:time] = time
      self[:label] = label
    end
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
        raise "Simultaneous sample recorded at #{time} for channel(s): #{conflicting.join(', ')} -- Data: #{self[time].inspect}"
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
      @now = 0
      @units = :us
      @channels = Channels.new
      @labels = Labels.new
      @samples = Samples.new
      @risefall = 0
      instance_eval(&block)
    end

    # Define the units for this scope.
    # :d, :h, :m, :s, :ms, :us, :ns, :ps, :fs
    def units(u)
      @units = u
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

    # 'Push' @now and offset it for the block we'll run, then wind it back.
    def at(*args); end

    # Mark the current time with a label:
    def label(name)
      @labels << Label.new( :time => now, :label => name )
    end

    # Define a block that repeats.
    def repeat(count, name, options={}, &block)
      base_time = now
      num = (:n == count) ? 1 : count
      p = options[:period]
      num.times do |n|
        @now = base_time + n*p if p
        yield n
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

    def yscale
      10
    end

    def yoffset
      0
    end

    def xscale
      8
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
      2
    end

    def baseline_for_channel(channel_index)
      channel_pitch * channel_index + channel_offset
    end

    def guide(time)
      [ [scaled_time(time),baseline_for_channel(-1)], [scaled_time(time),baseline_for_channel(@channels.count)], nil ]
    end

    def scaled_time(time)
      time * time_scale + time_offset
    end

    def time_scale
      4
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
        y = value
      else
        y = 0
      end
      [scaled_time(time), baseline_for_channel(channel_index) + y*channel_height]
    end


    def render_to_points
      # Build a structure that will hold all the point data we need to render, per channel:
      cc = @channels.count
      points = cc.times.map do |x|
        Hash[*(%w(main sub text).inject([]) { |a,k| a+[k.to_sym, []]})]
      end
      guides = []
      # NOTE: each_sample will give us the time of the sample, and the values for
      # ALL channels at that sample time:
      each_sample do |time, data|
        if :initial == time
          # Load points for initial state:
          data.each_with_index do |cd, ci|
            name,value = cd
            points[ci][:text] << [xy(-12, 0.25, ci), name.to_s]
            points[ci][:main] << xy(0, value, ci)
            # Get rise-fall value for this channel:
            points[ci][:rf] = channels[name].risefall
          end
        else
          # Load subsequent points:
          data.each_with_index do |cd, ci|
            name,value = cd
            rf = points[ci][:rf] * time_scale / 2
            # Create the point for this sample:
            sample_point = xy(time, value, ci)
            # Create the point that bridges the previous sample with this one:
            gap_point = [sample_point[0] - rf, points[ci][:main].last[1]]
            gap_point[1]
            # Add both samples to the stream:
            points[ci][:main] << gap_point
            sample_point[0] += rf
            points[ci][:main] << sample_point
            # Add text if needed:
            if String === value || Symbol === value && value != last_sample[name]
              points[ci][:text] << [xy(time, 0.25, ci), value.to_s]
            end
          end
          if @guidelines
            # Generate guide lines:
            guides += guide(time)
          end
          last_sample = data
        end
      end
      @points = points
      @guides = guides
      true
    end

    def rasem_scale_vertex(vertex, options = {})
      offset = options[:offset] || [0,0]
      [(vertex[0]+offset[0])*14/9, (vertex[1]+offset[1])*20+5]
    end

    def write_svg(filename, options = {})
      case (options[:engine] || 'rasem').to_s
      when 'rasem'
        render_to_points
        colors = %w(gray) + %w(black blue green red) * 3
        points = @points
        guides = @guides
        scope = self
        svg = Rasem::SVGImage.new(1500, 500) do
          point_streams = [guides, *points.map{|c| c[:main]}]
          point_streams.each_with_index do |point_stream, index|
            color = colors.shift
            # Break the stream into arrays of points, splitting on nil:
            paths = point_stream.chunk{|p| p ? true : nil}.map{|_,v| v}
            paths.each do |path|
              raise "Path needs at least 2 vertices, but it has: #{path.count}" unless path.count >= 2
              polyline(*(path.map{|v| scope.rasem_scale_vertex(v)}), :stroke => color, :stroke_width => (index==0) ? 0.25 : 0.75, :fill => :none)
            end
          end
          points.map{|c| c[:text]}.flatten(1).each do |item|
            pos,text = item
            text(*scope.rasem_scale_vertex(pos), text)
          end
        end # svg
        File.open(filename, 'w') do |file|
          file.write svg.output
        end
      else
        raise "Unsupported SVG engine: #{options[:engine].inspect}"
      end
    end


    def old_write_svg(filename, options = {})
      case (options[:engine] || 'xrvg').to_s
      when 'xrvg'
        render = SVGRender[ :filename, filename, :imagesize, '1250px' ]
        x = @samples.earliest
        limit = @samples.latest
        prev_time = nil
        prev_data = nil
        last_points = nil
        channel_points = [[]] * @channels.count
        each_sample do |time, data|
          if :initial == time
            prev_time = 0
            data.each_with_index do |d, c|
              channel_points[c] << xyv(0, d[1], c)
            end
          else
            data.each_with_index do |p, ch_index|
              c,v = p
              p3 = xyv(time, v, ch_index)
              p2 = channel_points[ch_index].last.clone
              p2.x = p3.x - channels[c].risefall / 2
              channel_points[ch_index] << p2
              p3.x += channels[c].risefall / 2
              channel_points[ch_index] << p3
              if @guidelines
                lp1 = V2D[time, (-5 + yoffset) * yscale]
                lp2 = V2D[time, (25 + yoffset) * yscale]
                render.add(
                  Line[ :points, [lp1,lp2] ],
                  Style[ :stroke, "gray", :strokewidth, 0.01 ]
                )
              end
            end
            prev_time = time
          end
        end
        # Here's a possible way to break streams of points into
        # line point arrays:
        # a.chunk{|e| e ? true : nil }.map{|_,v| v}
        channel_points.each do |points|
          render.add(
            Line[ :points, points ],
            Style[ :stroke, "blue", :strokewidth, 0.2 ]
          )
        end
        render.end
      else
        raise RuntimeError, "Unknown SVG engine: #{options[:engine].inspect}"
      end
    end

  end
end

