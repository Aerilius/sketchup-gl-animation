sketchup-gl-animation
=====================

This class allows to animate OpenGL drawing operations in SketchUp.
You can see examples in [this video](https://vimeo.com/68927967).

## Usage
 
* _**`AE::Animation.draw(view)`**_  
  Call this in the draw method of your SketchUp tool.

* _**`AE::Animation.new(view, drawing_operations)`**_  
  with `view` as the current Sketchup::View of your tool
  and `drawing_operations` as an Array in which each drawing operation is represented as an array of the method's name (as Symbol) and its arguments
  
* _**`<AE::Animation>.animate(properties)`**_  
  with `properties` as a Hash containing
  `:duration` [Numeric]  
  `:repeat`   [Numeric] how often to repeat this animation within duration  
  `:easing`   [Symbol]  one of `:linear`, `:quad`, `:quad2`, `:cubic`, `:cubic2`, `:quartic`, `:quartic2`, `:quintic`, `:quintic2`, `:swing`, `:gauss`, `:elastic`, `:bounce`  
  The following properties can also have a Hash assigned with a start value `:from`, end value `:to` and optionally an easing.  
  `:color`    [String, Sketchup::Color]  
  `:alpha`    [Fixnum<0..255>, Float<0.0..1.0>]  
  `:line_width`  [Fixnum]  
  `:transformation` [Geom::Transformation]  
  `:translation`    [Geom::Vector3d]  
  `:scaling`        [Array] with arguments of SketchUp's `Geom::Transformation.scaling` method  
  `:rotation`       [Array] with arguments of SketchUp's `Geom::Transformation.rotation` method  

* _**`<AE::Animation>.wait(duration)`**_  
  with `duration` as a Number of how many seconds to wait.
  
## Example

    Animation.new(view, [
      [:draw, GL_POLYGON, circle],
    ]).
    animate({
      :color => {
        :from => "yellow",
        :to => "orange",
        :easing => :gauss
      },
      :scaling => { :from => [p, 0], :to => [p, 2] },
      :alpha => { :from => 0.0, :to => 1.0, :easing => :gauss },
      :duration => 2
    })
