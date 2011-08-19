require "json"
require "util"
require "inventory"
require "map"
require "permissive_fov"

class Player
	include Util
	include PermissiveFieldOfView

	STATUS=[
		:hp, :hp_max, :energy, :energy_max,
		:str, :dex, :int, :lv, :experience, :ac, :ev, :regeneration_count,
		:speed, :spent,
		:x, :y, :current_level_num, :enable_minimap
	]

  ACCESSOR = STATUS +
  	[:inventory, :maps, :dungeon] +
  	[:fov, :fov_shade, :mode, :maps ] +
  	[:s, :mini_map]

  attr_accessor *ACCESSOR

	def load( save_data )
		save_data.each{|k,v|
			next if k == "inventory"
			next if k == "equipment"
			self.send k+"=", v
		}

		inventory.load save_data["inventory"]
		save_data["equipment"].each{|k,v|
			equipment[ k.intern ] = inventory.slot[v.to_i]
		}

		@maps = []
		(dungeon.levels.size-1).times{|i|
			v = JSON.parse File.read "#{$save_dir}/map_#{1+i}.json"
			@maps[1+i] = Map.new( dungeon.levels[1+i].w, dungeon.levels[1+i].h )
			v.each.with_index{|row,y|
				row.each.with_index{|c,x|
					@maps[1+i][x,y] = Grid.new c[0], c[1] if c
				}
			}
		}

		update_fov
		update
	end

	def save_json(target, file_name)
		save_file = open("#{$save_dir}/#{file_name}.json","w")
		#JSON.dump player.to_h, save_file
		save_data = JSON.pretty_generate target
		save_file.write save_data
		save_file.close
	end

	def save
		puts "save"
		save_json self.to_h, "#{name}"
		save_json dungeon.to_h, "dungeon"
		save_json current_level.to_h, "level_#{current_level_num}"
		save_json self.map.to_a, "map_#{current_level_num}"
	end

	def to_h
		h = Hash[ *(STATUS.map{|k| [ k, self.send(k) ] }.flatten) ]
		h[:inventory] = inventory.to_a
		h[:equipment] = Hash[ *( equipment.map{|k,v| [k, v ? inventory.slot.index(v) : nil] }.flatten(1) ) ]
		h
	end

	def self.config
		$player_config ||= JSON.parse File.read("data/player.json")
	end

	def config
		Player.config
	end

	def message( m, gsub_list={} )
		Crawl.logging messages["player"][m.to_s], gsub_list
	end

  def initialize( dungeon )
  	@dungeon = dungeon

		@s = new_surface(32,32)
		@mini_map_size = 50
		@mini_map = new_surface(@mini_map_size,@mini_map_size)
		@fov_shade = new_surface(SCREEN_W, SCREEN_H)

  	@fov = []
  	@inventory = Inventory.new(self)
	end

	def init_with_default
		STATUS.each{|key|
			self.send( "#{key}=", config["default_status"][key.to_s].to_i )
		}

		@maps = []

		config["default_equipment"].each{|k,v|
			if k=="accessory1" or k=="accessory2"
				i = Item.new( "accessory", v )
			else
				i = Item.new( k, v )
			end
			equipment[k.to_sym] = i
			@inventory.push i
		}
		
		config["default_inventory"].each{|v|
			@inventory.push Item.new(v[0],v[1])
		}
		update
	end

	def map
		maps[current_level_num]
	end

	def put_chip( place )
		if equipment[ place ] and equipment[ place ].status["chip"]
			Tile.blit_to( s, 0, 0, equipment[ place ].status["chip"] )
		end
	end

	def update
		s.fill_rect(0,0,s.w,s.h,[0,0,0,0])
		Tile.blit_to( s, 0,0, config["chip"]["body"] )
		Tile.blit_to( s, 0,0, config["chip"]["hair"] )
		put_chip :boots
		put_chip :armor
		put_chip :helm
		put_chip :accessory1
		put_chip :accessory2
		put_chip :weapon
		put_chip :shield
	end

	def effective_ev
		@ev + equipment.inject(0){|r,i| r+(i[1] ? i[1].ev : 0) }
	end

	def effective_ac
		@ac + equipment.inject(0){|r,i| r+(i[1] ? i[1].ac : 0) }
	end

	def weight
		inventory.weight
	end

	def weight_limit
		str*3
	end

	def name
		config["name"]
	end

	def equipped?(item)
		equipment.any?{|k,v| v==item}
	end

	def pickup
		unless items_here[0]
			message :no_pickup_item
			return false
		end
		unless inventory.empty_slot
			message :inventory_full
			return false
		end
		i = item_pickup( 0 )
		inventory.push( i )
		message :pickup, {:item_name=>i.name}
		@spent -= 10
		true
	end

	def drop(item)
		return false unless item

		item_drop( item )
		inventory.pop item
		equipment.each{|k,v|
			if v == item
				equipment[k] = nil
				update
			end
		}
		inventory.listing
		@spent -= 10
		true
	end

	def eat(food)
		return false unless food
		return false unless food.type == :ration

		e = food.status["spec"]["energy"].to_i
		energy_add e if e > 0

		if food.status["message_at_eat"]
			Crawl.logging food.status["message_at_eat"]
		end

		if food.status["spec"]["after"]
			food.id = food.status["spec"]["after"]
		else
			inventory.pop food
		end
		inventory.listing

		@spent -= 10
		true
	end


	def quaff(potion)
		return false unless potion
		return false unless potion.type == :potion

		@spent -= 10

		message :quaff, {:potion_name=>potion.name}

		if potion.status["message_at_quaff"]
			Crawl.logging potion.status["message_at_quaff"]
		end

		e = potion.status["spec"]["energy"].to_i
		hp_dice = potion.status["spec"]["hp"]

		energy_add 40+e, false
		if hp_dice
			@hp += dice(hp_dice)
		end

		if potion.status["spec"]["after"]
			potion.id = potion.status["spec"]["after"]
		else
			inventory.pop potion
		end
		inventory.listing
		true
	end

	def die
		message :die
	end

	def hit?( monster, weapon_hit )
		to_hit = rand( 15 + dex/2 + weapon_hit )
		monster.effective_ev <= to_hit
	end

	def weapon
		equipment[:weapon]
	end

	def lv_up
		@lv += 1
		@hp_max += 4
		@hp += 4
		@hp = @hp_max if @hp > @hp_max
	end

	def get_experience(xp)
		lv_table = [
			0,10,30,70,140,270,520,1010,1980,3910,
			7760, 15450, 29000, 48500, 74000, 105500, 143000, 186500, 236000, 291500,
			353000, 420500, 494000, 573500, 659000, 750500, 848000
		]

		@experience += xp
		loop do
			if lv_table[ lv ] <= @experience
				lv_up
				message :lv_up, {:lv=>lv}
			else
				break
			end
		end
	end

	def attack(monster)
		gsub_list = {:name=>monster.name}
		if weapon
			gsub_list[:weapon] = weapon.name
			power = weapon.status["spec"]["power"].to_i
			weapon_type = weapon.status["spec"]["type"][0]
			weapon_attributes = weapon.status["spec"]["attributes"] || []
			weapon_hit = weapon.status["spec"]["hit"]
		else
			power = 1
			weapon_type = "slap"
			weapon_attributes = []
			weapon_hit = 0
		end

		if weapon_attributes.include?("use_energy")
			energy_add -80
		end
		energy_add -3
		@spent -= 10

		unless hit?( monster, weapon_hit )
			message :miss_by_dodge, {:name=>name, :target_name=>monster.name}
			return
		end

		damage = rand(1+power).to_i - rand(1+monster.effective_ac).to_i
		if damage <= 0
			damage = 0
			message :miss_by_armor, {:name=>name, :target_name=>monster.name}
		else
			gsub_list[:damage] = damage
			monster.hp -= damage
			message weapon_type, gsub_list
			if monster.hp <= 0
				message :kill, gsub_list
				get_experience monster.xp
			end
		end

	end

	def monster_in_fov?
		fov.any?{|f|
			current_level.monster_at( f[0], f[1] )
		}
	end

	def update_fov
		@fov = get_fov( x, y, 8 )
		@fov_shade.fill_rect( 0,0,SCREEN_W, SCREEN_H, [0,0,0,196] );
		fov.each{|f|
			fx = (f[0] - x)*32+CENTER_X
			fy = (f[1] - y)*32+CENTER_Y
			@fov_shade.fill_rect( fx,fy, 32,32, [0,0,0,0] );

			map[*f] = current_level.grid[ f[0], f[1] ].clone
		}
	end

	def mini_map
		colors = {wall:gray.push(128),floor:ivory.push(128),ladder_down:magenta.push(128)}
		@mini_map.fill_rect( 0,0,@mini_map.w,@mini_map.h,[0,0,0,0] )
		@mini_map_size.times{|dx|
			@mini_map_size.times{|dy|
				px = x- @mini_map_size/2 +dx
				py = y- @mini_map_size/2 +dy
				next if px<0 or py<0
				if px==x and py==y
					@mini_map.fill_rect( dx,dy,1,1, white )
					next
				end
				g = map[ px, py ]
				next unless g
				c = colors[g.type]
				@mini_map.fill_rect( dx,dy,1,1, c )
			}
		}
		@mini_map
	end

	def draw_map( target_surface )
		ox = x - CENTER_X/32
		oy = y - CENTER_Y/32
		SCREEN_W/32.times{|dx|
			SCREEN_H/32.times{|dy|
				next if ox+dx<0 or oy+dy<0
				g = map[ ox+dx, oy+dy ]
				next unless g
				current_level.blit target_surface,  dx*32, dy*32, g
			}
		}
	end

	def entering_new_level
		@current_level_num += 1
		dungeon.down_to current_level_num
		maps[ current_level_num ] ||= Map.new( w, h )
		move_to_random_position
		update_fov
	end

	def climb_downwards
		if grid_here.type == :ladder_down
			message :climb_downwards
			save
			entering_new_level
			return true
		end
		message :no_ladder
		return false
	end

	def move_to_random_position
		loop do
			nx = rand(w)
			ny = rand(h)
			if current_level.empty_grid?( nx, ny )
				to nx,ny
				break
			end
		end
	end

	def energy_add( e, with_message=true )
		@energy += e.to_i

		if e > 0
			if e > 1000
				message :recover_energy_greatly if with_message
			else
				message :recover_energy if with_message
			end
		end
	
		if energy_max <= energy
			@energy = energy_max
			message :energy_max if with_message
		end

		if energy < 0
			@energy = 0
			message :energy_empty if with_message
			@hp -= 2
		end
	end

	def regeneration
		return unless hp < hp_max
		@regeneration_count -= 1
		if regeneration_count <= 0
			@hp += 1
			@hp = hp_max if hp > hp_max
			@regeneration_count = 10+rand(10)
		end
	end

	def rest
		energy_add -3
		@spent -= 10
		regeneration
	end

	def to(x,y)
		@x = x
		@y = y
	end

	def move_to(x,y)
		if m = current_level.monster_at(x,y)
			attack( m )
			return true
		end
		to(x,y)
		unless items_here.empty?
			items_here.each{|i|
				message :item_here, {:item_name=>i.name}
			}
		end
		energy_add -3
		@spent -= 10

		regeneration
		update_fov
	end


	def get_fov(x,y,r)
		@fov = []
		do_fov(x,y,r)
		@fov
	end

	def equipment
		inventory.equipment
	end
####

	def current_level
		dungeon.levels[current_level_num]
	end

	def grid_here
		current_level.grid[x,y]
	end

	def items_here
		current_level.items(x,y)
	end

	def item_drop(item)
		current_level.item_drop(x,y,item)
	end

	def item_pickup(n)
		current_level.item_pickup(x,y,n)
	end

	def blocked?(x,y)
		current_level.blocked?(x,y)
	end

	def light(x,y)
		@fov << [x,y]
	end

	def w
		current_level.w
	end

	def h
		current_level.h
	end

end