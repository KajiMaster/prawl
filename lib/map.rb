class Map
	attr_accessor :w, :h

  def initialize(w,h)
  	@w = w
  	@h = h
		@grid = {}
  end

	def []( *xy )
		return nil unless inside? *xy
		@grid[ xy[1]*w+xy[0] ]
	end

	def []=( *xy, obj )
		return nil unless inside? *xy
		@grid[ xy[1]*w+xy[0] ] = obj
	end

	def inside?( *xy )
		w > xy[0] and h > xy[1] and xy[0] >= 0 and xy[1] >= 0
	end

	def marshal_grid_element(g)
		return nil unless g
		if g.is_a? Array
			return g.map{|z| z.to_h }
		end
		if g.methods.include? :to_h
			return g.to_h
		elsif g.methods.include? :to_a
			return g.to_a
		end
		g.to_s
	end

	def to_h
		r = {}
		@grid.each{|k,v|
			r[k] = marshal_grid_element v
		}
		r
	end

	def to_a
		r = []
		h.times{|y|
			r[y] = []
			w.times{|x|
				r[y][x] = marshal_grid_element self[x,y]
			}
		}
		r
	end

end