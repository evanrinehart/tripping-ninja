class Args

  attr_reader :args
  attr_reader :restarg
  attr_reader :kwargs
  attr_reader :kwoptargs
  attr_reader :block

  def initialize(args:[],restarg:nil,kwargs:{},kwoptargs:{},block:nil)
    @args = args
    @restarg = restarg
    @kwargs = kwargs
    @kwoptargs = kwoptargs
    @block = block
  end

  def count
    @args.count +
    (@restarg ? 1 : 0) +
    @kwargs.keys.count +
    @kwoptargs.keys.count +
    (@block ? 1 : 0)
  end

end
