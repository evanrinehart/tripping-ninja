require 'parser/current'

name = ARGV[0]
path = %x{gem which #{name}}
path = File.dirname path
source_file_paths = Dir["#{path}/**/*.rb"]


