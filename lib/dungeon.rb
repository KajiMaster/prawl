require "level"

class Dungeon
  attr_accessor :levels

  def initialize
		@levels = []
	end

	def to_h
		{ max_level_num:levels.size-1 }
	end

	def load
		d = JSON.parse File.read("#{$save_dir}/dungeon.json")
		max_level_num = d["max_level_num"]
		max_level_num.times{|i|
			level_data = JSON.parse File.read("#{$save_dir}/level_#{1+i}.json")
			level = Level.new( 1+i )
			level.load level_data
			levels[1+i] = level
		}
	end

	def self.config
  	$dungeon_config ||= JSON.parse File.read("data/dungeon.json")
	end

	def down_to( level_num )
		levels[level_num] ||= Level.new( level_num ).new_level
	end
end