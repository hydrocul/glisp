#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

EOF = :"$eof"
#UNDEFINED = :"$undefined-on-compile"

EVAL_FINAL = 1
EVAL_FUNCTION_DEFINITION = 2
#EVAL_OPTIMIZATION = 3

def gl_create(rubyObj)
  if rubyObj.is_a? GlispObject then
    rubyObj
  elsif rubyObj.is_a? Symbol then
    SymbolGlispObject.new(rubyObj)
  elsif rubyObj.is_a? String then
    StringGlispObject.new(rubyObj)
  elsif rubyObj.is_a? Integer then
    IntegerGlispObject.new(rubyObj)
#  elsif rubyObj.is_a? Float then
#    NumberGlispObject.new(rubyObj)
  elsif rubyObj == false or rubyObj == true then
    BooleanGlispObject.new(rubyObj)
  elsif rubyObj.is_a? Proc then
    ProcGlispObject.new(rubyObj, false, nil)
  elsif rubyObj.is_a? Array then
    _gl_createList(rubyObj, 0)
  elsif rubyObj == nil then
    gl_nil
  else
    raise RuntimeError, rubyObj.inspect
  end
end

def _gl_createList(arrayRubyObj, offset)
  if offset == arrayRubyObj.length then
    gl_nil
  else
    gl_cons(arrayRubyObj[offset], _gl_createList(arrayRubyObj, offset + 1))
  end
end

def gl_nil
  NilGlispObject.instance
end

def gl_cons(car, cdr)
  ConsGlispObject.new(car, cdr)
end

def gl_list(*x)
  if x.empty? then
    gl_nil
  else
    gl_cons(x[0], gl_list(*x[1..-1]))
  end
end

def gl_list2(e1, e2)
  gl_cons(e1, gl_cons(e2, nil))
end

# クラス階層図
# GlispObject
#   SymbolGlispObject
#   StringGlispObject
#   IntegerGlispObject
#   BooleanGlispObject
#   ProcGlispObject
#   LazyEvalGlispObject
#   ListGlispObject
#     NilGlispObject
#     ConsGlispObject
#     StackGetGlispObject
#     GlobalGetGlispObject

class GlispObject

  def ==(other)
    raise RuntimeError
    # 各サブクラスで再実装している
    # ただし、ListGlispObject のサブクラスでは再実装していない
  end

  def to_rubyObj
    raise RuntimeError
    # 各サブクラスで再実装している
    # ただし、ListGlispObject のサブクラスでは再実装していない
  end

  def to_s
    to_ss.join(' ')
  end

  # 文字列表現のもととなる文字列の配列を返す
  def to_ss
    raise RuntimeError
    # 各サブクラスで再実装している
    # ただし、ListGlispObject のサブクラスのうち NilGlispObject 以外では再実装していない
  end

  def to_ss_internal
    raise RuntimeError
    # ListGlispObject, NilGlispObject で再実装している
  end

  def is_list
    false
    # ListGlispObject で再実装している
  end

  def is_nil
    raise RuntimeError
    # ListGlispObject, NilGlispObject で再実装している
  end

  def to_boolean
    true
    # BooleanGlispObject, NilGlispObject で再実装している
  end

  def is_integer
    false
    # IntegerGlispObject で再実装している
  end

  def integer
    raise RuntimeError
    # IntegerGlispObject で再実装している
  end

  def integer_or(default)
    default
    # IntegerGlispObject で再実装している
  end

  def is_symbol
    false
    # SymbolGlispObject で再実装している
  end

  def symbol
    raise RuntimeError
    # SymbolGlispObject で再実装している
  end

  def symbol_or(default)
    default
    # SymbolGlispObject で再実装している
  end

  def is_undefined
    false
  end

  def is_lazy
    false
  end

  def length
    raise RuntimeError
    # ListGlispObject, NilGlispObject で再実装している
  end

  def car
    raise RuntimeError
    # ListGlispObject のサブクラスのうち NilGlispObject 以外で再実装している
  end

  def cdr
    raise RuntimeError
    # ListGlispObject のサブクラスのうち NilGlispObject 以外で再実装している
  end

  def car_or(default)
    default
    # ListGlispObject, NilGlispObject で再実装している
  end

  def car_symbol
    car_or(gl_nil).symbol_or(nil)
  end

  def cdr_or(default)
    default
    # ListGlispObject, NilGlispObject で再実装している
  end

  def caar
    car.car
  end

  def caar_or(default)
    car_or(gl_nil).car_or(default)
  end

  def cadar_or(default)
    car_or(gl_nil).cdr_or(gl_nil).car_or(default)
  end

  def cadr
    cdr.car
  end

  def cadr_or(default)
    cdr_or(gl_nil).car_or(default)
  end

  def caadr
    cdr.car.car
  end

  def cdadr
    cdr.car.cdr
  end

  def caddr_or(default)
    cdr_or(gl_nil).cdr_or(gl_nil).car_or(default)
  end

  # [存在するかどうかの論理値, 取得した値] を返す
  def get_by_index(index)
    [false, nil]
    # ListGlispObject, NilGlispObject で再実装している
  end

  # ((1 a) (2 b) (3 c)) のような形式でマップを表現されたときの
  # キーから値を取得する。各ペアの1つ目が値、2つ目がキー。
  # [インデックス, 取得した値] を返す。
  # 存在しない場合は [false, nil] を返す
  def get_by_key(key)
    [false, nil]
    # ListGlispObject, NilGlispObject で再実装している
  end

  # Rubyの配列に変換する
  def to_list
    raise RuntimeError
    # ListGlispObject, NilGlispObject で再実装している
  end

  def is_permanent
    true
    # SymbolGlispObject, ListGlispObject, NilGlispObject で再実装している
  end

  # (evalresult ...) の場合に evalresult を削除する
  def decode
    self
    # ListGlispObject, NilGlispObject で再実装している
  end

  # is_permanent でない場合に evalresult をつける
  def encode
    self
    # SymbolGlispObject, ListGlispObject, NilGlispObject で再実装している
  end

  # 返り値は [結果, step]。
  def eval(env, stack, step, level)
    [self, step]
    # SymbolGlispObject, ListGlispObject のサブクラスで再実装している
  end

  # 返り値は [結果, step, 評価が完了しているかどうか]。
  def eval_quote(env, stack, step, level, quote_depth)
    [self, step, true]
    # ListGlispObject, NilGlispObject で再実装している
  end

  # 返り値は eval と同じ仕様
  def eval_func_call(env, stack, step, level, args)
    [self, step]
    # ProcGlispObject, NilGlispObject, ConsGlispObject で再実装している
  end

  # 以下はlistについてのメソッド

  def eval_each(env, stack, step, level)
    new_car, step = car.eval(env, stack, step, level)
    return [gl_cons(new_car, cdr), step] if step == 0
    new_cdr, step = cdr.eval_each(env, stack, step, level)
    [gl_cons(new_car, new_cdr), step]
    # NilGlispObject で再実装している
  end

  def is_permanent_all
    return false if not car.is_permanent
    cdr.is_permanent_all
    # NilGlispObject で再実装している
  end

