require "Animation.rb"



module AE



class AnimationTestTool



def initialize
  @first_point = nil
  @ctrl = false
  @shift = false
end



def onKeyDown(key, repeat, flags, view)
  @ctrl = true if key == COPY_MODIFIER_KEY # VK_CONTROL
  @shift = true if key == CONSTRAIN_MODIFIER_KEY # VK_SHIFT
end



def onKeyUp(key, repeat, flags, view)
  @ctrl = false if key == COPY_MODIFIER_KEY # VK_CONTROL
  @shift = false if key == CONSTRAIN_MODIFIER_KEY # VK_SHIFT
end



def onLButtonDown(flags, x, y, view)
  hit = view.model.raytest(view.pickray(x, y))
  return @first_point = nil if hit.nil? || hit.empty?
  @first_point = hit.first
end



def onLButtonUp(flags, x, y, view)

  # Example: Arrow
  if !@ctrl
    return if @first_point.nil?
    hit = view.model.raytest(view.pickray(x, y))
    return @first_point = nil if hit.nil? || hit.empty?
    p1 = hit.first
    p = @first_point
    @first_point = nil
    normal = (hit[1].last.is_a?(Sketchup::Face)) ? hit[1].last.normal : Z_AXIS
    # Get a vector of the direction in which the mouse cursor was dragged.
    vector = normal * p.vector_to(p1) * normal
    normal = (hit[1].last.is_a?(Sketchup::Face)) ? hit[1].last.normal : Z_AXIS
    return unless vector.valid?

    # Circle
    segments = 24
    r_inner = r = vector
    r_outer = r_inner.clone; r_outer.length *= 1.2
    t = Geom::Transformation.new(p, normal, 2*Math::PI/segments)
    circle = [p + r_inner, p + r_outer]
    (1..segments).each{ |i|
      p1 = circle[-2].transform(t)
      p2 = circle[-1].transform(t)
      circle.push(p1, p2)
    }

    # Arrow
    w = normal * r; w.length = 0.20 * r.length
    h = r.clone; h.length *= 0.15
    arrow = [p+r, p+h+w+w, p+h+w, p-r+w, p-r-w, p+h-w, p+h-w-w, p+r]

    # Draw it and animate it:
    Animation.new(view, [
      [:draw, GL_QUAD_STRIP, circle],
    ]).
    animate({
      :color => {
        :from => "yellow",
        :to => "orange",
        :easing => :gauss
      },
      # Scale it bigger (around the center point)
      :scaling => { :from => [p, 0], :to => [p, 2] },
      :alpha => { :from => 0.0, :to => 1.0, :easing => :gauss },
      :duration => 2
    })

    Animation.new(view, [
      [:draw, GL_POLYGON, arrow],
    ]).
    wait(0.5).
    animate({
      :color => {
        :from => "yellow",
        :to => "lime",
        :easing => :gauss
      },
      # Move it "through" the circle
      :translation => { :from => vector.reverse - vector, :to => vector + vector, :easing => :linear },
      :alpha => { :from => 0.0, :to => 1.0, :easing => :gauss },
      :duration => 1
    })



  # Example: Fireworks
  else
    return if @first_point.nil?
    hit = view.model.raytest(view.pickray(x, y))
    return @first_point = nil if hit.nil? || hit.empty?
    p1 = hit.first
    p = @first_point
    @first_point = nil
    # Get a vector of the direction in which the mouse cursor was dragged.
    vector = p.vector_to(p1)
    vector = Geom::Vector3d.new(rand, rand, 0) unless vector.valid?
    # Get the maximum height of the fireworks:
    # tilted in dragged direction, minimum height 100 screen pixels
    z = Geom::Vector3d.new(0, 0, 2 + 2*rand) + vector.normalize
    z.length *= [view.pixels_to_model(100, p), vector.length].max
    # Get a random color.
    color = Sketchup::Color.new(rand, rand, rand, 255)

    # Rays: 20 - 25 rays
    (20+rand(5)).times{
      # Radius
      r = Geom::Vector3d.new(rand-0.5, rand-0.5, rand-0.5) * z
      r.length = [100, 0.25 * vector.length].max
      t = Geom::Transformation.new(p + r, r.axes.x, 5.degrees)
      curve = [p]
      (3 + rand(3)).times{
        curve << curve[-1].transform(t)
      }

      # Draw it and animate it:
      Animation.new(view, [
        [:draw, GL_LINE_STRIP, curve[-2..-1]],
        [:line_width=, 3],
        [:draw, GL_LINE_STRIP, curve[-[4, curve.length].min..-1]],
        [:line_width=, 2],
        [:draw, GL_LINE_STRIP, curve[-[3, curve.length].min..-1]],
        [:line_width=, 1],
        [:draw, GL_LINE_STRIP, curve]
      ]).
      # Add a random delay to have more variation.
      wait(0.1*rand).
      animate({
        :color => {
          :from => Sketchup::Color.new(255, 255, 64, 255),
          :to => color,
          :easing => :cubic2
        },
        :line_width => { :from => 1, :to => 5, :easing => :cubic },
        # Move the ray vertically, at the beginning fast and then slower
        :translation => { :from => Geom::Vector3d.new(0,0,0), :to => z, :easing => :cubic2 },
        # Rotate the ray outwards, with varying angle
        :rotation => { :from => [p + r, r.axes.x, 0], :to => [p + r, r.axes.x, (90 + 90*rand).degrees], :easing => :quintic },
        :alpha => { :from => 0.5, :to => 1.0, :easing => :cubic },
        :duration => 3
      })

    } # times

  end # if @ctrl

