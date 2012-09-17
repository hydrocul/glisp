#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

EOF = :"$eof"
UNDEFINED = :"$undefined"

EVAL_FINAL = 1
EVAL_FUNCTION_DEFINITION = 2
EVAL_OPTIMIZATION = 3
EVAL_SELF_REF = 4

class GlispObject

  def self.create(rubyObj)
    if rubyObj.is_a? GlispObject then
      rubyObj
    elsif rubyObj.is_a? Symbol then
      SymbolGlispObject.new(rubyObj)
    elsif rubyObj.is_a? String then
      StringGlispObject.new(rubyObj)
    elsif rubyObj.is_a? Integer then
      NumberGlispObject.new(rubyObj)
    elsif rubyObj.is_a? Float then
      NumberGlispObject.new(rubyObj)
    elsif rubyObj == false or rubyObj == true then
      BooleanGlispObject.new(rubyObj)
    elsif rubyObj.is_a? Proc then
      ProcGlispObject.new(rubyObj)
    elsif rubyObj.is_a? Array then
      if rubyObj.length == 0 then
        ConsGlispObject.nill
      else
        ConsGlispObject.cons(create(rubyObj[0]), create(rubyObj.slice(1..-1)))
      end
    else
      raise Exception, rubyObj.inspect
    end
  end

  def to_rubyObj
    self
  end

  def to_s
    to_ss.join(' ')
  end

  # 文字列表現のもととなる文字列の配列を返す
  def to_ss
    [inspect]
  end

  def is_list
    false
  end

  def eval(expr, env, stack, step, level)
    [expr, step]
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
    sym
  end

  def to_ss
    [@sym.to_s]
  end

  def symbol
    @sym
  end

  def eval(expr, env, stack, step, level)
    index, value = stack.get_by_key(self)
    if index then
      if level == EVAL_FINAL or value != UNDEFINED then
        return [value, step - 1]
      end
      return [List.list(:"stack-get", index), step - 1]
    end
    exists, value, is_val = env.global.get(symbol)
    if exists then
      if level == EVAL_FINAL or is_val then
        return [value, step - 1]
      end
      return [List.list(:"global-get", symbol), step - 1]
    end
    return [self, step]
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
    val
  end

  def to_ss
    [@val.inspect]
  end

  def val
    @val
  end

end # SringGlispObject

class NumberGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? NumberGlispObject and other.val == val
  end

  def to_rubyObj
    val
  end

  def to_ss
    [@val.inspect]
  end

  def val
    @val
  end

end # NumberGlispObject

class BooleanGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? BooleanGlispObject and other.val == val
  end

  def to_rubyObj
    val
  end

  def to_ss
    [@val.inspect]
  end

  def val
    @val
  end

end # BooleanGlispObject

class ProcGlispObject < GlispObject

  def initialize(proc, can_calc_on_compile)
    @proc = proc
    @can_calc_on_compile = can_calc_on_compile
  end

  def ==(other)
    other.is_a? ProcGlispObject and other.proc == proc
  end

  def to_rubyObj
    val
  end

  def to_ss
    [@proc.inspect]
  end

  def proc
    @proc
  end

  def can_calc_on_compile
    @can_calc_on_compile
  end

end # ProcGlispObject

class SelfRefGlispObject < GlispObject

  def initialize
    @list = nil
  end

  def target_list
    @list
  end

  def set_target_list(target)
    @list = target
  end

end # SelfRefGlispObject

class ListGlispObject < GlispObject

  def ==(other)
    if not other.is_a? ListGlispObject then
      return false
    end
    if other.is_nil and self.is_nil then
      return true
    end
    if other.is_nil or self.is_nil then
      return false
    end
    if other.car != self.car then
      return false
    end
    return self.cdr == other.cdr
  end

  def to_rubyObj
    to_list
  end

  def to_ss
    a = ['(']
    a.push(* car.to_ss)
    a.push(* cdr.to_ss)
    a.push(')')
    return a
  end

  def to_ss_internal
    a = ['(']
    a.push(* car.to_ss)
    a.push(* cdr.to_ss_internal)
    a.push(')')
    return a
  end

  def is_list
    true
  end

  def is_nil
    false
  end

  def car
    raise Exception
  end

  def cdr
    raise Exception
  end

  def car_or(default)
    default
  end

  def cdr_or(default)
    default
  end

  def length
    cdr.length + 1
  end

  # [存在するかどうかの論理値, 取得した値] を返す
  def get_by_index(index)
    if index == 0 then
      [true, car]
    elsif index < 0 then
      [false, nil]
    else
      cdr.get_by_index(index - 1)
    end
  end

  # ((a 1) (b 2) (c 3)) のような形式でマップを表現されたときの
  # キーから値を取得する。
  # [インデックス, 取得した値] を返す。
  # 存在しない場合は [false, nil] を返す
  def get_by_key(key)
    if car.car_or(nil) == key then
      return [0, car.cdr.car]
    end
    index, value = cdr.get_by_key(key)
    if index then
      return [index + 1, value]
    else
      [false, nil]
    end
  end

  # Rubyの配列に変換する
  def to_list
    list = self
    args = []
    while not list.is_nil
      args.push list.car
      list = list.cdr
    end
    args
  end

  def body_to_simple
    if cdr.length == 0 then
      car
    else
      ConsGlispObject.cons(:progn, self)
    end
  end

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

  def length
    0
  end

  def get_by_index(index)
    [false, nil]
  end

  def get_by_key(key)
    [false, nil]
  end

end # NilGlispObject

class ConsGlispObject < ListGlispObject

  def initialize(car, cdr)
    if not car.is_a? GlispObject then
      raise Exception, car.inspect
    end
    if not cdr.is_a? ListGlispObject then
      raise Exception, cdr.inspect
    end
    @car = car
    @cdr = cdr
  end

  def self.nill
    NilGlispObject.instance
  end

  def self.cons(car, cdr)
    self.new(car, cdr)
  end

  def self.list(*x)
    if x.empty? then
      NilGlispObject.instance
    else
      List.new(GlispObject.create(x[0]), List.list(*x[1..-1]))
    end
  end

  def self.list2(e1, e2)
    List.cons(GlispObject.create(e1), List.cons(GlispObject.create(e2), self.nill))
  end

  def car
    @car
  end

  def cdr
    @cdr
  end

  def car_or(default)
    @car
  end

  def cdr_or(default)
    @cdr
  end

end # ConsGlispObject

class InterpreterEnv

  def initialize
    @global = Global.new
  end

end # InterpreterEnv

class Global

  def initialize
    @vals = {}
    @vars = {}
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
      return List.list(:quote, _read_expr)
    when :',' then
      return List.list(:unquote, _read_expr)
    when :'.' then
      raise EvalException, 'unexpected: ' + t.to_s
    else
      return t
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
      return List.new(head, tail)
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

if __FILE__ == $PROGRAM_NAME
end