end # GlispObject

class SymbolGlispObject < GlispObject

  def initialize(sym)
    @sym = sym
  end

  def ==(other)
    other.is_a? SymbolGlispObject and other.symbol == symbol
  end

  def to_rubyObj
    @sym
  end

  def to_ss
    [@sym.to_s]
  end

  def is_symbol
    true
  end

  def symbol
    @sym
  end

  def symbol_or(default)
    @sym
  end

  def is_permanent
    false
  end

  def encode
    gl_list2(:evalresult, self)
  end

  def eval(env, stack, step, level)
    index, value = stack.get_by_key(self)
    if index then
      step = step - 1
      if value.is_lazy then
        # 参照先が lazy だった場合は評価をする
        return [StackGetGlispObject.new(index), step] if step == 0
        value, step = value.eval_lazy(env, stack, step, level)
        return [StackGetGlispObject.new(index), step] if step == 0 or value.is_lazy
        return [value, step - 1]
      elsif value.is_undefined then
        return [StackGetGlispObject.new(index), step]
      else
        return [value, step]
      end
    end
    exists, value, is_val = env.global.get(symbol)
    if exists then
      if level != EVAL_FINAL and not is_val then
        return [GlobalGetGlispObject.new(self), step - 1, false]
      else
        return [value, step - 1, true]
      end
    end
    return [self, step, false]
  end

end # SymbolGlispObject

class StringGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? StringGlispObject and other.val == val
  end

  def to_rubyObj
    @val
  end

  def to_ss
    [@val.inspect]
  end

end # SringGlispObject

class IntegerGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? IntegerGlispObject and other.val == val
  end

  def to_rubyObj
    @val
  end

  def to_ss
    [@val.inspect]
  end

  def is_integer
    true
  end

  def integer
    @val
  end

  def integer_or(default)
    @val
  end

end # IntegerGlispObject

class BooleanGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? BooleanGlispObject and other.val == val
  end

  def to_rubyObj
    @val
  end

  def to_ss
    [@val.inspect]
  end

  def to_boolean
    @val
  end

end # BooleanGlispObject

class ProcGlispObject < GlispObject

  def initialize(proc, can_calc_on_compile, name)
    @proc = proc
    @can_calc_on_compile = can_calc_on_compile
    @name = name
  end

  def ==(other)
    other.is_a? ProcGlispObject and other.proc == proc
  end

  def to_rubyObj
    @proc
  end

  def to_ss
    if @name then
      ['#<Proc:' + @name + '>']
    else
      [@proc.inspect]
    end
  end

  def proc
    @proc
  end

  def can_calc_on_compile
    @can_calc_on_compile
  end

  def eval_func_call(env, stack, step, level, args)
    args, step = args.eval_each(env, stack, step, level)
    return [gl_cons(self, args), step] if step == 0 or not args.is_permanent_all
    return [gl_cons(self, args), step] if level != EVAL_FINAL and not @can_calc_on_compile
    begin
      return [gl_create(@proc.call(* args.to_list)), step - 1]
    rescue => e
      return [gl_list(:throw,
                      '[%s] %s' % [e.class, e.message],
                      :Exception), step - 1]
    end
  end

end # ProcGlispObject

