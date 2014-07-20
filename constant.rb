class Constant

  attr_reader :name, :ast

  def initialize(name:, ast:)
    @name = name
    @ast = ast
  end

end
