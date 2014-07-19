class Space

  attr_reader :path
  attr_reader :is_module

  def initialize(path:, spec:, is_module:, superclass:nil)
    @spec = spec
    @names = {}
    @path = path
    @is_module = is_module
    @superclass = superclass # full name
    @mixins = [] # array of full names
    @static_mixins = []
  end

  def gem
    if @spec
      @spec.name
    else
      nil
    end
  end

  def [] name
    @names[name]
  end

  def insert name, value
    @names[name] = value
  end

  def insert_mixin path
    @mixins.push path
  end

  def insert_static_mixin path
    @static_mixins.push path
  end

  def inspect
    to_s
  end

  def to_s
    [
      @path.join('::'),
      '(',
      @names.map{|k,v| show_frag k, v}.join(', '),
      ')'
    ].join('')
  end

  def show_frag k, v
    if v.respond_to?(:size)
      "#{k}(#{v.size})"
    else
      k
    end
  end


end