class LazyEvalGlispObject < GlispObject

  def initialize(body, stack)
    @body = body
    @stack = stack
  end

#  def to_ss
#    a = ['(', '#lazy', '(']
#    a.push(* @body.to_ss)
#    a.push(')', '(')
#    a.push(* @stack.to_ss)
#    a.push(')', ')')
#    return a
#  end

  def is_lazy
    true
  end

  def eval_lazy(env, stack, step, level)
    new_body, step = @body.eval(env, @stack, step, level)
    @body = new_body
    return [self, step] if not new_body.is_permanent
    [new_body, step]
  end

  def body
    @body
  end

end # LazyEvalGlispObject

class ListGlispObject < GlispObject

  def ==(other)
    return false if other == nil
    return false if not other.is_list
    return true if other.is_nil and self.is_nil
    return false if other.is_nil or self.is_nil
    return false if other.car != self.car
    return self.cdr == other.cdr
  end

  def to_rubyObj
    to_list
  end

  def to_ss
    a = ['(']
    a.push(* self.to_ss_internal)
    a.push(')')
    return a
  end

  def to_ss_internal
    a = []
    a.push(* car.to_ss)
    a.push(* cdr.to_ss_internal)
    return a
  end

  def is_list
    true
  end

  def is_nil
    false
  end

  def length
    cdr.length + 1
  end

  def car_or(default)
    car
  end

  def cdr_or(default)
    cdr
  end

  def get_by_index(index)
    if index == 0 then
      [true, car]
    elsif index < 0 then
      [false, nil]
    else
      cdr.get_by_index(index - 1)
    end
  end

  def get_by_key(key)
    if cadar_or(nil) == key then
      return [0, caar]
    end
    index, value = cdr.get_by_key(key)
    if index then
      return [index + 1, value]
    else
      [false, nil]
    end
  end

  def to_list
    list = self
    args = []
    while not list.is_nil
      args.push list.car
      list = list.cdr
    end
    args
  end

  def is_permanent
    car_symbol == :evalresult
  end

  def decode
    if car_symbol != :evalresult then
      raise RuntimeError
    end
    cadr # ここで例外は発生しないはず
  end

  def encode
    gl_list2(:evalresult, self)
  end

  def eval_quote(env, stack, step, level, quote_depth)
    sym = car_symbol
    value = cadr_or(nil)
    if sym == :quote then
      # eval から呼び出された最初は必ずこの分岐に入る
      if value == nil then
        return [gl_nil, step - 1, true]
      end
      value, step, completed = value.eval_quote(env, stack, step, level, quote_depth + 1)
      return [gl_list2(:quote, value), step, true] if quote_depth > 0 and completed
      return [gl_list2(:quote, value), step, false] if step == 0 or not completed
      return [gl_list2(:evalresult, value), step - 1, true]
    elsif sym == :unquote then
      if value == nil then
        return [gl_nil, step - 1, true]
      end
      if quote_depth == 1 then
        value, step = value.eval(env, stack, step, level)
        return [gl_list2(:unquote, value), step, false] if step == 0 or not value.is_permanent
        return [value.decode, step - 1, true]
      else
        value, step, completed = value.eval_quote(env, stack, step, level, quote_depth - 1)
        return [gl_list2(:unquote, value), step, completed]
      end
    else
      new_car, step, completed1 = car.eval_quote(env, stack, step, level, quote_depth)
      return [gl_cons(new_car, cdr), step, false] if step == 0
      new_cdr, step, completed2 = cdr.eval_quote(env, stack, step, level, quote_depth)
      return [gl_cons(new_car, new_cdr), step, completed1 && completed2]
    end
  end

#  def body_to_simple
#    if cdr.length == 0 then
#      car
#    else
#      gl_cons(:progn, self)
#    end
#  end

end # ListGlispObject

class NilGlispObject < ListGlispObject

  @@singleton = NilGlispObject.new

  def self.instance
    @@singleton
  end

  def to_ss
    return ['(', ')']
  end

  def to_ss_internal
    return []
  end

  def is_nil
    true
  end

  def to_boolean
    false
  end

  def length
    0
  end

  def car_or(default)
    default
  end

  def cdr_or(default)
    default
  end

  def get_by_index(index)
    [false, nil]
  end

  def get_by_key(key)
    [false, nil]
  end

  def to_list
    []
  end

  def is_permanent
    true
  end

  def decode
    self
  end

  def encode
    self
  end

  def eval(env, stack, step, level, args)
    [self, step]
  end

  def eval_quote(env, stack, step, level, quote_depth)
    [self, step, true]
  end

  def eval_func_call(env, stack, step, level, args)
    [self, step]
  end

  def eval_each(env, stack, step, level)
    [self, step]
  end

  def is_permanent_all
    true
  end

end # NilGlispObject

## ListGlispObjectのサブクラスの中で NilGlispObject 以外のすべてで共通のスーパークラス
#class BasicConsGlispObject < ListGlispObject
#
#  def initialize
#  end
#
#end # BasicConsGlispObject

