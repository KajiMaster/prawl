require "rect"

module DungeonCreator

	def split( rect, direction )
		limit = 3+rand(3)
		if rand > 0.5
			child = rect.split_rand(direction, limit, limit)
		else
			child = rect.split_half(direction, limit, limit)
		end
		return unless child
		if direction == :vertical
			partition = Rect.new( rect.x, rect.y+rect.h, rect.w, 1 )
		elsif direction == :horizontal
			partition = Rect.new( rect.x+rect.w, rect.y, 1,rect.h )
		end

		invert_direction = ( direction == :vertical ? :horizontal : :vertical )

		@partitions << partition

		@rect_to_partition ||= {}
		@rect_to_partition[rect] ||= {}
		@rect_to_partition[child] ||= {}

		@rect_to_partition[rect][direction] = partition

		@rect_to_partition[child][direction] = partition
		@rect_to_partition[child][invert_direction] = @rect_to_partition[rect][invert_direction]

		@rects << child
		split( rect, invert_direction )
		split( child, invert_direction )
	end

	def flooring(rects, v)
		rects.each{|r|
			r.w.times{|x|
				r.h.times{|y|
					to_floor x+r.x, y+r.y, v
				}
			}
		}
	end

	def walling(rects, v)
		rects.each{|r|
			r.w.times{|x|
				r.h.times{|y|
					to_wall x+r.x, y+r.y, v
				}
			}
		}
	end

	def create_dungeon
		@rects = [ Rect.new(0,0, w, h) ]
		@partitions = []
		split( @rects.first, rand < 0.5 ? :vertical : :horizontal )

		rooms = []
		routes = []

		@rects.each{|r|
			room = r.inside_rand
			rooms << room
			if @rect_to_partition[r][:horizontal]
				routes << room.connect( @rect_to_partition[r][:horizontal] )
			end
			if @rect_to_partition[r][:vertical]
				routes << room.connect( @rect_to_partition[r][:vertical] )
			end
		}

		flooring rooms, 1
		flooring routes, 2
		flooring @partitions, 3

		cut_partition_edge
		make_staircases
	end

	def make_staircases
		3.times{|i|
			loop do
				x = rand(w)
				y = rand(h)
				unless blocked?( x, y )
					to_downstair(x,y,i)
					break
				end
			end
		}
		3.times{|i|
			loop do
				x = rand(w)
				y = rand(h)
				unless blocked?( x, y )
					to_upstair(x,y,i)
					break
				end
			end
		}
	end

	def cut_partition_edge
		@partitions.each{|pa|
			if pa.w == 1
				if pa.y == 0
					pa.h.times{|dh|
						unless blocked?( pa.x-1, dh ) and blocked?( pa.x+1, dh )
							walling [ Rect.new( pa.x, pa.y, 1, dh ) ], 0
							break
						end
					}
				end
				if pa.y+pa.h == h
					(h-1).downto(pa.y){|dy|
						unless blocked?( pa.x-1, dy ) and blocked?( pa.x+1, dy )
							walling [ Rect.new( pa.x, dy+1, 1, h-dy-1 ) ], 0
							break
						end
					}
				end
			else
				if pa.x == 0
					pa.w.times{|dw|
						unless blocked?( dw, pa.y-1 ) and blocked?( dw, pa.y+1 )
							walling [ Rect.new( pa.x, pa.y, dw, 1 ) ], 0
							break
						end
					}
				end
				if pa.x+pa.w == w
					(w-1).downto(pa.x){|dx|
						unless blocked?( dx, pa.y-1 ) and blocked?( dx, pa.y+1 )
							walling [ Rect.new( dx+1, pa.y, w-dx-1, 1 ) ], 0
							break
						end
					}
				end
			end
		}
	end
end