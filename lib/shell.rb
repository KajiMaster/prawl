require "sdl"
require 'json'

require 'util'

class Shell
	include Util
	
	attr_accessor :name
	
	def initialize
		@shell_config = JSON.parse File.read("data/surfaces.json")
		@surfaces = {}

		@name = @shell_config.first[0]

		@shell_config.each{|k,v|
			v.each.with_index{|element,i|
				unless @surfaces[ element[0] ]
					s = SDL::Surface.load( "resources/shell/master/#{element[0]}" )
					s.set_color_key( SDL::SRCCOLORKEY, s.getPixel(0,0) )
					s.set_alpha( 0,0 )
					@surfaces[ element[0] ] = s
				end
			}
		}
		@last_update = 0
		update_blink_span
	end

	def update_blink_span
		@blink_span = 3500+rand(4000)
	end

	def to(name)
		@name = name
		@last_update = SDL.getTicks
	end

	def update?(crawl)	
		if crawl.player.monster_in_fov?
			if name != "surface303"
				to "surface303"
				return true
			end
		else
			if name == "surface13"
				if SDL.getTicks > @last_update+100
					to "surface0"
					update_blink_span
					return true
				end
			elsif name == "surface0"
				if SDL.getTicks > @last_update+@blink_span
					to "surface13"
					return true
				end
			else
				to "surface0"
			end
		end
		return false
	end

	def sample
		@name = @shell_config.to_a.sample[0]
	end

	def blit_to( target_surface )
		elements = @shell_config[@name]
		bx = nil
		by = nil
		elements.each.with_index{|element,i|
			s = @surfaces[ element[0] ]
			bx ||= SCREEN_W - s.w
			by ||= SCREEN_H - s.h
			x = element[1]
			y = element[2]
			target_surface.put( s, bx+x, by+y )
		}
	end

end