require "sdl"
require 'util'

class Item
	include Util

	attr_accessor :type, :id, :status

	def to_h
		{ type:type, id:id }
	end

	def self.load( save_data )
		type = save_data["type"]
		id = save_data["id"]
		Item.new type, id
	end

	def self.create_random
		$items ||= JSON.parse File.read("data/items.json")
		type = $items.keys.sample
		id = $items[type].keys.sample
		Item.new( type, id )
	end

	def self.config
		$item_config ||= JSON.parse File.read("data/items.json")
	end

	def items
		Item.config
	end

	def is_artifact?( target = nil )
		target = self.status unless target
		target["attribute"] and target["attribute"].include? "artifact"
	end

	def	is_existed_artifact?
		@@existed_artifacts ||= []
		@@existed_artifacts.any?{|a| a.type == self.type and a.id == self.id }
	end

	def initialize( type, id )
		puts "ERROR! type:#{type} not found!" unless items[type]
		puts "ERROR! id:#{id} not found in type:#{type}!" unless items[type][id]
		@type = type.intern
		@id = id
		# artifact check
		if self.is_artifact?
			if self.is_existed_artifact?
				items[type].each{|k,v|
					unless is_artifact? v
						@id = k
						break
					end
				}
			else
				@@existed_artifacts << self
			end
		end
	end

	def status
		items[type.to_s][id]
	end

	def desc
		status["desc"].is_a?(Array) ? status["desc"] : [ status["desc"] ]
	end

	def weight
		status["weight"].to_f
	end

	def ev
		if status["spec"]
			return status["spec"]["ev"].to_i
		end
		return 0
	end

	def ac
		if status["spec"]
			return status["spec"]["ac"].to_i
		end
		return 0
	end

	def blit( target_surface, x, y )
		if t = status["tile"]
			Tile.blit_to( target_surface, x, y, t )
		end
	end

	def weapon_detail
		power = status['spec']['power']
		hit = status['spec']['hit']
		type = status['spec']['type'].join(",")
		attributes = status['spec']['attributes'] ? status['spec']['attributes'].join(",") : ""
		["Damage Rating: #{power} Accuracy Rating: #{hit}",
		"Type: #{type}",
		 "Attributes: #{attributes}"]
	end

	def wear_detail
		ac = status['spec']['ac'].to_i
		ev = status['spec']['ev'].to_i
		["AC:#{ac} EV:#{ev}"]
	end

	def detail( s )
		fill_rect_with_frame( s, 0,0,s.w,s.h, [0,0,0,196], [0,255,128] )
		thumbnail s, 10, 10
		print_ttf( "Weight: #{weight} kg", s, 10, 10+32 )
		
		by = 10+32+32
		desc.each.with_index{|l,i|
			by = 10+32+32+FONT_SIZE*i
			print_ttf( l, s, 10, by )
		}
		case type.intern
			when :weapon
				lines = weapon_detail
			when :armor, :gloves, :helm, :boots, :accessory
				lines = wear_detail
			else
				lines = []
		end
		lines.each.with_index{|l,i|
			print_ttf( l, s, 10, by+32+FONT_SIZE*i )
		}
	end

	def accuracy_plus
		return 0 unless status['spec']
		status['spec']['accuracy_plus'].to_i
	end

	def damage_plus
		return 0 unless status['spec']
		status['spec']['damage_plus'].to_i
	end

	def name_with_slaying
		return "#{name}(#{accuracy_plus},#{damage_plus})" if accuracy_plus != 0 or damage_plus != 0
		"#{name}"
	end

	def name
		if status["attribute"] and status["attribute"].include? "artifact"
			return artifact_mark + status["name"]
		end
		status["name"]
	end

	def thumbnail(target_surface,x,y, character=nil, color=[255,255,255])
		blit( target_surface, x, y )

		if is_artifact? and color==white
			color = gold
		end

		if character
			print_ttf( "#{character} - #{name_with_slaying}", target_surface, x+32, y+(32-15)/2, color )
		else
			print_ttf( name_with_slaying, target_surface, x+32, y+(32-15)/2, color )
		end
	end
end