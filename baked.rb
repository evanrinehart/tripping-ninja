require 'parser/current'

def generate_ast source
  tree = Parser::CurrentRuby.parse source
  return tree

  # but we should bake the tree here
end


