require 'pry'
require 'awesome_print'

require './scanner'

name = ARGV[0]

spaces = Scanner.new.scan :gem => name

puts "GLOBAL SPACES"
ap spaces.values

puts "NAME LISTING"
spaces.each do |path, space|
  if space.path == []
    puts "Top Level"
  else
    puts space.space_descriptor
  end

  space.names.each do |name, item|
    next if item.is_a?(Space)
    if item.is_a?(MethDef)
      puts "  #{item.descriptor}"
    else
      puts "  #{name} (#{item.class})"
    end
  end
end
