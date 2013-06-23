module AE



class Animation



# Keep track of all currently available instances.
# Draw all those instances that belong to the model from which the draw request comes.
@@instances = {}
def self.draw(view)
  if @@instances[view.model]
    @@instances[view.model].each{ |instance|
      instance.draw(view)
    }
  end
end



@@transformation_identity = Geom::Transformation.new()
@@draw_methods = [:draw, :draw2d, :draw_line, :draw_lines, :draw_points, :draw_polyline]
attr_reader :finished
alias_method :finished?, :finished



# Create an instance for the given drawing operations.
# @param [Array<Array>] drawing_operations each drawing operation is an array of
#   the method's name (as Symbol) and its arguments
def initialize(view, drawing_operations)
  @view = view
  @drawing_operations = drawing_operations
  @default_properties = {
    :duration => 0,
    :repeat => 1,
    :color => Sketchup::Color.new("black"),
    :alpha => 1.0,
    :line_width => 1,
    :easing => :linear,
  }
  @current_properties = @default_properties.clone # TODO: deep clone?
  @queue = []
  @time_started = nil
  @time_end = Time.at(0)
  @finished = false
end



# A method to register new animation properties for the drawing operations.
# @param [Hash] properties
# @return self
def animate(properties)
  raise ArgumentError unless properties.is_a?(Hash)
  # Validation: Here we clean up the input and normalize input alternatives.
  # If a color string is given, turn it into a Sketchup::Color (for easier blending)
  if properties.include?(:color)
    if properties[:color].is_a?(Hash)
      properties[:color][:from] = Sketchup::Color.new(properties[:color][:from]) if properties[:color].include?(:from) && !properties[:color][:from].is_a?(Sketchup::Color)
      properties[:color][:to] = Sketchup::Color.new(properties[:color][:to]) if properties[:color].include?(:to) && !properties[:color][:to].is_a?(Sketchup::Color)
    elsif !properties[:color].is_a?(Sketchup::Color)
      properties[:color] = Sketchup::Color.new(properties[:color])
    end
  end
  # Convert alpha values between 0..255 to 0.0..1.0
  if properties.include?(:alpha)
    if properties[:alpha].is_a?(Hash)
      properties[:alpha][:from] /= 255.0 if properties[:alpha].include?(:from) && (properties[:alpha][:from].is_a?(Fixnum) || properties[:alpha][:from] > 1)
      properties[:alpha][:to] /= 255.0 if properties[:alpha].include?(:to) && (properties[:alpha][:to].is_a?(Fixnum) || properties[:alpha][:to] > 1)
    elsif !properties[:alpha].is_a?(Numeric)
      properties[:alpha] /= 255.0 if properties[:alpha] > 1
    end
  end
  # Since translation has only one argument, we allow to use it without array, and normalize both alternatives.
  if properties.include?(:translation)
    if properties[:translation].is_a?(Hash)
      properties[:translation][:from] = properties[:translation][:from].first if properties[:translation][:from].is_a?(Array)
      properties[:translation][:to] = properties[:translation][:to].first if properties[:translation][:to].is_a?(Array)
    elsif properties[:translation].is_a?(Array)
      properties[:translation] = properties[:translation].first
    end
  end
  # Add the animation to the queue.
  @queue << properties
  # Start the animation if not yet running. TODO: Does this give problems when adding several animations?
  start unless @@instances[@view.model].is_a?(Array) && @@instances[@view.model].include?(self)
  return self
rescue Exception => e
  $stderr.write(e)
end



# A method to wait before the next animation starts.
# @param [Numeric] duration
# @return self
# TODO: Should wait count after the previous animation finished, or concurrently while the previous animation is running?
def wait(duration)
  @queue << {:duration => duration, :wait => true}
  return self
end



# Start the animation and register this instance as running animation.
# @return self
def start
  @@instances[@view.model] ||= []
  @@instances[@view.model] << self
  @time_started = Time.now
  @view.invalidate
  return self
end



# Stop the animation and unregister this instance.
# @return self
def stop
  @@instances[@view.model].delete(self) if @@instances[@view.model]
  @time_started = nil
  @time_end = Time.now
  @view.invalidate
  @finished = true
  return self
end



