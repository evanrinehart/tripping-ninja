require 'ostruct'

require './working_set'

# compute the types of all names of a source ast
# requires a name context for the stdlib and or required files

# baked ast is the simplified and normalized version of the ast
# expressions:
#   let v = e in e
#   lambda p p p ... e
#   e.name e e e...
#   literal
#   variable


module Expr
  class Base < OpenStruct; end

  class Let < Base; end
  class Lambda < Base; end
  class MethodCall < Base; end
  class Literal < Base; end
  class Var < Base; end
end


class Infer

  class NameUndefined < StandardError; end
  class IllTyped < StandardError; end

  def initialize context
    @global_context = context # Name => Type
    @ws = WorkingSet.new
  end

  def run expr
    final = infer expr, {}
    ix = @ws.generalize final
    @ws[ix]
  end

  # Expr -> TypeId
  def infer expr, context
    case expr
      when Expr::Let then infer_let expr, context
      when Expr::Lambda then infer_lambda expr, context
      when Expr::MethodCall then infer_call expr, context
      when Expr::Literal then infer_literal expr
      when Expr::Var then infer_var expr, context
    end
  end

  def infer_literal expr
    # the expression should obviously be able to tell what the type is
    # copy the type constant into the working set anyway
    @ws.insert WorkingSet::constant(:name => expr.type)
  end


  # does instantiation so you can use polymorphic instances
  # forall a. [a] -> Int ==> [t9] -> Int
  def infer_var expr, context
    ix = context[expr.name]
    if ix
      @ws.instantiate_scheme node
    else
      raise NameUndefined, name if !@global_context.has_key?(expr.name)
      @ws.insert_type @global_context[expr.name]
    end
  end

  # does unification, which is where type errors are caught
  #   Bool,  t1,     t2 -> t1|t2
  #     t3, Int, String -> t4     UNIFY
  #   ---------------------------------
  #   Bool, Int, String -> Int|String
  def infer_call expr, context
    # e.name e e e
    obj_ix = infer expr.object, context
    arg_ixs = []
    expr.args.each do |arg|
      arg_ixs.push infer(arg, context)
    end
    result = @ws.fresh_variable
    template_ix = @ws.insert_duck_call(obj_ix, arg_ixs, result)
    @ws.unify(obj_ix, template_ix)
    result
  end

  # introduces new type variables for params
  # lambda{|x,y| [y, x+1]} ===> Int,t2 -> [t2,Int]
  def infer_lambda expr, context
    # lambda{|a,b| e }
    new_context = context.dup
    param_types = []
    expr.params.each do |param|
      t = @ws.fresh_variable
      new_context[param.name] = t
      param_types.push t
    end
    body_type = infer expr.body, new_context
    @ws.insert_function(param_types, body_type)
  end

  # quantifies free type variables in the definition
  # f = lambda{|x| x}  ====> f : forall a. a -> a
  def infer_let expr, context
    # let x = e in e
    def_type_raw = infer expr.definition, context
    def_type = @ws.generalize def_type_raw
    new_context = context.dup
    new_context[expr.var] = def_type
    infer expr.body, new_context
  end

end

