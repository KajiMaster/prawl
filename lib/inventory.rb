require "sdl"
require 'player'
require 'util'

class Inventory
	include Util

	attr_accessor :s, :s2
	attr_accessor :owner, :slot, :selected, :filter, :mode, :equipment
	
	SLOT_KEYS = ("a".."z").to_a+("A".."Z").to_a

	def to_a
		slot.map{|i| i ? i.to_h : nil }
	end

	def load( save_data )
		save_data.each.with_index{|v,i|
			slot[i] = v ? Item.load(v) : nil
		}
	end

	def initialize(owner)
		@equipment = {}
		@owner = owner
		@s = new_surface(800,600)
		@padding = 10
		@margin = 4
		@s2 = new_surface(500,300)
		@slot = Array.new(SLOT_KEYS.size)
		@selected = nil
		@filter = nil
		@page=0
	end

	def weight
		slot.inject(0){|r,i| i ? r+i.weight : r }
	end

	def put(target_surface,x,y)
		target_surface.put s, x,y
		if selected
			target_surface.put s2, x+20,y+20
		end
	end

	def pop(item)
		i = slot.index item
		slot[i] = nil
	end

	def empty_slot
		SLOT_KEYS.size.times{|i|
			return i unless slot[i]
		}
		return nil
	end

	def push(item)
		unless empty_slot
			Crawl.logging "no slot."
			return false
		end
		slot[ empty_slot ] = item
	end

	def list
		r = []
		SLOT_KEYS.size.times{|i|
			next unless slot[i]
			unless filter
				r << i
				next
			end
			r << i if filter.include?(slot[i].type)
		}
		r
	end

	def message( m, gsub_list={} )
		Crawl.logging messages["inventory"][m.to_s], gsub_list
	end


	def takeoff(item)
		if @equipment[ item.type ] != item
			message :selected_item_is_not_equipped
			return false
		end
		@equipment[ item.type ] = nil
		owner.update
		owner.spent -= 10
		true
	end

	def equip_weapon(item)
		return false unless item.type == :weapon
		@equipment[ item.type ] = item
		owner.update
		owner.spent -= 10
		return true
	end

	def equip(item)
		return false unless [:armor,:helm,:boots,:shield,].include? item.type
		return false if @equipment[ item.type ] == item
		@equipment[ item.type ] = item
		if item.status["sound_at_equip"]
			se = SDL::Mixer::Wave.load( item.status["sound_at_equip"] )
			SDL::Mixer.play_channel(-1, se , 0)
		end
		if item.status["message_at_equip"]
			Crawl.logging item.status["message_at_equip"]
		end
		owner.update
		owner.spent -= 10
		return true
	end

	def puton_jewellery( item )
		if equipment[ :accessory1 ] == nil
			@equipment[ :accessory1 ] = item
		elsif equipment[ :accessory2 ] == nil
			@equipment[ :accessory2 ] = item
		else
			message :no_accessory_space
			return false
		end
		owner.update
		owner.spent -= 10
		true
	end
	
	def remove_jewellery( item )
		if equipment[ :accessory1 ] == item
			@equipment[ :accessory1 ] = nil
		elsif equipment[ :accessory2 ] == item
			@equipment[ :accessory2 ] = nil
		else
			message :selected_item_is_not_accessory
			return false
		end
		owner.update
		owner.spent -= 10
		true
	end

	def select(key)
		return false unless SLOT_KEYS.include? key
		unless slot[ SLOT_KEYS.index(key) ]
			message :no_item_selected
			return false
		end
		@selected = slot[ SLOT_KEYS.index(key) ]

		case mode
			when :inventory_check
				detail selected
				return false
			when :drop_select
				@mode = nil
				return owner.drop selected
			when :select_ration
				@mode = nil
				return owner.eat selected
			when :select_potion
				@mode = nil
				return owner.quaff selected

			when :weapon_select
				@mode = nil
				return equip_weapon selected
			when :wear_select
				@mode = nil
				return equip selected
			when :takeoff_wear_select
				@mode = nil
				return takeoff selected
			when :puton_jewellery_select
				@mode = nil
				return puton_jewellery selected
			when :remove_jewellery_select
				@mode = nil
				return remove_jewellery selected
		end
	end

	def input(event)
		key = event.unicode.chr("UTF-8")
		case key
			when "\e"
				if @selected
					@selected = nil
				else
					@mode = nil
				end
			when " "
				next_page
			else
				return select(key)
		end
		return false
	end

	def start_item_select( mode )
		@mode = mode
		mode_to_filter = {
			:inventory_check => nil,
			:drop_select => nil,
			:weapon_select => [:weapon],
			:wear_select => [:armor,:helm,:boots,:gloves,:shield],
			:takeoff_wear_select => [:armor,:helm,:boots,:gloves,:shield],
			:remove_jewellery_select => [:accessory],
			:puton_jewellery_select => [:accessory],
			:select_ration => [:ration],
			:select_potion => [:potion]
		}
		@filter = mode_to_filter[mode]
		@selected = nil
		@page = 0
		listing
	end

	def detail(item)
		return false unless item
		item.detail s2
	end
	
	def row
		(s.h - @padding*2) / (ICON_SIZE+@margin)
	end

	def per_page
		row*2
	end

	def page_max
		m = (list.size-1) / per_page + 1
	end

	def next_page
		@page += 1
		@page = 0 if @page >= page_max
		listing
		@page
	end
	
	def list_with_page
		list[ @page*per_page, per_page ] || []
	end
	
	def listing
		fill_rect_with_frame( s, 0,0,s.w,s.h, [0,0,0,196], [0,255,128] )
		y_step = ICON_SIZE+@margin

		bx = @padding
		by = @padding

		list_with_page.each.with_index{|key,i|
			y = by+(i%row)*y_step
			if i >= row
				x = bx + s.w/2
			else
				x = bx
			end

			item = slot[ key ]

			if owner.equipped?( item )
				item.thumbnail s, x,y, SLOT_KEYS[key], [128,128,255]
			else
				item.thumbnail s, x,y, SLOT_KEYS[key]
			end
		}
		print_ttf "page(#{1+@page}/#{page_max})", s, -2,-2
	end

end