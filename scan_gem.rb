require 'parser/current'

name = ARGV[0]
root_file_path = %x{gem which #{name}}.chomp
gem_dir = File.dirname root_file_path
source_file_paths = Dir["#{gem_dir}/**/*.rb"]

$spaces = {}

def scan_module space, scopes, node
  # (module NAME body)
  puts "scan module #{space.inspect}"
  node.children[1..-1].each do |c|
    scan_node space, scopes, c
  end
end

def scan_class space, scopes, node
  # (class NAME SUPERCLASS BODY)
  puts "scan class #{space.inspect}"
  node.children[2..-1].each do |c|
    scan_node space, scopes, c
  end
end

def scan_node space, scopes, node
  case node.type
    when :module
      inner_space, inner_scopes = read_module_space space, scopes, node
      scan_module(inner_space, inner_scopes, node)
    when :class
      inner_space, inner_scopes = read_module_space space, scopes, node
      scan_class(inner_space, inner_scopes, node)
    when :begin
      node.children.each do |c|
        scan_node space, scopes, c
      end
    when :casgn
      my_space, name = read_lhs_name space, scopes, node
      $spaces[my_space][name] = true
    when :send
      if node.children[1] == :require
        end_of_path = read_require node
        puts "REQUIRE #{end_of_path}"        
      else
        puts node.inspect
      end
    else
      puts "IGNORING NODE #{node.type}"
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
def read_module_space space, scopes, node
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
    $spaces[new_space] ||= {}
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
    raw.children[0]
  else
    raise "can't read this require #{node.inspect}"
  end
end

def scan_file path
  source = IO.read path
  ast = Parser::CurrentRuby.parse source
  puts "scanfile #{path} #{ast.inspect}"
  scan_node [], {}, ast
  puts ''
end

scan_file root_file_path

puts "GLOBAL SPACES"
puts $spaces.inspect
