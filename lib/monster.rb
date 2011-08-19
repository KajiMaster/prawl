require "util"

class Monster
	include Util

  attr_accessor :x,:y,:n,:hp_max,:hp, :spent

	def to_h
		{
		x:x, y:y, n:n, hp_max:hp_max, hp:hp, spent:spent
		}
	end

	def self.load( save_data_hash )
		n = save_data_hash["n"]
		m = self.new n
		m.x = save_data_hash["x"]
		m.y = save_data_hash["y"]
		m.hp = save_data_hash["hp"]
		m.hp_max = save_data_hash["hp_max"]
		m.spent = save_data_hash["spent"]
		m
	end

  def initialize( n=0 )
		@@monster_config ||= JSON.parse File.read("data/monsters.json")
    @n = n
    @hp = @hp_max = @@monster_config[ @n ]["hp"]

    @x=0
    @y=0
    @spent = 0
  end

	def speed
		@@monster_config[ @n ]["speed"]
	end

	def hd
		@@monster_config[ @n ]["hd"]
	end

	def xp
		@@monster_config[ @n ]["xp"]
	end

	def effective_ev
		@@monster_config[ @n ]["ev"]
	end

	def effective_ac
		@@monster_config[ @n ]["ac"]
	end

	def desc
		@@monster_config[ @n ]["desc"]
	end

	def name
		@@monster_config[ @n ]["name"]
	end

	def level
		@@monster_config[ @n ]["level"]
	end

	def hit?( target )
		return true if target.hp <= 0
		rand(target.effective_ev)+rand(target.dex)/3 < rand(16+hd)
	end

	def damage( target, diceroll )
		target_ac = target.effective_ac < 0 ? 0 : rand( target.effective_ac ).to_i
		damage = dice( diceroll )
		damage = damage - target_ac > 0 ? damage - target_ac : 0
		return 1 if target.hp <= 0 and damage == 0
		damage
	end

	def message( m, gsub_list={} )
		Crawl.logging messages["monster"][m.to_s], gsub_list
	end

	def attack(target)
		@@monster_config[ @n ]["attack"].each{|a|
			d = a[0]
			m = a[1]
			if hit? target
				damage = damage( target, d )
				if damage == 0
					message :miss_by_armor, {:name=>name, :target_name=>target.name}
				else
					target.hp -= damage
					message m, { :target_name=>target.name, :name=>name, :damage=>damage }
				end
			else
				message :miss_by_dodge, {:name=>name, :target_name=>target.name}
			end
		}
	end

	def blit( target_surface, dx, dy )
		Tile::blit_to( target_surface, dx, dy, @@monster_config[n]["tile"] )
	end

	def move_to( player, tx, ty )
		
		if x==tx
			priority = [ [ :n ], [ :nw, :ne ], [:w,:e] ] if y > ty
			priority = [ [ :s ], [ :sw, :se ], [:w,:e] ] if y < ty
		end

		if y==ty
			priority = [ [ :e ], [ :ne, :se ], [:n,:s] ] if x < tx
			priority = [ [ :w ], [ :nw, :se ], [:n,:s] ] if x > tx
		end

		if x < tx
			priority = [ [ :se ], [ :s,:e ], [:ne,:sw], [:s,:e] ] if y < ty
			priority = [ [ :ne ], [ :n,:e ], [:nw,:se], [:s,:w] ] if y > ty
		elsif x > tx
			priority = [ [ :sw ], [ :s,:w ], [:se,:nw], [:n,:e] ] if y < ty
			priority = [ [ :nw ], [ :n,:w ], [:ne,:sw], [:s,:e] ] if y > ty
		end

		priority ||= nil

		direction = {
			nw:[-1,-1], n:[ 0,-1], ne:[ 1,-1],
			 w:[-1, 0], c:[ 0, 0],  e:[ 1, 0],
			sw:[-1, 1], s:[ 0, 1], se:[ 1, 1]
		}

		candidates = direction.select{|k,v|
			player.current_level.empty_grid?( x+v[0], y+v[1] )
		}

		priority.find{|p|
			d = (candidates.keys & p).sample
			return direction[d] if d
		}
		
		return [0,0] if candidates.empty?
		candidates.values.sample
	end

	def move( player )
		d = player.distance(self)
		
		if player.fov.any?{|f| f[0]==x and f[1]==y }
			dx,dy = move_to( player, player.x, player.y )
		else
			dx = rand(3) -1
			dy = rand(3) -1
			return unless player.current_level.empty_grid?( x+dx, y+dy )
		end

		if player.x == x+dx and player.y == y+dy
			attack(player)
			return
		end		
		@x += dx
		@y += dy
	end

end