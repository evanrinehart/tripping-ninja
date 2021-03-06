require './args'

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
    objmeth :==, 1

    exception = put_c :Exception
    stderror = put_c :StandardError, exception
    put_c :RuntimeError, stderror
    put_c :OpenStruct
    put_m :Mutex_m
    put_m :Enumerable
  end

  def self.std_requires
    %w{
      optparse
      thread
      mutex_m
      rbconfig
      pathname
      ostruct
      optparse/time
      timeout
      etc
      fileutils
      rubygems
      rubygems/specification
      rubygems/config_file
      set
    }
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
    args = (1..count).map do |i|
      OpenStruct.new(
        name: "arg#{i}",
        body: nil
      )
    end

    @object_class.insert name, MethDef.new(
      name: name,
      args: Args.new(args: args),
      body: nil,
      stdlib: true
    )
  end

  def spaces
    @top_level.values.select{|x| x.is_a? Space}
  end

end
