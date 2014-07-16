# a scratch pad to do the unification of types

require 'ostruct'

class WorkingSet

  class Node < OpenStruct; end

  class Constant < Node # Int Bool String
    # name
  end

  class Variable < Node # t1 t2 t3 ...
    # id
  end

  class Indirection < Node
    # ptr
  end

  class Ctor < Node # Array(_) Hash(_,_) ->(_,_)
    # name
    # ptrs
  end

  class Forall < Node
    # vars
    # body
  end

  class Duck < Node
    # var
    # methods
  end

  class BadIndex < StandardError; end
  class UnificationFailed < StandardError; end

  def initialize
    @map = {} # Int => Node
    @counter = 0
  end

  def fresh_index
    n = @counter
    @counter += 1
    n
  end

  def fresh_variable
    ix = fresh_index
    @map[ix] = Variable.new :id => ix
    ix
  end

  def [] ix
    node = @map[ix]
    case node
      when Indirection then self[node.ptr]
      when nil then raise BadIndex, "ix=#{ix}"
      else node
    end
  end

  def []= ix, node
    @map[ix] = node
  end

  def insert node
    ix = fresh_index
    @map[ix] = node
  end

  def instantiate_scheme ix
  end

  def insert_type type
  end

  def insert_duck_call obj, args, result
  end

  def unify ix1, ix2
    nil
  end

  def insert_function params, body
  end

  def generalize ix
  end

end