class ConsGlispObject < ListGlispObject

  def initialize(car, cdr)
    @car = gl_create(car)
    @cdr = gl_create(cdr)
    if not @cdr.is_list then
      raise RuntimeError
    end
  end

  def car
    @car
  end

  def cdr
    @cdr
  end

  def eval(env, stack, step, level)

    sym = car_symbol

    # 以下の各命令は StackPushGlispObject など専用オブジェクトが生成されるはずだが、
    # 手動で生成した場合はここで処理する

#    if sym == :"stack-push" then
#      second = cdr_or_nill.car_or_nill
#      name = second.car_or(nil)
#      value = second.cdr_or_nill.car_or(nil)
#      body = cdr_or_nill.cdr_or_nill.car_or(nil)
#      if name.is_symbol and value != nil and body != nil then
#        return StackPushGlispObject.new(name.symbol, value, body).
#          eval(env, stack, step, level)
#      end
#      return [gl_list(:throw,
#                      'Illegal stack-push operator.',
#                      :Exception), step - 1, true]
#    end

    if sym == :"stack-get" then
      index = cardr_or(nil)
      if integer != nil && index.is_integer then
        return StackGetGlispObject.new(index.integer).eval(env, stack, step, level)
      end
      return [gl_list(:throw,
                      'Stack index needs Integer, but: %s' % [index],
                      :Exception), step - 1]
    end

    if sym == :"global-get" then
      name = carr_or(nil)
      if name != nil && name.is_symbol then
        return GlobalGetGlispObject.new(name).eval(env, stack, step, level)
      end
      return [gl_list(:throw,
                      'Global variable name needs Symbol, but: %s' % [name],
                      :Exception), step - 1]
    end

    # 以上の各命令は StackPushGlispObject など専用オブジェクトが生成されるはずだが、
    # 手動で生成した場合はここで処理する

    if sym == :"evalresult" then
      return [self, step]
    end

    if sym == :car then
      return _eval_car(env, stack, step, level)
    end

    if sym == :cdr then
      return _eval_cdr(env, stack, step, level)
    end

#    if sym == :cons then
#      return _eval_cons(env, stack, step, level)
#    end

    if sym == :quote then
      result, step, = eval_quote(env, stack, step, level, 0)
      return [result, step]
    end

#    if sym == :unquote then
#      return [gl_list(:throw,
#                      'Unexpected `unquote\'',
#                      :Exception), step - 1, true]
#    end
#
#    if sym == :func then
#      return _eval_func_def(env, stack, step, level)
#    end
#
#    if sym == :if then
#      return _eval_if(env, stack, step, level)
#    end

    new_car, step = car.eval(env, stack, step, level)
    args = cdr
    return [gl_cons(new_car, args), step, false] if step == 0
    if not new_car.is_permanent then
      if level != EVAL_FINAL then
        args, step = args.eval_each(env, stack, step, level)
      end
      return [gl_cons(new_car, args), step, false]
    end

    return new_car.eval_func_call(env, stack, step, level, args)

  end

  # carが :car の場合に eval から呼び出される
  def _eval_car(env, stack, step, level)
    begin
      arg = cadr
    rescue
      return [gl_list(:throw,
                      '\'Car\' needs an argument.',
                      :Exception), step - 1]
    end
    arg, step = arg.eval(env, stack, step, level)
    return [gl_list2(:car, arg), step] if step == 0 or not arg.is_permanent
    step = step - 1
    begin
      return [arg.decode.car.encode, step]
    rescue
      return [gl_list(:throw,
                      '\'Car\' needs a list argument.',
                      :Exception), step - 1]
    end
  end

  # carが :cdr の場合に eval から呼び出される
  def _eval_cdr(env, stack, step, level)
    begin
      arg = cadr
    rescue
      return [gl_list(:throw,
                      '\'Cdr\' needs an argument.',
                      :Exception), step - 1]
    end
    arg, step = arg.eval(env, stack, step, level)
    return [gl_list2(:cdr, arg), step] if step == 0 or not arg.is_permanent
    step = step - 1
    begin
      return [arg.decode.cdr.encode, step]
    rescue
      return [gl_list(:throw,
                      '\'Cdr\' needs a list argument.',
                      :Exception), step - 1]
    end
  end

#  def _eval_quote_all(env, stack, step, level)
#    begin
#      [cdr.car, step - 1, true]
#    rescue
#      return [gl_list(:throw,
#                      'Illegal quote-all operator.',
#                      :Exception), step - 1, true]
#    end
#  end

  def eval_func_call(env, stack, step, level, args)
    raise Exception # TODO
#    args = _args_to_lazy_if_need(args, stack)
#    vargs = cdr_or_nill.car_or_nill
#    body = cdr_or_nill.cdr_or_nill.car_or(nil)
#    c = _count_vargs(vargs)
#    step = step - 1
#    return [_create_expr_push_args_to_stack(body, vargs, _args_from_lazy(args)),
#            step, false] if step == 0
#    new_stack = _push_args_to_stack(new_stack, vargs, args)
#    body, step, completed = body.eval(env, new_stack, step, level)
#    return [_create_expr_push_args_to_stack(body, vargs, _args_from_lazy(args)),
#            step, false] if step == 0 or not completed
#    return _create_expr_push_args_to_stack(body, vargs, _args_from_lazy(args)).
#      eval(env, stack, step, level) if step < c
#    step = step - c
#    [body, step, true]
  end

