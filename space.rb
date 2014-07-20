class Space

  attr_reader :path
  attr_reader :type
  attr_reader :names
  attr_reader :superclass
  attr_reader :stdlib
  attr_accessor :internal_mode

  def initialize(path:, gem:, type:, superclass:nil, stdlib:false)
    @spec = gem
    @names = {}
    @path = path
    if ![:class, :module, :top_level].include? type
      raise "bad space type: #{type}"
    end
    @type = type
    @superclass = superclass # space
    @mixins = [] # array of full names
    @static_mixins = []
    @internal_mode = false
    @stdlib = stdlib
  end

  def gem
    if @spec
      @spec.name
    else
      nil
    end
  end

  def name
    if path.empty?
      :''
    else
      path.last
    end
  end

  def [] name
    @names[name]
  end

  def lookup target
    raise "empty path" if target.empty?
    ptr = self
    target.each do |name|
      ptr = ptr[name]
      return nil if ptr.nil?
    end
    ptr
  end

  def lookup_inherited name
    here = @names[name]
    if here
      here
    else
      @mixins.each do |mixin|
        there = mixin.lookup_inherited(name)
        return there if there
      end

      if @superclass
        there = @superclass.lookup_inherited(name)
        return there if there
      end

      nil
    end
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

  def methdefs
    @names.values.select do |item|
      item.is_a?(MethDef)
    end
  end

  def namespace?
    methdefs.all?{|x| x.static}
  end

  def mixin?
    type == :module && methdefs.any?{|x| !x.static}
  end

  def datatype?
    type == :class
  end

  def space_descriptor
    full = path.join('::')
    if type==:class
      "class #{full}"
    elsif mixin?
      "mixin #{full}"
    elsif namespace?
      "namespace #{full}"
    else
      full
    end
  end

end
