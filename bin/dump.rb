#!/home/evan/.rvm/rubies/ruby-2.1.2/bin/ruby
require 'parser/current'

code = $stdin.read
tree = Parser::CurrentRuby.parse code
puts tree.inspect