#  def _args_to_lazy_if_need(args, stack)
#    if args.is_nil then
#      return args
#    end
#    b = _args_to_lazy_if_need(args.cdr, stack)
#    a = args.car
#    if not a.is_permanent then
#      a = LazyEvalGlispObject.new(a, stack)
#    end
#    gl_cons(a, b)
#  end
#
#  def _args_from_lazy(args)
#    if args.is_nil then
#      return args
#    end
#    b = _args_from_lazy(args.cdr)
#    a = args.car
#    if a.is_lazy then
#      a = a.body
#    end
#    gl_cons(a, b)
#  end
#
#  def _create_expr_push_args_to_stack(expr, vargs, args)
#    v = vargs.car_or(nil)
#    if v == nil then
#      return expr
#    end
#    begin
#      a = args.car
#      b = args.cdr
#    rescue
#      a = gl_nill
#      b = a
#    end
#    if v.is_symbol then
#      expr = StackPushGlispObject.new(v, a, expr)
#    end
#    _create_expr_push_args_to_stack(expr, vargs.cdr, b)
#  end
#
#  def _push_args_to_stack(stack, vargs, args)
#    v = vargs.car_or(nil)
#    if v == nil then
#      return stack
#    end
#    begin
#      a = args.car
#      b = args.cdr
#    rescue
#      a = gl_nill
#      b = a
#    end
#    if v.is_symbol then
#      stack = gl_cons(gl_list2(a, v), stack)
#    end
#    _push_args_to_stack(stack, vargs.cdr, b)
#  end
#
#  def _count_vargs(vargs)
#    v = vargs.car_or(nil)
#    if v == nil then
#      return 0
#    end
#    if v.is_symbol then
#      return _count_vargs(vargs.cdr) + 1
#    end
#    _count_vargs(vargs.cdr)
#  end
#
#  # carが :if の場合に eval から呼び出される
#  def _eval_if(env, stack, step, level)
#
#    cond      = cdr_or_nill.car_or(nil)
#
#    if cond == nil then
#      return [gl_list(:throw,
#                      'Illegal if operator.',
#                      :Exception), step - 1, true]
#    end
#
#    cond, step, completed = cond.eval(env, stack, step, level)
#    return [gl_cons(:if, gl_cons(cond, cdr_or_nill.cdr_or_nill)),
#            step, false] if step == 0 or not completed
#
#    if cond.to_boolean then
#      begin
#        then_expr = cdr_or_nill.cdr_or_nill.car
#        step = step - 1
#        return [then_expr, step, false] if step == 0
#        return then_expr.eval(env, stack, step, level)
#      rescue
#        return [gl_list(:throw,
#                        'Illegal if operator.',
#                        :Exception), step - 1, true]
#      end
#    else
#      begin
#        else_expr = cdr_or_nill.cdr_or_nill.cdr_or_nill.car
#        step = step - 1
#        return [else_expr, step, false] if step == 0
#        return else_expr.eval(env, stack, step, level)
#      rescue
#        return [gl_list(:throw,
#                        'Illegal if operator.',
#                        :Exception), step - 1, true]
#      end
#    end
#
#  end
#
#  def _eval_func_def(env, stack, step, level)
#
#    vargs = cdr_or_nill.car_or(nil)
#    body = cdr_or_nill.cdr_or_nill.car_or(nil)
#
#    stack = _push_vargs_to_stack(stack, vargs)
#
#    prev_step = step
#    body, step, completed = body.eval(env, stack, step, EVAL_FUNCTION_DEFINITION)
#    return [gl_list(:func, vargs, body), step, false] if step == 0
#    return [gl_list(:func, vargs, body), step, true]
#
#  end
#
#  def _push_vargs_to_stack(stack, vargs)
#    v = vargs.car_or(nil)
#    if v == nil then
#      return stack
#    end
#    stack = _push_vargs_to_stack(stack, vargs.cdr)
#    if not v.is_symbol then
#      return stack
#    end
#    gl_cons(gl_list2(UNDEFINED, v), stack)
#  end

end # ConsGlispObject

#class StackPushGlispObject < BasicConsGlispObject
#
#  @@symbolObj = SymbolGlispObject.new(:"stack-push")
#
#  # nameはRubyプリミティブのシンボル
#  def initialize(name, value, body)
#    @name = name
#    @value = value
#    @body = body
#  end
#
#  def car
#    @@symbolObj
#  end
#
#  def cdr
#    gl_list2(gl_list2(@name, @value), @body)
#  end
#
#  def is_permanent
#    false
#  end
#
#  def eval(env, stack, step, level)
#
#    if @value.is_permanent then
#      lazy = nil
#      new_stack = gl_cons(gl_list2(@value, @name), stack)
#    else
#      lazy = LazyEvalGlispObject.new(@value, stack)
#      new_stack = gl_cons(gl_list2(lazy, @name), stack)
#    end
#
#    new_body, step, completed = @body.eval(env, new_stack, step, level)
#    if lazy == nil then
#      new_value = @value
#    else
#      new_value = lazy.body
#    end
#    return [StackPushGlispObject.new(@name, new_value, new_body),
#            step, false]  if step == 0 or not completed
#    [new_body, step - 1, true]
#
#  end
#
#end # StackPushGlispObject