# Get the current progress of the animation from its starting time and duration.
# @return [Float] a number between 0 and 1
def get_interpolation_factor
  s = (Time.now - @time_started) / @current_properties[:duration] % 1
  s = @@easing[@current_properties[:easing]].call(s) if @@easing.include?(@current_properties[:easing])
  return s
end
private :get_interpolation_factor



@@easing = {
  :linear => Proc.new{ |i| i },
  :quad  => Proc.new{ |i| i**2 },
  :quad2  => Proc.new{ |i| 1 - (1-i)**2 },
  :cubic => Proc.new{ |i| i**3 },
  :cubic2  => Proc.new{ |i| 1 - (1-i)**3 },
  :quartic => Proc.new{ |i| i**4 },
  :quartic2  => Proc.new{ |i| 1 - (1-i)**4 },
  :quintic => Proc.new{ |i| i**5 },
  :quintic2  => Proc.new{ |i| 1 - (1-i)**5 },
  :swing => Proc.new{ |i| 0.5 - Math.cos( i * Math::PI ) / 2.0 },
  :gauss => Proc.new{ |i| Math.exp( -0.5 * (6 * i - 3)**2 ) },
  :elastic => Proc.new{ |i| (i == 0 || i == 1) ? i : -2**(8 * (i - 1) ) * Math.sin( ( (i - 1) * 80 - 7.5 ) * Math::PI / 15.0 ) },
  :bounce => Proc.new{ |i| # goes out of 0..1
    pow2 = 0
    bounce = 4
    nil while ( i < ( ( pow2 = 2**(bounce -= 1) ) - 1 ) / 11 )
    i = 1 / 4**(3 - bounce) - 7.5625 * (( pow2 * 3 - 2 ) / 22 - i)**2
  },
}
# Helper method to interpolate two numeric values with an optional easing function.
# @param [Numeric] a the start value
# @param [Numeric] b the end value
# @param [Float]  i the interpolation step
# @param [Symbol] easing # TODO: eventually support also custom easing functions as Proc
def interpolate(a, b, i, easing=nil)
  i = (@@easing[easing] || @@easing[:linear]).call(i)
  return b * i + a * (1 - i)
end
private :interpolate



