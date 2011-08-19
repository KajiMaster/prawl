require "sdl"
require 'player'
require 'util'

class InfoArea
	include Util

	attr_accessor :s
	
	def initialize
		@s = new_surface(300,270)
		s.fill_rect(0,0, s.w, s.h, [0,0,0,196])
	end
	
	def update( player, fps )
		fill_rect_with_frame( s, 0,0,s.w,s.h, [0,0,0,196], [0,255,128] )
		
		padding = 4
		
		print_ttf( "#{fps}FPS", s, -padding, padding )

		h = player.hp*100 / player.hp_max
		b = player.energy*100/player.energy_max

		lines = [
		["B#{player.current_level_num}F"],
		["HP: #{player.hp} / #{player.hp_max}" , h < 50 ? ( h < 25 ? red : yellow ) : white ],
		["Battery: #{b} %", b < 50 ? ( b < 25 ? red : yellow ) : white ],
		["Lv:#{player.lv} Exp:#{player.experience}"],
		["#{sprintf "%.1f",player.weight}/#{player.weight_limit} kg"],
		["STR:#{player.str} DEX:#{player.dex} INT:#{player.int} AC:#{player.effective_ac}"],
		["EV:#{player.effective_ev}" ]
		]

		lines.each.with_index{|l,i|
			print_ttf( l[0], s, padding, padding+FONT_SIZE*i, l[1] )
		}

		icon_size = 32
		by = 10+FONT_SIZE*lines.size
		bx = 10+icon_size

		categories = [:weapon,:shield,:helm,:armor,:gloves,:boots,:accessory1,:accessory2]
		categories.each.with_index{|c,i|
			if player.equipment[c]
				#player.equipment[c].thumbnail s, 10, by+icon_size*i
				player.equipment[c].blit s, 10+icon_size*i, by
			end
		}
	end

end