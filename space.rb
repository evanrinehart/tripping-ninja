class Space

  attr_reader :path

  def initialize(path:, spec:, superclass:nil, mixins:[])
    @spec = spec
    @names = {}
    @path = path
    @superclass = superclass # full name
    @mixins = mixins # array of full names
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
