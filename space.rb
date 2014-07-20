class Space

  attr_reader :path
  attr_reader :type

  def initialize(path:, gem:, type:, superclass:nil)
    @spec = gem
    @names = {}
    @path = path
    if ![:class, :module, :top_level].include? type
      raise "bad space type: #{type}"
    end
    @type = type
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
