require 'xrvg'

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
      4
    end

    def yoffset
      -40
    end

    def guidelines(state)
      @guidelines = state
    end

    def xy(time, value, channel_index)
      if value == true
        y = -1
      elsif value == false
        y = 1
      else
        y = 0
      end
      V2D[time, (y + yoffset + channel_index*6) * yscale]
    end

    def write_svg(filename)
      render = SVGRender[ :filename, filename, :imagesize, '1250px' ]
      x = @samples.earliest
      limit = @samples.latest
      prev_time = nil
      prev_data = nil
      last_points = nil
      channel_points = @channels.count.times.map{ [] }
      each_sample do |time, data|
        if :initial == time
            prev_time = 0
          data.each_with_index do |d, c|
            channel_points[c] << xy(0, d[1], c)
          end
        else
          data.each_with_index do |p, ch_index|
            c,v = p
            p3 = xy(time, v, ch_index)
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
    end

  end
end

