require "sdl"

class Tile
  attr_accessor :name, :positions, :surface

  def initialize(config)
  	@positions = []
		@positions = config["tiles"]
		@surface = SDL::Surface.load( "resources/"+config["filename"] )
		if( config["colorkey"] )
			color = surface.getPixel( config["colorkey"][0], config["colorkey"][1] )
			surface.set_color_key( SDL::SRCCOLORKEY, color )
			surface.set_alpha( 0,0 )
		end
	end

	def self.get(name)
		unless $tiles
			$tiles = {}
			tile_configs = JSON.parse File.read("data/tile.json")
			tile_configs.each{|k,v|
				$tiles[ k ] = Tile.new v
			}
		end
		$tiles[ name ]
	end

	def self.blit_to( target_surface, dx, dy, config )
		t = Tile::get( config[0] )
		
		if config.size == 2
			t.blit( target_surface, config[1], dx, dy )
		elsif config.size == 3
			SDL::Surface.blit( t.surface, config[1], config[2],
				32, 32,	target_surface, dx, dy )
		elsif config.size == 4
			SDL::Surface.blit( t.surface, config[1]*config[3], config[2]*config[3],
				config[3], config[3],	target_surface, dx, dy )
		elsif config.size == 7
			SDL::Surface.blit( t.surface, config[1], config[2],
				config[3], config[4],	target_surface, dx+config[5], dy+config[6] )
		end
	end

	def blit( target_surface, number, x, y )
		case positions[number].size
			when 2
				SDL::Surface.blit( surface, positions[number][0], positions[number][1], 32,32,
					target_surface, x, y )
			when 4
				SDL::Surface.blit( surface, positions[number][0], positions[number][1], 
					positions[number][2], positions[number][3],
					target_surface, x, y )
			when 6
				SDL::Surface.blit( surface, positions[number][0], positions[number][1], 
					positions[number][2], positions[number][3],
					target_surface, x+positions[number][4], y+positions[number][5] )
		end
	end

end