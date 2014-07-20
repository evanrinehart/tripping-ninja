class StdLib

  attr_reader :object_class

  def initialize
    @top_level = {}
    @object_class = Space.new(
      path: [:Object],
      gem: nil,
      type: :class,
      stdlib: true
    )
    @top_level[[:Object]] = @object_class

    objmeth :dup, 0

    exception = put_c :Exception
    put_c :StandardError, exception
  end

  def put_c name, superclass=nil
    @top_level[name] = Space.new(
      path: [name],
      gem: nil,
      type: :class,
      superclass: superclass||@object_class,
      stdlib: true
    )
  end

  def put_m name
    @top_level[name] = Space.new(
      path: [name],
      gem: nil,
      type: :module,
      stdlib: true
    )
  end

  def objmeth name, count
    @object_class.insert name, MethDef.new(
      name: name,
      args: Array.new(count),
      body: nil,
      stdlib: true
    )
  end

  def spaces
    @top_level.values.select{|x| x.is_a? Space}
  end

end
