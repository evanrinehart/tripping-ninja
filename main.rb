require 'baked'
require 'infer'

ast = generate_ast $stdin.read
context = {
  'foo' => 'Int',
  'Date::parse' => 'String -> Date'
}
type = Infer.new(context).run ast

puts type.inspect
