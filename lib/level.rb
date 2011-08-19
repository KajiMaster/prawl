require "grid"
require "rect"
require "util"
require "item"
require "dungeon_creator"
require "map"
require "monster"

class Level
	include Util
	include DungeonCreator

  attr_accessor :w,:h, :mini_map, :grid, :monsters, :level, :tile_group, :mini_map
	TILE_SIZE=8

	def blit( target_surface, x, y, grid )
		Tile.blit_to( target_surface, x, y,
			tile_config( grid.type, grid.number ) )
	end

	def message( m, gsub_list={} )
		Crawl.logging messages["level"][m.to_s], gsub_list
	end

	def to_h
		{
			tile_group: tile_group,
			w: w, h: h,
			grid: grid.to_a,
			items: @items.to_h,
			monsters: monsters.map{|m| m.to_h}
		}
	end

	def tile_config( type, number )
		Dungeon.config["groups"][tile_group][type.to_s][number]
	end

	def random_tile( type )
		tile_number = rand( Dungeon.config["groups"][tile_group][type.to_s].size ).to_i
		return type, tile_number
	end

  def initialize( level )
  	@level = level
	end

	def make_minimap
		@mini_map = new_surface( w*TILE_SIZE, h*TILE_SIZE )
		colors = { :wall=>gray, :floor=>ivory, :ladder_down=>cyan }		
		w.times{|x|
			h.times{|y|
				c = colors[ grid[x,y].type ]
				@mini_map.fill_rect( x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE, c)
				@mini_map.draw_rect( x*TILE_SIZE, y*TILE_SIZE, TILE_SIZE, TILE_SIZE, black)
			}
		}
	end

	def load(save_data)
		@tile_group = save_data["tile_group"]
		@w = save_data["w"]
		@h = save_data["h"]
		@grid = Map.new(w,h)
		@items = Map.new(w,h)

		save_data["grid"].each.with_index{|row,y|			
			row.each.with_index{|g,x|
				grid[x,y] = Grid.new( g[0], g[1] )
			}
		}

		@monsters = []
		save_data["monsters"].each{|m|
			@monsters << Monster.load(m)
		}

		save_data["items"].each{|k,v|
			y = k.to_i / w
			x = k.to_i % w
			v.each{|item|
				@items[x,y] ||= []
				@items[x,y] << Item.new( item["type"], item["id"] )
			}
		}
		make_minimap
	end

	def new_level
  	@tile_group = Dungeon.config["default_group"]
		Dungeon.config["dungeon"].each{|d|
			if d["level"][0] <= level and level <= d["level"][1]
				@tile_group = d["group"]
				break
			end
		}

		@w = 40+rand(40)
		@h = 40+rand(40)
		@grid = Map.new(w,h)
		@items = Map.new(w,h)
		@monsters = []

		h.times{|y|
			w.times{|x|
				grid[x,y] = Grid.new *random_tile(:wall)
			}
		}

		create_dungeon

		# make items
		( 3 + roll_dice(3,11) ).times{
			loop do
				x=rand(w)
				y=rand(h)
				unless blocked?( x, y )
					i = Item.create_random
					item_drop x, y, i
					if i.is_artifact?
						message :create_artifact
					end
					break
				end
			end
		}

		# make monsters
		( roll_dice(3,10) ).times{
			
			m=nil
			1000.times{
				m = Monster.new( rand( 10 ) )
				break if (m.level - level).abs <= 5
			}

			loop do
				m.x = rand(w)
				m.y = rand(h)
				break if empty_grid?(m.x, m.y)
			end

			monsters << m
		}

		print
		make_minimap
		self
  end

	def monster_at(x,y)
		monsters.find{|m| m.x==x and m.y==y}
	end

	def empty_grid?( *xy )
		( not blocked?( xy[0], xy[1] ) ) and ( not monster_at( xy[0], xy[1] ) )
	end

	def items(x,y)
		@items[x,y].to_a
	end

	def item_drop(x,y, item)
		unless item
			Crawl.logging "drop item not selected."
			return
		end
		@items[x,y] ||= []
		@items[x,y] << item
	end

	def item_pickup(x,y,n)
		@items[x,y] ||= []
		@items[x,y].delete_at n
	end

	def to_upstair(x,y,v)
	end

	def to_downstair(x,y,v)
		grid[x,y].update *random_tile(:ladder_down)
	end

	def to_wall(x,y,v)
		grid[x,y].update *random_tile(:wall)
	end

	def to_floor( x,y,v )
		grid[x,y].update *random_tile(:floor)
	end

	def blocked?(x,y)
		g = grid[x,y]
		(not g) or g.type == :wall
	end

	def print
		c_symbol = { :wall=>"#", :ladder_down=>">", :floor=>" " }	
		h.times{|y|
			line = ""
			w.times{|x|
				line << c_symbol[ grid[x,y].type ]
			}
			puts line
		}
	end
end