class StackGetGlispObject < ListGlispObject

  @@symbolObj = SymbolGlispObject.new(:"stack-get")

  # indexはRubyプリミティブの整数
  def initialize(index)
    @index = index
  end

  def car
    @@symbolObj
  end

  def cdr
    gl_cons(@index, nil)
  end

  def eval(env, stack, step, level)

    exists, value = stack.get_by_index(@index)

    if not exists then
      return [gl_list(:throw,
                      'Stack index is out of bound: %d' % [@index],
                      :Exception), step - 1]
    end

    value = value.car

    if value.is_lazy then
      # 参照先が lazy だった場合は評価をする
      value, step = value.eval_lazy(env, stack, step, level)
      return [self, step] if step == 0 or value.is_lazy
      [value, step - 1]
    elsif value.is_undefined then
      [self, step]
    else
      [value, step - 1]
    end

  end

end # StackGetGlispObject

class GlobalGetGlispObject < ListGlispObject

  @@symbolObj = SymbolGlispObject.new(:"global-get")

  # nameはGlispObject
  def initialize(name)
    @name = name
  end

  def car
    @@symbolObj
  end

  def cdr
    gl_cons(@name, nil)
  end

  def eval(env, stack, step, level)

    raise Exception, "TODO"

    [self, step]

  end

end # GlobalGetGlispObject

class InterpreterEnv

  def initialize
    @global = Global.new
  end

  def global
    @global
  end

end # InterpreterEnv

class Global

  def initialize
    @vals = {}
    @vars = {}
    _set_basic_object(:true, true)
    _set_basic_object(:false, false)
    _set_basic_operator(:+, true) do |*xs|
      xs.inject(0) {|a, b| a + b}
    end
    _set_basic_operator(:-, true) do |x, y|
      x - y
    end
    _set_basic_operator(:*, true) do |*xs|
      xs.inject(1) {|a, b| a * b}
    end
    _set_basic_operator(:/, true) do |x, y|
      x / y
    end
    _set_basic_operator(:%, true) do |x, y|
      x % y
    end
  end

  def get(symbol)
    if symbol.is_a? GlispObject then
      raise Excpetion, symbol.inspect
    end
    if @vals.has_key?(symbol) then
      [true, @vals[symbol], true]
    elsif @vars.has_key?(symbol) then
      [true, @vars[symbol], false]
    else
      [false, nil, false]
    end
  end

  def createVar(symbol)
    if symbol.is_a? GlispObject then
      raise Excpetion, symbol.inspect
    end
    @vars[symbol] = nil
  end

  def set(symbol, value)
    if symbol.is_a? GlispObject then
      raise Excpetion, symbol.inspect
    end
    if @vars.has_key?(symbol) then
      @vars[symbol] = value
    else
      @vals[symbol] = value
    end
  end

  def _set_basic_object(symbol, obj)
    @vals[symbol] = gl_create(obj)
  end

  def _set_basic_operator(symbol, can_calc_on_compile)
    f = proc do |*xs|
      args = xs.map {|x| x.to_rubyObj}
      ret = yield(*args)
      gl_create(ret)
    end
    @vals[symbol] = ProcGlispObject.new(f, can_calc_on_compile, symbol.to_s)
  end

end # Global

class Reader

  def initialize(io)
    @io = io
    @next = []
    @buf = []
    @line = nil
  end

  def read
    _read_expr
  end

  def _read_expr
    t = _read_token
    case t
    when :'(' then
      return _read_list
    when :')' then
      raise EvalException, 'unexpected: ' + t.to_s
    when :'`' then
      return gl_list2(:quote, _read_expr)
    when :',' then
      return gl_list2(:unquote, _read_expr)
    when :'.' then
      raise EvalException, 'unexpected: ' + t.to_s
    else
      return gl_create(t)
    end
  end

  def _read_list
    t = _read_token
    case t
    when :')' then
      return nil
    when EOF then
      raise EvalException, 'unexpected: ' + t.to_s
    else
      _read_back(t)
      head = _read_expr
      tail = _read_list
      return gl_cons(head, tail)
    end
  end

  def _read_back(token)
    @next.unshift(token)
  end

  def _read_token
    if ! @next.empty? then
      t = @next.shift
      return t
    end
    _read_tokens
    if @buf.empty? then
      return EOF
    end
    t = @buf.shift
    case t
    when '(', ')', '`', ',', '.' then
      token = t.to_sym
    when 'nil' then
      token = nil
    when 'true' then
      token = true
    when 'false' then
      token = false
    when /\A\".*\"\z/ then
      token = t[1..-2]
    else
      begin
        token = Integer(t)
      rescue ArgumentError
        begin
          token = Float(t)
        rescue ArgumentError
          token = t.to_sym
        end
      end
    end
  end

  def _read_tokens
    while @buf.empty? do
      _read_line
      if @line == nil then
        return
      end
      token_pattern = /\s+|;.*$|(".*?"|[^()`,][^() ]*|[()`,])/
      @line.chomp.scan(token_pattern) do |p|
        @buf.push(p[0]) if p[0]
      end
    end
  end

  def _read_line
    if @io == nil then
      return
    end
    @line = @io.gets
    if @line == nil then
      @io.close
      return
    end
  end

