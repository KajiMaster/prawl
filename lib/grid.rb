class Grid
  attr_accessor :type, :number

	def to_a
		[type, number]
	end

  def initialize( type, number )
		update(type,number)
  end

	def update( type, number )
  	@type = type.intern
  	@number = number
	end

	def clone
		Grid.new type, number
	end
end