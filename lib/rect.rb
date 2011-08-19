require "sdl"

class Rect
  attr_accessor :x,:y,:w,:h

  def initialize(x,y,w,h)
  	@x = x
  	@y = y
  	@w = w
  	@h = h
  end

	def conflict(x,y)
		@x <= x and x <= @x+@w and @y <= y and y <= @y+@h
	end

	def inside_rand
		return nil if w-2 <= 0 or h-2 <= 0
		r = Rect.new( 0,0, 1+rand(w-2).to_i, 1+rand(h-2).to_i )
		r.x = x+1+rand(w-r.w-1).to_i
		r.y = y+1+rand(h-r.h-1).to_i
		r
	end

	def split_half( direction, width_limit, height_limit )
		return nil if w < width_limit*2+1 or h < height_limit*2+1

		if direction == :vertical
			return split_vertical h/2
		elsif direction == :horizontal
			return split_horizontal w/2
		end
	end

	def split_rand( direction, width_limit, height_limit )
		return nil if w < width_limit*2+1 or h < height_limit*2+1

		if direction == :vertical
			return split_vertical height_limit + rand(h-height_limit*2).to_i
		elsif direction == :horizontal
			return split_horizontal width_limit + rand(w-width_limit*2).to_i
		end
	end

	def split_vertical( line )
		r = Rect.new( @x, @y+line, @w, @h-line )
		@h = line
		return r
	end

	def split_horizontal( line )
		r = Rect.new( @x+line, @y, @w-line, @h )
		@w = line
		return r
	end

	def connect(r)
		if r.w < r.h # :vertical
			if (@x - r.x).abs < (@x+@w - r.x).abs #left side
				Rect.new( r.x, @y+rand(@h), @x-r.x, 1 )
			else # right side
				Rect.new( @x+@w, @y+rand(@h), r.x - @x-@w, 1 )
			end
		else # :horizontal
			if (@y - r.y).abs < (@y+@h - r.y).abs # top side
				Rect.new( @x+rand(@w), r.y, 1, @y-r.y )
			else # bottom_side
				Rect.new( @x+rand(@w), @y+@h, 1, r.y - @y-@h )
			end
		end
	end

	def fill(target_surface,color)
		target_surface.fill_rect( x, y, w, h, color )
	end
end