end # Reader

def do_test
  env = InterpreterEnv.new

  do_test_sub(env, "1",
              [
               '1',
              ])

  do_test_sub(env, "true",
              [
               'true',
              ])

  do_test_sub(env, "(car (evalresult (2 3 4)))",
              [
               '( car ( evalresult ( 2 3 4 ) ) )',
               '2',
              ])

  do_test_sub(env, "(cdr (evalresult (2 3 4)))",
              [
               '( cdr ( evalresult ( 2 3 4 ) ) )',
               '( evalresult ( 3 4 ) )',
              ])

  do_test_sub(env, "(+ 2 3)",
              [
               '( + 2 3 )',
               '( Proc* 2 3 )',
               '5',
              ])

  do_test_sub(env, "`(a b c ,(+ 2 3))",
              [
               '( quote ( a b c ( unquote ( + 2 3 ) ) ) )',
               '( quote ( a b c ( unquote ( Proc* 2 3 ) ) ) )',
               '( quote ( a b c ( unquote 5 ) ) )',
               '( quote ( a b c 5 ) )',
               '( evalresult ( a b c 5 ) )',
              ])

  do_test_sub(env, "`(a `(b ,,(+ 2 3)))",
              [
               '( quote ( a ( quote ( b ( unquote ( unquote ( + 2 3 ) ) ) ) ) ) )',
               '( quote ( a ( quote ( b ( unquote ( unquote ( Proc* 2 3 ) ) ) ) ) ) )',
               '( quote ( a ( quote ( b ( unquote ( unquote 5 ) ) ) ) ) )',
               '( quote ( a ( quote ( b ( unquote 5 ) ) ) ) )',
               '( evalresult ( a ( quote ( b ( unquote 5 ) ) ) ) )',
              ])

  do_test_sub(env, "(stack-push (a 1) (* (+ a 2) (+ a 3)))",
              [
               '( stack-push ( a 1 ) ( * ( + a 2 ) ( + a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* ( + a 2 ) ( + a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* ( Proc* a 2 ) ( + a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* ( Proc* 1 2 ) ( + a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* 3 ( + a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* 3 ( Proc* a 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* 3 ( Proc* 1 3 ) ) )',
               '( stack-push ( a 1 ) ( Proc* 3 4 ) )',
               '( stack-push ( a 1 ) 12 )',
               '12',
              ])

  do_test_sub(env, "(stack-push (a (+ 3 4)) (+ a 2))",
              [
               '( stack-push ( a ( + 3 4 ) ) ( + a 2 ) )',
               '( stack-push ( a ( + 3 4 ) ) ( Proc* a 2 ) )',
               '( stack-push ( a ( + 3 4 ) ) ( Proc* ( stack-get 0 ) 2 ) )',
               '( stack-push ( a ( Proc* 3 4 ) ) ( Proc* ( stack-get 0 ) 2 ) )',
               '( stack-push ( a 7 ) ( Proc* ( stack-get 0 ) 2 ) )',
               '( stack-push ( a 7 ) ( Proc* 7 2 ) )',
               '( stack-push ( a 7 ) 9 )',
               '9',
              ])

  do_test_sub(env, "(if false (/ 1 0) (car (3 1)))",
              [
               '( if false ( / 1 0 ) ( car ( 3 1 ) ) )',
               '( car ( 3 1 ) )',
               '3',
              ])

  do_test_sub(env, "(stack-push (c 1) (func (a b) (+ (* a b) c)))",
              [
               '( stack-push ( c 1 ) ( func ( a b ) ( + ( * a b ) c ) ) )',
               '( stack-push ( c 1 ) ( func ( a b ) ( Proc* ( * a b ) c ) ) )',
               '( stack-push ( c 1 ) ( func ( a b ) ( Proc* ( Proc* a b ) c ) ) )',
               '( stack-push ( c 1 ) ( func ( a b ) ( Proc* ( Proc* ( stack-get 0 ) b ) c ) ) )',
               '( stack-push ( c 1 ) ( func ( a b ) ( Proc* ( Proc* ( stack-get 0 ) ( stack-get 1 ) ) c ) ) )',
               '( stack-push ( c 1 ) ( func ( a b ) ( Proc* ( Proc* ( stack-get 0 ) ( stack-get 1 ) ) 1 ) ) )',
               '( func ( a b ) ( Proc* ( Proc* ( stack-get 0 ) ( stack-get 1 ) ) 1 ) )',
              ])

  do_test_sub(env, '((func (a b) (* a b)) 3 4)',
              [
               '( ( func ( a b ) ( * a b ) ) 3 4 )',
               '( ( func ( a b ) ( Proc* a b ) ) 3 4 )',
               '( ( func ( a b ) ( Proc* ( stack-get 0 ) b ) ) 3 4 )',
               '( ( func ( a b ) ( Proc* ( stack-get 0 ) ( stack-get 1 ) ) ) 3 4 )',
               '( stack-push ( b 4 ) ( stack-push ( a 3 ) ( Proc* ( stack-get 0 ) ( stack-get 1 ) ) ) )',
               '( stack-push ( b 4 ) ( stack-push ( a 3 ) ( Proc* 3 ( stack-get 1 ) ) ) )',
               '( stack-push ( b 4 ) ( stack-push ( a 3 ) ( Proc* 3 4 ) ) )',
               '( stack-push ( b 4 ) ( stack-push ( a 3 ) 12 ) )',
               '( stack-push ( b 4 ) 12 )',
               '12',
              ])

  do_test_sub(env, "((func (f) (func (x) (+ x 1))) 3)",
              [
               '( ( func ( f ) ( func ( x ) ( + x 1 ) ) ) 3 )',
               '( ( func ( f ) ( func ( x ) ( Proc* x 1 ) ) ) 3 )',
               '( ( func ( f ) ( func ( x ) ( Proc* ( stack-get 0 ) 1 ) ) ) 3 )',
               '( stack-push ( f 3 ) ( func ( x ) ( Proc* ( stack-get 0 ) 1 ) ) )',
               '( func ( x ) ( Proc* ( stack-get 0 ) 1 ) )',
              ])

  do_test_sub(env, "((func (f) (func (x) (f (f x)))) (func (x) (+ x (+ 2 3))))",
              [
               '( ( func ( f ) ( func ( x ) ( f ( f x ) ) ) ) ( func ( x ) ( + x ( + 2 3 ) ) ) )',
               '( ( func ( f ) ( func ( x ) ( ( stack-get 1 ) ( f x ) ) ) ) ( func ( x ) ( + x ( + 2 3 ) ) ) )',
               '( ( func ( f ) ( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) x ) ) ) ) ( func ( x ) ( + x ( + 2 3 ) ) ) )',
               '( ( func ( f ) ( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ) ( func ( x ) ( + x ( + 2 3 ) ) ) )',
               '( stack-push ' +
                 '( f ( func ( x ) ( + x ( + 2 3 ) ) ) ) ' +
                 '( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* x ( + 2 3 ) ) ) ) ' +
                 '( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) ( + 2 3 ) ) ) ) ' +
                 '( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) ( Proc* 2 3 ) ) ) ) ' +
                 '( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
                 '( func ( x ) ( ( stack-get 1 ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
                 '( func ( x ) ( ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ( ( stack-get 1 ) ( stack-get 0 ) ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
                 '( func ( x ) ( stack-push ( x ( ( stack-get 1 ) ( stack-get 0 ) ) ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
                 '( func ( x ) ( stack-push ( x ( ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ( stack-get 0 ) ) ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
               ')',
               '( stack-push ' +
                 '( f ( func ( x ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
                 '( func ( x ) ( stack-push ( x ( stack-push ( x ( stack-get 0 ) ) ( Proc* ( stack-get 0 ) 5 ) ) ) ( Proc* ( stack-get 0 ) 5 ) ) ) ' +
               ')',
               '( func ( x ) ( stack-push ( x ( stack-push ( x ( stack-get 0 ) ) ( Proc* ( stack-get 0 ) 5 ) ) ) ( Proc* ( stack-get 0 ) 5 ) ) )',
              ])

