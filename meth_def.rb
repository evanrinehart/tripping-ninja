class MethDef

  attr_reader :name
  attr_reader :body
  attr_reader :args
  attr_reader :star
  attr_reader :static
  attr_reader :origin # space path

  def initialize(ast:, origin:)
    if ast.type == :def
      @name = ast.children[0]
      @args = ast.children[1].children
      @star = false
      @body = ast.children[2]
      @static = false
      @origin = origin
    elsif ast.type == :defs
      @name = ast.children[1]
      @args = ast.children[2].children
      if @args.count > 0
        @star = @args.last.type == :restarg
      else
        @star = false
      end
      @body = ast.children[3]
      if ast.children[0].type == :self
        @static = true
      else
        raise "unknown syntax: defs #{ast.children[0].type}"
      end
      @origin = origin
    elsif ast.type == :defs
    else
      raise "unknown syntax: #{ast.type}"
    end
  end

  def size
    if star
      "#{args.count}+"
    else
      args.count
    end
  end

  def inspect
    "#{name}(#{size})"
  end

end
