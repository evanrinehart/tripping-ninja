require 'parser/current'
require 'ostruct'

require 'pry'
require 'awesome_print'

require './space'
require './meth_def'
require './stdlib'


name = ARGV[0]
root_file_path = %x{gem which #{name}}.chomp
gem_dir = File.dirname root_file_path
source_file_paths = Dir["#{gem_dir}/**/*.rb"]

gem = Gem::Specification.find_by_name name

$top_level = Space.new(path: [], gem: nil, type: :top_level)
$spaces = { # path -> Space
  [] => $top_level
}
$files_scanned = {}

StdLib.new.spaces.each do |space|
  $top_level.insert space.name, space
  $spaces[space.path] = space
end

def lookup_path start_space, path
  ptr = start_space.path
  while
    space = $spaces[ptr]
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

def scan_space space, gem, node
  # (module NAME body)
  puts "SCAN SPACE #{node}"
  target, name, superpath = read_space_header node

  if target && !space[target]
    raise "unknown target"
  end

  puts "IM IN #{space.path.inspect} defining #{target.inspect} #{name} < #{superpath.inspect}"

  if superpath
    superclass = lookup_path space, superpath
    if superclass.nil?
      raise "#{superpath.inspect} is not defined"
    end

    if !superclass.is_a?(Space) || superclass.type != :class
      raise "#{superpath.inspect} is not a class"
    end
  else
    superclass = nil
  end

  if target
    target_space = lookup_path(space, target)
    if target_space
      if !target_space.is_a?(Space)
        raise "#{target.inspect} is not a class or module"
      end
    else
      raise "#{target.inspect} not found"
    end
  else
    target_space = space
  end

  new_path = target_space.path + [name]
  new_space = lookup_path(space, new_path)

  if new_space
    if !new_space.is_a? Space
      raise "#{new_path.inspect} is not a class or module"
    end
  else
    new_path = space.path + [name]
    new_space = Space.new(
      path: new_path,
      gem: gem,
      type: node.type,
      superclass: superclass
    )
    space.insert name, new_space
    $spaces[new_path] = new_space
  end

  node.children[(node.type == :module ? 1 : 2)..-1].each do |c|
    scan_node new_space, gem, c
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


def read_lhs_name space, scopes, node
  accum = []
  name = node.children[1]
  thing = node.children[0]
  while !thing.nil?
    accum.unshift thing.children[1]
    thing = thing.children[0]
  end

  if accum.empty?
    [space, name]
  elsif scopes[accum[0]]
    prefix = scopes[accum[0]]
    if $spaces[prefix+accum]
      [prefix+accum, name]
    else
      raise "namespace error"
    end
  else
    raise "namespace error"
  end
end

# space, scopes, node -> new_space, new_scopes
def read_module_space space, scopes, spec, node
  thing = node.children[0]
  accum = []
  name = thing.children[1]
  thing = thing.children[0]
  while !thing.nil?
    accum.unshift thing.children[1]
    thing = thing.children[0]
  end

  if accum.empty?
    new_space = space + [name]
    new_scopes = scopes.dup
    new_scopes[name] = new_space
    $spaces[new_space] ||= Space.new(
      path: new_space,
      gem: spec,
      type: node.type
    )
    [new_space, new_scopes]
  elsif scopes[accum[0]]
    prefix = scopes[accum[0]]
    if $spaces[prefix+accum]
      new_space = prefix+accum+[name]
      new_scopes = scopes.dup
      new_scopes[name] = new_space
      [new_space, new_scopes]
    else
      raise "namespace error"
    end
  else
    raise "namespace error"
  end
end

# node -> path
def read_require node
  raw = node.children[2]
  if raw.type == :str
    arg = raw.children[0]
    spec = Gem::Specification.find_by_path(arg)
    raise "gem #{arg} not found" if spec.nil?
    path_glob = spec.lib_dirs_glob
    paths = Dir["#{path_glob}/#{arg}.rb"]
    raise "ambiguous require #{arg}" if paths.length > 1
    raise "file not found #{arg}" if paths.length == 0
    
    OpenStruct.new(
      :arg => arg,
      :gem => spec,
      :path => paths.first
    )
  else
    raise "can't read this require #{node.inspect}"
  end
end

def scan_method space, gem, node
  meth = MethDef.new(ast: node, origin: gem)
  space.insert meth.name, meth
  nil
end

def scan_mixin space, gem, node
  puts "SCAN MIXIN #{node.inspect}"
  path, name = read_qualified_name node.children[2]
  mixin = lookup_path space, (path||[])+[name]
  if !mixin.is_a?(Space) || mixin.type != :module
    raise "mixin target #{path.inspect} #{name} is not a module"
  else
    case node.children[1]
      when :include then space.insert_mixin mixin
      when :extend then space.insert_static_mixin mixin 
      else raise "bug in scan_mixin #{node.inspect}"
    end
  end
  nil
end

def scan_casgn space, gem, node
  puts "SCAN CASGN #{node.inspect}"
end

def scan_node space, gem, node
  case node.type
    when :module
      scan_space space, gem, node
    when :class
      scan_space space, gem, node
    when :begin
      node.children.each do |c|
        scan_node space, gem, c
      end
    when :casgn
      scan_casgn space, gem, node
    when :send
      if node.children[1] == :require
        link = read_require node
        if !$files_scanned[link.path]
          scan_file link.path, link.gem
        end
      elsif node.children[1] == :include || node.children[1] == :extend
        scan_mixin space, gem, node
      else
        puts "IGNORING SEND #{node.inspect}"
      end
    when :def
      scan_method space, gem, node
    when :defs
      scan_method space, gem, node
    else
      puts "IGNORING NODE #{node.type}"
  end
end

def scan_file filepath, gem
  $files_scanned[filepath] = true
  source = IO.read filepath
  ast = Parser::CurrentRuby.parse source
  puts "scanfile #{filepath} #{ast.inspect}"
  scan_node $top_level, gem, ast
  puts ''
end

scan_file root_file_path, gem

puts "GLOBAL SPACES"
ap $spaces.values
