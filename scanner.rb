require 'parser/current'
require 'ostruct'

require './space'
require './meth_def'
require './stdlib'
require './constant'
require './code_pointer'

# the scanner recursively reads through source files and
# builds a model of the names it finds and the namespaces

# scanning begins at a particular source file or gem

class Scanner

  class ScannerError < StandardError
    def initialize errors
      @errors = errors
    end

    def errors
      @errors.map do |h|
        code = h[:code]
        message = h[:message]
        OpenStruct.new(
          :location => "#{code.file} line #{code.line}",
          :message => message
        )
      end
    end
  end

  class SoftCrash < StandardError; end

  def initialize
    @top_level = Space.new(path: [], gem: nil, type: :top_level)
    @spaces = { # path -> Space
      [] => @top_level
    }
    @files_scanned = {}

    @stdlib = StdLib.new

    @stdlib.spaces.each do |space|
      @top_level.insert space.name, space
      @spaces[space.path] = space
    end

    @object_class = @stdlib.object_class

    @errors = []
  end

  def soft_crash code, message
    @errors.push(:code => code, :message => message)
    raise SoftCrash
  end

  def scan(gem:nil, file:nil)
    if gem.nil? && file.nil?
      raise "specify gem or file to start scanning at"
    end

    if gem
      spec = Gem::Specification.find_by_name gem
      root_file_path = "#{spec.gem_dir}/lib/#{gem}.rb"
      scan_file root_file_path, spec
    elsif file
      scan_file file, nil
    else
      raise "bug"
    end

    if @errors.count == 0
      @spaces
    else
      raise ScannerError.new(@errors)
    end
  end


  def scan_file filepath, gem
    puts "scanfile #{filepath}"
    @files_scanned[filepath] = true
    if filepath =~ /\.so$/
      puts "avoiding scanning a .so file"
      return
    end
    source = IO.read filepath
    ast = Parser::CurrentRuby.parse source
    code = CodePointer.new(
      file: filepath,
      gem: gem,
      node: ast
    )
    scan_node @top_level, code
    puts ''
  end

  def lookup_path start_space, path
    ptr = start_space.path
    while
      space = @spaces[ptr]
      found = space.lookup path
      if found
        return found
      end
      if ptr.empty?
        return nil
      else
        ptr = ptr[0..-2]
      end
    end
  end

  def scan_space space, code
    # (module NAME body)
    node = code.node
    puts "SCAN SPACE #{node}"
    target, name, superpath = read_space_header node

    if target && !space[target]
      soft_crash(code, "unknown target #{target.inspect}")
    end

    if superpath
      superclass = lookup_path space, superpath
      if superclass.nil?
        soft_crash code, "#{superpath.inspect} is not defined"
      end

      if !superclass.is_a?(Space) || superclass.type != :class
        soft_crash code, "#{superpath.inspect} is not a class"
      end
    else
      superclass = @object_class
    end

    if target
      target_space = lookup_path(space, target)
      if target_space
        if !target_space.is_a?(Space)
          soft_crash code, "#{target.inspect} is not a class or module"
        end
      else
        soft_crash code, "#{target.inspect} not found"
      end
    else
      target_space = space
    end

    new_path = target_space.path + [name]
    new_space = lookup_path(space, new_path)

    if new_space
      if !new_space.is_a? Space
        soft_crash code, "#{new_path.inspect} is not a class or module"
      end
    else
      new_path = space.path + [name]
      new_space = Space.new(
        path: new_path,
        gem: code.gem,
        type: node.type,
        superclass: superclass
      )
      space.insert name, new_space
      @spaces[new_path] = new_space
    end

    node.children[(node.type == :module ? 1 : 2)..-1].each do |c|
      if c.nil?
        # hmm
      else
        scan_node new_space, code.with_node(c)
      end
    end
  end


  def scan_method space, code
    node = code.node
    if node.type == :def
      meth = MethDef.new(
        name: node.children[0],
        args: node.children[1].children,
        star: false, # huh
        body: node.children[2],
        static: false,
        origin: code.gem,
        internal: space.internal_mode
      )
      space.insert meth.name, meth
    elsif node.type == :defs
      name = node.children[1]
      args = node.children[2].children
      if args.count > 0
        star = args.last.type == :restarg
      else
        star = false
      end
      body = node.children[3]
      if node.children[0].type == :self
        static = true
      else
        soft_crash code, "unknown syntax: defs #{node.children[0].type}"
      end

      meth = MethDef.new(
        name: name,
        args: args,
        star: star,
        body: body,
        static: static,
        origin: code.gem,
        internal: false
      )

      space.insert name, meth

    else
      raise "bug"
    end
  end

  def read_space_header node
    path, name = read_qualified_name node.children[0]
    if node.type == :class && node.children[1]
      a, b = read_qualified_name node.children[1]
      superpath = (a||[])+[b]
    else
      superpath = nil
    end

    [path, name, superpath]
  end

  def read_qualified_name node
    accum = []
    name = node.children[1]
    ptr = node.children[0]
    while !ptr.nil?
      accum.unshift ptr.children[1]
      ptr = ptr.children[0]
    end

    if accum.empty?
      [nil, name]
    else
      [accum, name]
    end
  end

  # node -> path
  def read_require code
    node = code.node
    raw = node.children[2]
    if raw.type == :str
      arg = raw.children[0]

      if StdLib.std_requires.include?(arg)
        return OpenStruct.new(
          :arg => arg,
          :stdlib => true
        )
      end

      if File.exists? "#{arg}.rb"
        OpenStruct.new(
          :arg => arg,
          :path => "#{arg}.rb",
          :gem => nil
        )
      else
        spec = Gem::Specification.find_by_path(arg)
        soft_crash code, "gem for #{arg} not found" if spec.nil?
        path_glob = spec.lib_dirs_glob
        paths = Dir["#{path_glob}/#{arg}.rb"]
        soft_crash code, "ambiguous require #{arg}" if paths.length > 1
        soft_crash code, "file not found #{arg}" if paths.length == 0
        
        OpenStruct.new(
          :arg => arg,
          :gem => spec,
          :path => paths.first
        )
      end

    else
      soft_crash code, "can't read this require #{node.inspect}"
    end
  end

  def scan_mixin space, code
    node = code.node
    path, name = read_qualified_name node.children[2]
    mixin = lookup_path space, (path||[])+[name]
    if mixin.nil?
      soft_crash code, "mixin #{path.inspect} #{name} not found"
    else
      if !mixin.is_a?(Space) || mixin.type != :module
        soft_crash code, "mixin target #{path.inspect} #{name} is not a module"
      else
        case node.children[1]
          when :include then space.insert_mixin mixin
          when :extend then space.insert_static_mixin mixin 
          else raise "bug in scan_mixin #{node.inspect}"
        end
      end
    end
    nil
  end

  def read_asgn_lhs node
    if node.children[0]
      a,b = read_qualified_name node.children[0]
      if a
        target = a+[b]
      else
        target = [b]
      end
    else
      target = nil
    end

    name = node.children[1]

    [target, name]
  end

  def scan_casgn space, code
    node = code.node
    puts "SCAN CASGN #{node.inspect}"
    target, name = read_asgn_lhs node
    ast = node.children[2]

    constant = Constant.new(
      ast: ast,
      name: name
    )

    if target
      target_space = lookup_path space, target
      if target_space
        if !target_space.is_a?(Space)
          soft_crash code, "target of assignment is not a class or module"
        else
          if target_space[name]
            soft_crash code, "assignment to existing constant"
          else
            target_space.insert name, constant
          end
        end
      else
        soft_crash code, "target does not exist #{target.inspect}"
      end
    else
      if space[name]
        soft_crash code, "assignment to existing constant"
      else
        space.insert name, constant
      end
    end

    nil
  end

  def scan_private space, code
    node = code.node
    if node.children[2]
      name = node.children[2].children[0]
      if space[name]
        if space[name].is_a?(MethDef)
          space[name].internal = true
        else
          soft_crash code, "private must be used on a method, if anything"
        end
      else
        soft_crash code, "private used on a non existent thing"
      end
    else
      space.internal_mode = true
    end
  end

  def scan_alias space, code
    node = code.node
    puts "SCAN ALIAS #{node.inspect}"
    new_name = node.children[0].children[0]
    old_name = node.children[1].children[0]
    if space[new_name]
      soft_crash code, "alias #{new_name} already exists"
    else
      meth = space.lookup_inherited old_name
      if meth
        new_meth = meth.dup
        new_meth.name = new_name
        space.insert new_name, new_meth
      else
        soft_crash code, "aliasing #{old_name} which does not exist"
      end
    end
  end

  def scan_node space, code
    node = code.node
    begin
      case node.type
        when :module
          scan_space space, code
        when :class
          scan_space space, code
        when :begin
          node.children.each do |c|
            scan_node space, code.with_node(c)
          end
        when :casgn
          scan_casgn space, code
        when :alias
          scan_alias space, code
        when :send
          if node.children[1] == :require
            link = read_require code
            if link.path && !@files_scanned[link.path]
              scan_file link.path, link.gem
            end
          elsif node.children[1] == :include || node.children[1] == :extend
            scan_mixin space, code
          elsif node.children[1] == :private
            scan_private space, code
          else
            puts "IGNORING SEND #{node.inspect}"
          end
        when :def
          scan_method space, code
        when :defs
          begin
            scan_method space, code
          rescue UnknownDefs
            puts "IGNORING dynamicy defs"
          end
        else
          puts "IGNORING NODE #{node.type}"
      end
    rescue SoftCrash
    end
  end

end
