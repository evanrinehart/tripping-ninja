class StdLib

  def initialize
    @top_level = {}
    put_c :StandardError
  end

  def put_c name
    @top_level[name] = Space.new(path: [name], gem: nil, type: :class)
  end

  def put_m name
    @top_level[name] = Space.new(path: [name], gem: nil, type: :module)
  end

  def spaces
    @top_level.values.select{|x| x.is_a? Space}
  end

end