end



# Example: Colored stars
def onLButtonDoubleClick(flags, x, y, view)
  hit = view.model.raytest(view.pickray(x, y))
  return if hit.nil? || hit.empty?
  p = hit.first
  normal = (hit[1].last.is_a?(Sketchup::Face)) ? hit[1].last.normal : Z_AXIS

  # Star
  segments = 24
  r = normal.axes.y; r.length = view.pixels_to_model(100, p)
  r2 = r.clone; r2.length *= 1.2
  t = Geom::Transformation.new(p, normal, 2*Math::PI/segments)
  circle = [p + r, p + r2]
  star = [p + r, p + r2]
  (1..segments).each{ |i|
    p1 = circle[-2].transform(t)
    p2 = circle[-1].transform(t)
    circle.push(p1, p2)
    # Alternating number to push points inwards/outwards.
    j = 0.25 * (i%2)
    p1 = Geom.linear_combination(1-j, p1, j, p)
    p2 = Geom.linear_combination(1-j, p2, j, p)
    star.push(p1, p2)
  }

  # Draw it and animate it:
  Animation.new(view, [
    [:draw, GL_QUAD_STRIP, star],
  ]).
  animate({
    :color => {
      :from => "yellow",
      :to => "red"
    },
    :scaling => { :from => [p, 0], :to => [p, 2] },
    :rotation => { :from => [p, normal, -90.degrees], :to => [p, normal, 90.degrees] },
    :alpha => { :from => 0.0, :to => 1.0, :easing => :linear },
    :duration => 3,
    :repeat => 1,
  }).
  animate({
    :color => {
      :from => "red",
      :to => "blue"
    },
    :scaling => { :from => [p, 2], :to => [p, 0] },
    :rotation => { :from => [p, normal, -90.degrees], :to => [p, normal, 90.degrees] },
    :alpha => { :from => 1.0, :to => 0.0, :easing => :linear },
    :duration => 3,
    :repeat => 1,
  }).
  animate({
    :color => {
      :from => "blue",
      :to => "green"
    },
    :scaling => { :from => [p, 0], :to => [p, 3] },
    :rotation => { :from => [p, normal, -30.degrees], :to => [p, normal, 30.degrees] },
    :alpha => { :from => 0.0, :to => 0.5, :easing => :gauss },
    :duration => 1,
    :repeat => 2,
  })

end



def draw(view)
  Animation.draw(view)
end



end # class AnimationTestTool



unless file_loaded?(__FILE__)
  cmd = UI::Command.new("Animation Test Tool") { Sketchup.active_model.select_tool(AE::AnimationTestTool.new) }
  cmd.tooltip = "Tool to demonstrate OpenGL animation/interpolation effects."
  cmd.status_bar_text = "Try left dragging, ctrl and left dragging, or double clicking."
  UI.menu("Plugins").add_item(cmd)
  file_loaded(__FILE__)
end



end # module AE
