require 'parser/current'

code = $stdin.read
tree = Parser::CurrentRuby.parse code
puts tree.inspect
