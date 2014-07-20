class CodePointer

  attr_reader :file
  attr_reader :line
  attr_reader :node
  attr_reader :gem

  def initialize(file:, gem:, node:)
    @file = file
    @line = node.location.line
    @gem = gem
    @node = node
  end

  def with_node new_node
    CodePointer.new(
      file: file,
      gem: gem,
      node: new_node
    )
  end

end