end

def do_test_sub(env, str, expected_patterns)
  io = StringIO.new(str)
  reader = Reader.new(io)
  expr = reader.read
  _test_eval_expr(expr, env, expected_patterns)
  _test_eval_expr2(expr, env, expected_patterns)
  print "\n"
end

def _test_convert_pattern(pattern)
  Regexp.new('^' + pattern.gsub(/\+/, '\\\\+').gsub(/\*/, '\\\\*').
             gsub(/\(/, '\(').gsub(/\)/, '\)') + '$')
end

def _test_convert_expr(expr)
  # expr.to_s.gsub(/Proc/, 'proc')
  expr.to_s.gsub(/#<Proc:[^>]+>/, 'Proc*')
end

def _test_eval_expr(expr, env, expected_patterns)
  offset = 0
  step = 0
  while true

    expr_s = _test_convert_expr(expr)

    print "%d expr:           %s\n" % [offset, expr_s]

    if offset >= expected_patterns.length then
      print "FAILED! Too much!\n"
      break
    end
    pattern = expected_patterns[offset]
    pattern_regexp = _test_convert_pattern(pattern)
    offset = offset + 1
    if not pattern_regexp =~ expr_s then
      print "FAILED! Expected: %s\n" % [pattern]
      break
    end
    STDOUT.flush

    if expr.is_permanent then
      break
    end

    expr, step = expr.eval(env, gl_create([]), 1, EVAL_FINAL)

  end
  STDOUT.flush
end

def _test_eval_expr2(expr, env, expected_patterns)

  expr, step = expr.eval(env, gl_create([]), -1, EVAL_FINAL)

  expr_s = _test_convert_expr(expr)
  pattern = expected_patterns[-1]
  pattern_regexp = _test_convert_pattern(pattern)
  if not pattern_regexp =~ expr_s then
    print "(total)\nFAILED! Expected: %s\n             but: %s\n" % [pattern, expr_s]
    return
  end

  if step != (- expected_patterns.length) then
    print "(total)\nFAILED! step = %d\n" % [step]
    return
  end

end

if __FILE__ == $PROGRAM_NAME then
  do_test
end



