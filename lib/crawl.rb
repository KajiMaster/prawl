require "sdl"
require 'json'

require 'dungeon'
require 'player'
require 'tile'
require 'util'
require 'info_area'
require 'text_area'
require 'shell'

class Crawl
	include Util

	attr_accessor :s, :player, :dungeon,
								:info_area, :text_area, :shell, :fps,
								:died_shade

	LEFT_ARROW = [239, 156, 130].pack("C*").force_encoding("UTF-8")
	UP_ARROW = [239, 156, 128].pack("C*").force_encoding("UTF-8")
	DOWN_ARROW = [239, 156, 129].pack("C*").force_encoding("UTF-8")
	RIGHT_ARROW =[239, 156, 131].pack("C*").force_encoding("UTF-8")

	DIRECTION_KEYS = [
		"h","j","k","l",
		"y","u","b","n",
		LEFT_ARROW, DOWN_ARROW, UP_ARROW, RIGHT_ARROW
	]
	DIRECTIONS = {
		LEFT_ARROW => [-1,0], DOWN_ARROW => [0,1], UP_ARROW => [0,-1], RIGHT_ARROW => [1,0],
		"h"=>[-1, 0], "j"=>[ 0, 1], "k"=>[ 0,-1], "l"=>[ 1, 0],
		"y"=>[-1,-1], "u"=>[ 1,-1], "b"=>[-1, 1], "n"=>[ 1, 1],
	}
	
	def initialize
		SDL.init(SDL::INIT_VIDEO)
		@s = SDL::Screen.open(SCREEN_W, SCREEN_H, 32, SDL::HWSURFACE | SDL::DOUBLEBUF )

		files = Dir::glob("resources/illusts/*.jpg") + Dir::glob("resources/illusts/*.png")
		unless files.empty?
			opening_file = files[ rand(files.size) ]
			opening_image = SDL::Surface.load( "#{opening_file}" )
			x = (SCREEN_W-opening_image.w)/2
			y = (SCREEN_H-opening_image.h)/2
			x = 0 if x < 0
			y = 0 if y < 0
			SDL::Surface.blit(opening_image, 0, 0, opening_image.w, opening_image.h, s, x, y)
			opening_image.destroy
			s.flip
		end
	end

	def self.logging(message, gsub_list={})
		@@log ||= []
		@@log << gsub_list.inject(message){|m,l|
			m.to_s.gsub "[#{l[0].to_s}]", l[1].to_s
		}
	end

	def create_game
		SDL::Mixer.open
		SDL::TTF.init
		SDL::Event.enable_unicode

		@fps=0

		@@log = []
		@text_area = TextArea.new(@@log)
		@shell = Shell.new
		@died_shade = new_surface SCREEN_W,SCREEN_H
		died_shade.fill_rect 0,0, died_shade.w,died_shade.h, [255,0,0,128] 
		@info_area = InfoArea.new

		@mode = :walk

		opening_message = open("data/opening_message.txt").read
		opening_message.lines {|line|
			Crawl.logging( line.chomp )
		}
		
		files = Dir::glob("save/*_dat").reverse

		cy = 0
		loop do
			event = SDL::Event.poll
			case event
				when SDL::Event::KeyDown
					case event.sym

						when SDL::Key::RETURN
							break

						when SDL::Key::UP
							cy -= 1 if cy > 0

						when SDL::Key::DOWN
							cy += 1 if cy < files.size

						when SDL::Key::ESCAPE
							exit
					end
				when SDL::Event::Quit
					exit
			end
			sleep 0.01

			s.fill_rect(0,0,SCREEN_W,SCREEN_H,[0,0,0])

			print_ttf( "New Game", s, FONT_SIZE, 0  )
			files.each.with_index{|f,i|
				print_ttf( f, s, FONT_SIZE, (1+i)*FONT_SIZE  )
			}

			print_ttf( "*", s, 0, cy*FONT_SIZE  )

			s.flip
		end

		if cy > 0 
			$save_dir = files[cy-1]
			p $save_dir
		end
		p "#{$save_dir}/dungeon.json"
		if File.exist?("#{$save_dir}/dungeon.json")
			p "LOAD"
			@dungeon = Dungeon.new
			dungeon.load
			@player = Player.new dungeon
			player.load JSON.parse File.read "#{$save_dir}/#{Player.config['name']}.json"
		else
			p "NEW GAME"
			@dungeon = Dungeon.new
			@player = Player.new( dungeon )
			player.init_with_default
			player.entering_new_level

			$save_dir = Time.now.strftime "save/%Y%m%d_%H%M%S_dat"
			Dir::mkdir $save_dir
		end

		update
	end

	def update
		s.fill_rect(0,0,SCREEN_W,SCREEN_H,[0,0,0])

		player.draw_map s

		player.fov.each{|f|
			if i = player.current_level.items( f[0], f[1] ).last
				ix = (f[0]-player.x)*32+CENTER_X
				iy = (f[1]-player.y)*32+CENTER_Y
				i.blit( s, ix, iy )
			end

			if m = level.monster_at( f[0], f[1] )
				mx = (m.x-player.x)*32+CENTER_X
				my = (m.y-player.y)*32+CENTER_Y
				m.blit( s, mx, my )
			end
		}

		s.put( player.s, CENTER_X, CENTER_Y )	
		s.put( player.fov_shade, 0,0 )

		info_area.update( player, @fps )
		s.put( info_area.s, SCREEN_W-info_area.s.w-5, 5)

		shell.blit_to(s)

		text_area.update
		s.put text_area.s, 4, SCREEN_H-text_area.	s.h-4

		if player.enable_minimap
			SDL::Surface.transform_blit( player.mini_map,s,0,4,4, 0,0,10,10, 0)
			#s.put( player.current_level.mini_map, 0, 0)
		end

		case @mode
			when :examine
				Tile.blit_to( s, (@cursor_x-player.x)*32+CENTER_X, (@cursor_y-player.y)*32+CENTER_Y,
					player.config["cursor"] )
			when :inventory
				player.inventory.put s, 10, 10
			when :gameover
				died_shade.fill_rect 0,0, died_shade.w,died_shade.h, [ 255-@died_count, 0,0, @died_count]
				s.put died_shade,0,0
		end

		s.flip
	end

	def level
		player.current_level
	end

	def examine_input(event)
		key = event.unicode.chr("UTF-8")

		case key
			when "\e"
				@mode = :walk

			when *DIRECTION_KEYS
				@cursor_x += DIRECTIONS[key][0]
				@cursor_y += DIRECTIONS[key][1]
				puts player.current_level.grid( @cursor_x, @cursor_y )
	
			when "v"
				if m = level.monster_at( @cursor_x, @cursor_y )
					Crawl.logging "#{m.name} - #{m.desc}"
				end
				
		end
	end

	def walk_input(event)
		key = event.unicode.chr("UTF-8")

		if SDL::Key.mod_state & SDL::Key::MOD_CTRL and key == "5"
			key = "ctrl+5"
		end

		case key
			when "ctrl+5"
				@auto_rest_count = 0
				@mode = :auto_rest

			when "\e"
				puts "ESC key"

			when 'Q'
				player.save
				exit

			when 'S'
				player.save

			when 'x', "X"
				p "examine"
				@cursor_x = player.x
				@cursor_y = player.y
				@mode = :examine

			when "\r"
				player.enable_minimap = player.enable_minimap ? false : true

			when "i","P","R","t","W","w","d","e","q"
				imode = {
					"i" => :inventory_check,
					"P" => :puton_jewellery_select,
					"R" => :remove_jewellery_select,
					"t" => :takeoff_wear_select,
					"W" => :wear_select,
					"w" => :weapon_select,
					"d" => :drop_select,
					"e" => :select_ration,
					"q" => :select_potion
				}
				player.inventory.start_item_select imode[key]
				@mode = :inventory

			when "g"
				return player.pickup

			when *DIRECTION_KEYS
				dx = player.x+DIRECTIONS[key][0]
				dy = player.y+DIRECTIONS[key][1]
				return false if player.current_level.blocked?( dx, dy )
				player.move_to(dx,dy)
				return true

			when "<"
				if player.current_level.grid( player.x, player.y ).type == :ladder_up
					Crawl.logging "You climb upwards."
				else
					Crawl.logging "You can't go up here!"
				end
				
			when ">"
				player.climb_downwards

			when "."
				player.rest
				return true
		end
		return false
	end
	
	def play( event )
		case @mode
			when :gameover
				@died_count += 8
				@died_count = 231 if @died_count > 231
				@turn_end = true

			when :walk
				@turn_end = walk_input(event)

			when :examine
				examine_input(event)

			when :inventory
				@turn_end = player.inventory.input(event)
				unless player.inventory.mode
					@mode = :walk
				end
		end
	end

	def player_turn
		event = SDL::Event.poll

		if @mode == :auto_rest
			if player.monster_in_fov? or @auto_rest_count > 100
				@mode = :walk
				@auto_rest_count = 0
				@need_update = true
			else
				@auto_rest_count += 1
				player.rest
				@need_update = false
				@turn_end = true
			end
			return
		end
		
		case event
			when SDL::Event::KeyDown
				@need_update = true
				play event
			when SDL::Event::Quit
				player.save
				exit
		end
	end

	def update_monster(m)
		m.move(player) if m.hp > 0
		m.spent -= 10 if m.hp > 0
	end

	def turn
		if player.spent >= 10 and not @turn_end or player.hp <= 0
			player_turn
		end
		if @turn_end
			level.monsters.each{|m|
				if m.spent >= 10
					update_monster m
					something_happen = true
				end
			}
			level.monsters.reject!{|m| m.hp <= 0 }
			if player.hp <= 0 and @mode != :gameover
				@mode = :gameover
				@died_count = 32
				player.die
				@need_update = true
			end
		end
	end

	def step
		if player.spent >= 10 or level.monsters.any?{|m| m.spent >= 10 }
			turn
		else
			player.spent += player.speed if player.hp > 0
			level.monsters.each{|m|
				m.spent += m.speed
			}
			@turn_end = false
		end
	end
	
	def run
		last_msec = SDL.getTicks-1000
		count = 0
		need_update = true

		loop do
			frame_start_at = SDL.getTicks		

			step

			@need_update = true if shell.update?( self )

			if @need_update
				update
				@need_update = false
			end

			count += 1
		
			if SDL.getTicks - last_msec >= 1000
				@fps = count		
				last_msec = SDL.getTicks
				count = 0
				@need_update = true
			end

			SDL.delay(10)
		end
	end

end
