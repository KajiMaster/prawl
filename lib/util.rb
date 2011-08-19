require "sdl"

module Util

	SCREEN_W = 1024
	SCREEN_H = 768

	CENTER_X = 12*32 # = 384 = 768/2
	CENTER_Y = 8*32 # = 256 = 512/2

	FONT_SIZE=16
	ICON_SIZE=32

	def artifact_mark
		Player.config["artifact_mark"]
	end

	def messages
		$messages ||= JSON.parse File.read("data/messages.json")
	end

	def roll_dice( num, max )
		result = 0
		(num.to_i).times{ result += rand(max).to_i+1 }
		result
	end

	def dice( d )
		cons = 0
		if d.include?( "+" )
			d,cons = d.split( "+" )
			cons = cons.to_i
		elsif d.include?( "-" )
			d,cons = d.split "-"
			cons = - cons.to_i
		end
		num,max = d.split("d")
		num = num.to_i
		max = max.to_i

		cons + roll_dice(num,max)
	end

	def tile( target_surface, name, number, x, y )
		Tile::get(name).blit( target_surface, number, x, y )
	end

	def font32
		$font32 ||= SDL::TTF.open("resources/mona.ttf", 32)
	end

	def font
		$font ||= SDL::TTF.open("resources/mona.ttf", FONT_SIZE)
	end
	
	def print_ttf( string, target, x, y, color=nil )
		color = white unless color
		f = font.render_blended_utf8( string, color[0], color[1], color[2] )
		y = target.h + y - f.h if y<0
		x = target.w + x - f.w if x<0
		SDL::Surface.blit(f, 0, 0, f.w, f.h, target, x,y)
		f.destroy
	end
	
	def new_surface(w,h)
		big_endian = ([1].pack("N") == [1].pack("L"))
		if big_endian
			rmask = 0xff000000
			gmask = 0x00ff0000
			bmask = 0x0000ff00
			amask = 0x000000ff
		else
			rmask = 0x000000ff
			gmask = 0x0000ff00
			bmask = 0x00ff0000
			amask = 0xff000000
		end
		SDL::Surface.new(SDL::HWSURFACE | SDL::SRCALPHA, w, h, 32,
															 rmask, gmask, bmask, amask);
	end

	def fill_rect_with_frame( surface, x,y,w,h, fill_color, frame_color )
		surface.fill_rect(x,y,w,h, fill_color)
		surface.draw_rect(x,y,w-1,h-1, frame_color)
	end

	def distance(target)
		Math.sqrt( (x-target.x).abs**2 + (y-target.y).abs**2 )
	end

	def rand_color
		[rand(255), rand(255), rand(255)]
	end

	def b_circle( x0, y0, r )
		line = []
		f = 1-r
		ddf_x = 1
		ddf_y = -2 * r
		x = 0
		y = r
		
		line << [x0,y0+r]
		line << [x0,y0-r]
		line << [x0+r,y0]
		line << [x0-r,y0]
	
		while x < y
			if f >= 0
				y -= 1
				ddf_y += 2
				f += ddf_y
			end
			x += 1
			ddf_x += 2
			f += ddf_x
			
			line << [x0+x,y0+y]
			line << [x0-x,y0+y]
			line << [x0+x,y0-y]
			line << [x0-x,y0-y]
			line << [x0+y,y0+x]
			line << [x0-y,y0+x]
			line << [x0+y,y0-x]
			line << [x0-y,y0-x]
	
		end
		line
	end
	
	def b_line(x1,y1, x2,y2)
		line = []
	
		dx = (x2 - x1).abs
		dy = (y2 - y1).abs
		sx = (x2 - x1) < 0 ? -1 : 1
		sy = (y2 - y1) < 0 ? -1 : 1
		e = 0
	
		if dx > dy
			y = y1
			x = x1
			(1+dx).times do
				e += dy
				if( e > dx )
					e -= dx
					y += sy
				end
				line << [x,y]
				x += sx
			end
		else
			x = x1
			y = y1
			(1+dy).times do
				e += dx
				if e > dy
					e -= dy
					x += sx
				end
				line << [x,y]
				y += sy
			end
		end
		line
	end
	
	def black
		[0,0,0]
	end
	def gray
		[0x33,0x33,0x33]
	end
	def blue
		[0,0,255]
	end
	def silver
		[196,196,196]
	end
	def brown
		[0xA5, 0x2A, 0x2A]
	end
	def ivory
		[221,222,211]
	end
	def magenta
		[255,0,255]
	end
	def orange
		[255, 0xa5, 00]
	end
	def cyan
		[0,255,255]
	end
	def white
		[255,255,255]
	end
	def red
		[255,0,0]
	end
	def yellow
		[255,255,0]
	end
	def green
		[0,255,0]
	end
	def gold
		[0xFF,0xD7,0]
	end
end
