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

  def pi
    "π"
  end

  def arrow
    "→"
  end

  def type_sig names=false
    if ctor
      rhs = alpha
      prealpha = false
    else
      rhs = beta
      prealpha = true
    end

    total_args = @args.count

    if static && total_args == 0
      return rhs
    elsif static
      lhs = Array.new(total_args, beta).join(', ')
    else
      lhs = ((prealpha ? [alpha] : [])+Array.new(total_args, beta)).join(', ')
    end

    "#{lhs} #{arrow} #{rhs}"
  end

  def detailed_sig
    parts = []

    @args.args.each do |arg|
      if arg.body
        parts.push "#{arg.name}?"
      else
        parts.push arg.name
      end
    end

    if @args.restarg
      parts.push "*#{@args.restarg}"
    end

    @args.kwargs.values.each do |name|
      parts.push "#{name}:"
    end

    @args.kwoptargs.values.each do |name|
      parts.push "#{name}?:"
    end

    if @args.block
      parts.push "&#{@args.block}"
    end

    parts.join(', ')
  end

  def named_type_sig
    parts = []

    if !ctor && !static
      parts.push alpha
    end

    @args.args.each do |arg|
      if arg.body
        parts.push "#{arg.name}?:#{beta}"
      else
        parts.push "#{arg.name}:#{beta}"
      end
    end

    if @args.restarg
      parts.push "*#{@args.restarg}:#{beta}"
    end

    @args.kwargs.keys.each do |name|
      parts.push "#{name}:#{beta}"
    end

    @args.kwoptargs.keys.each do |name|
      parts.push "#{name}?:#{beta}"
    end

    if @args.block
      parts.push "#{@args.block}:#{pi}"
    end

    lhs = parts.join(', ')

    if ctor && parts.count > 0
      "#{lhs} #{arrow} #{alpha}"
    elsif ctor && parts.count == 0
      alpha
    elsif parts.count == 0
      beta
    else
      "#{lhs} #{arrow} #{beta}"
    end
  end

  def descriptor
#    "#{static ? "self." : ""}#{name}(#{size})#{internal ? " (internal)" : ""}"
    "#{internal ? '(internal) ' : ''}#{show_name} : #{named_type_sig}"
  end

end