# Draw method, called the corresponding class method and by SketchUp.
# @param [Sketchup::View] view
def draw(view=@view)
  # Manage start and end

  # Before animation
  if !@time_started || Time.now < @time_started
    return # and wait for start # TODO: problem: This method is only triggered by view.invalidate.
  # Start the next transition
  elsif !@queue.empty? && Time.now >= @time_end
    properties = @queue.shift
    # Wait
    if properties[:wait]
      duration = properties[:duration] || 0
      @time_started = Time.now + duration
      @time_end = Time.now + duration
      UI.start_timer(duration, false) { view.invalidate }
      return
    end
    # Normal: merge properties over current properties
    # If only :to is given, take the previous status as new start value.
    @current_properties.merge!(properties) { |key, old_val, new_val|
      if old_val.is_a?(Hash) && old_val[:to] && new_val.is_a?(Hash)
        old_val[:from] = old_val[:to]
        old_val.merge(new_val)
      else
        new_val
      end
    }
    @time_started = Time.now
    @time_end = @time_started + @current_properties[:duration] * (@current_properties[:repeat]||1)
  # When the time has passed, stop the animation and start a succeeding animation if available.
  elsif Time.now >= @time_end && @queue.empty?
    return stop
  end

  # Interpolate properties
  s = get_interpolation_factor()
  transformation = @@transformation_identity

  # Translation
  if @current_properties[:translation]
    if @current_properties[:translation].is_a?(Hash) && @current_properties[:translation][:from] && @current_properties[:translation][:to]
      s1 = (@@easing[@current_properties[:translation][:easing]] || @@easing[:linear]).call(s)
      translation = Geom::Vector3d.linear_combination(1-s1, @current_properties[:translation][:from], s1, @current_properties[:translation][:to])
      transformation *= Geom::Transformation.translation(translation)
    # Static (no interpolation)
    elsif @current_properties[:translation].is_a?(Geom::Vector3d)
      transformation *= Geom::Transformation.translation(@current_properties[:translation])
    end
  end

  # Scaling
  if @current_properties[:scaling]
    if @current_properties[:scaling].is_a?(Hash) && @current_properties[:scaling][:from] && @current_properties[:scaling][:to]
      scaling = []
      @current_properties[:scaling][:from].each_with_index{ |a, i|
        scaling[i] = a.is_a?(Numeric) ? interpolate(a, @current_properties[:scaling][:to][i], s) : a
      }
      transformation *= Geom::Transformation.scaling(*scaling)
    elsif @current_properties[:scaling].is_a?(Array)
      transformation *= Geom::Transformation.scaling(*@current_properties[:scaling])
    end
  end

  # Rotation
  if @current_properties[:rotation]
    if @current_properties[:rotation].is_a?(Hash) && @current_properties[:rotation][:from] && @current_properties[:rotation][:to]
      rotation = []
      @current_properties[:rotation][:from].each_with_index{ |a, i|
        rotation[i] = a.is_a?(Numeric) ? interpolate(a, @current_properties[:rotation][:to][i], s) : a
      }
      transformation *= Geom::Transformation.rotation(*rotation)
    elsif @current_properties[:rotation].is_a?(Array)
      transformation *= Geom::Transformation.rotation(*@current_properties[:rotation])
    end
  end

  # Transformation object
  transformation *= Geom::Transformation.interpolate(@current_properties[:transformation], @@transformation_identity, s) if @current_properties[:transformation]
  if @current_properties[:transformation]
    if @current_properties[:transformation].is_a?(Hash) && @current_properties[:transformation][:from] && @current_properties[:transformation][:to]
      transformation *= Geom::Transformation.interpolate(@current_properties[:transformation][:from], @current_properties[:transformation][:to], s)
    elsif @current_properties[:transformation].is_a?(Geom::Transformation)
      transformation *= Geom::Transformation.interpolate(@current_properties[:transformation], @@transformation_identity, s)
    end
  end

  # Color and alpha
  if @current_properties[:color]
    if @current_properties[:color].is_a?(Hash) && @current_properties[:color][:from] && @current_properties[:color][:to]
      s1 = (@@easing[@current_properties[:color][:easing]] || @@easing[:linear]).call(s)
      color = @current_properties[:color][:to].blend(@current_properties[:color][:from], s1)
      color.alpha = @current_properties[:alpha].is_a?(Hash) ? interpolate(@current_properties[:alpha][:from], @current_properties[:alpha][:to], s, @current_properties[:alpha][:easing]) : @current_properties[:alpha]
      view.drawing_color = color
    elsif @current_properties[:color].is_a?(Sketchup::Color)
      color = @current_properties[:color]
      color.alpha = @current_properties[:alpha].is_a?(Hash) ? interpolate(@current_properties[:alpha][:from], @current_properties[:alpha][:to], s, @current_properties[:alpha][:easing]) : @current_properties[:alpha]
      view.drawing_color = color
    end
  end

  # Line width
  if @current_properties[:line_width]
    if @current_properties[:line_width].is_a?(Hash) && @current_properties[:line_width][:from] && @current_properties[:line_width][:to]
      view.line_width = interpolate(@current_properties[:line_width][:from], @current_properties[:line_width][:to], s) #.to_i
    elsif @current_properties[:line_width].is_a?(Numeric)
      view.line_width = @current_properties[:line_width]
    end
  end

  # Interpolate arguments of drawing operations and call each.
  @drawing_operations.each{ |array|
    begin
      method = array.first
      args = array[1..-1]
      if !transformation.identity? && @@draw_methods.include?(method)
        # Transformation
        args.map!{ |arg|
          arg = arg.transform(transformation) if arg.is_a?(Geom::Point3d) #|| arg.is_a?(Geom::Vector3d) # TODO
          arg = arg.map{ |b| (b.respond_to?(:transform)) ? b.transform(transformation) : b } if arg.is_a?(Array)
          arg
        }
      elsif method == :drawing_color= # TODO: remove this
        # Color blending
        #args[0] = Sketchup::Color.new(args[0]) unless args[0].is_a?(Sketchup::Color)
        #args[0] = args[0].blend(@current_properties[:color], s) if @current_properties[:color]
        # Alpha blending
        #args[0].alpha = ((1 - s)*args[0].alpha + s*@current_properties[:alpha]).to_i if @current_properties[:alpha]
      elsif method == :line_width=
        # Line width
        #args[0] = ((1 - s)*args[0] + s*@current_properties[:line_width]).to_i
      end
      view.send(method, *args)
    rescue Exception => e
      $stderr.write(e)
      next
    end
  }
  view.invalidate
end



end # class Animation



end # module AE
