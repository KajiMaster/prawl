require "sdl"
require 'util'

class TextArea
	include Util

	LINE_NUM=14
	attr_accessor :s
	
	def initialize(log)
		@s = new_surface( SCREEN_W-10+2, FONT_SIZE*LINE_NUM+2 )
		@log = log
	end

	def update
		fill_rect_with_frame s, 0,0, s.w, s.h, [0,0,0,196], [0,255,128]

		@log.last(LINE_NUM).each.with_index{|m,i|
			if m and m.size > 0
				print_ttf m, s, 1, 1+i*FONT_SIZE
			end
		}
	end
end