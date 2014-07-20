class MethDef

  attr_accessor :name
  attr_reader :body
  attr_reader :args
  attr_reader :star
  attr_reader :static
  attr_reader :origin # gem
  attr_accessor :internal
  attr_reader :ctor

  attr_reader :stdlib

  def initialize(
    name:, args:, star:false, body:,
    static:false, origin:nil, internal:false, stdlib:false
  )
    @name = name
    @args = args
    @star = star
    @body = body
    @static = static
    @origin = origin
    @internal = internal
    @stdlib = stdlib
    @ctor = name == :initialize
  end

  def show_name
    if ctor
      :new
    else
      name
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

  def alpha
    "α"
  end

  def beta
    "β"
  end

  def arrow
    "→"
  end

  def type_sig
    if ctor && args.count > 0
      "#{Array.new(args.count, beta).join(', ')} #{arrow} #{alpha}"
    elsif ctor && args.count == 0
      "#{alpha}"
    elsif static && args.count > 0
      "#{Array.new(args.count, beta).join(', ')} #{arrow} #{beta}"
    elsif static
      "#{beta}"
    else
      "#{([alpha]+Array.new(args.count, beta)).join(', ')} #{arrow} #{beta}"
    end
  end

  def descriptor
#    "#{static ? "self." : ""}#{name}(#{size})#{internal ? " (internal)" : ""}"
    "#{show_name} : #{type_sig}"
  end

end
