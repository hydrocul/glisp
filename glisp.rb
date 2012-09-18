#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

EOF = :"$eof"
UNDEFINED = :"$undefined-on-compile"

EVAL_FINAL = 1
EVAL_FUNCTION_DEFINITION = 2
EVAL_OPTIMIZATION = 3

def gl_create(rubyObj)
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
    _gl_createList(rubyObj, 0)
  elsif rubyObj == nil then
    gl_nill
  else
    raise Exception, rubyObj.inspect
  end
end

def _gl_createList(arrayRubyObj, offset)
  if offset == arrayRubyObj.length then
    gl_nill
  else
    gl_cons(arrayRubyObj[offset], _gl_createList(arrayRubyObj, offset + 1))
  end
end

def gl_nill
  NilGlispObject.instance
end

def gl_cons(car, cdr)
  ConsGlispObject.new(car, cdr)
end

def gl_list(*x)
  if x.empty? then
    gl_nill
  else
    gl_cons(x[0], gl_list(*x[1..-1]))
  end
end

def gl_list2(e1, e2)
  gl_cons(e1, gl_cons(e2, nil))
end

class GlispObject

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

  def eval(env, stack, step, level)
    [self, step]
  end

  # (quote ...) の場合に quote を削除する
  def eval_force
    self
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

  def eval(env, stack, step, level)
    index, value = stack.get_by_key(self)
    if index then
      if level == EVAL_FINAL or value != UNDEFINED then
        # 参照先が SelfRefGlispObject だった場合は参照解決をしない
        if not value.is_a? SelfRefGlispObject then
          return [value, step - 1]
        end
      end
      return [StackGetGlispObject.new(index), step - 1]
    end
    exists, value, is_val = env.global.get(symbol)
    if exists then
      if level == EVAL_FINAL or is_val then
        return [value, step - 1]
      end
      return [GlobalGetGlispObject.new(self), step - 1]
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
  # スタックにのみこのオブジェクトが格納され、
  # 構文木やグローバル変数にはこのオブジェクトは格納されない。
  # stack-get命令やシンボルの参照先が SelfRefGlispObject だった場合は、
  # 評価してもstack-get命令のままとする。

  def initialize(target)
    @target = target
  end

  def target
    @target
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

  def car
    raise Exception
  end

  def cdr
    raise Exception
  end

  def car_or(default)
    car
  end

  def cdr_or(default)
    cdr
  end

  def car_or_nill
    car_or(NilGlispObject.instance)
  end

  def cdr_or_nill
    cdr_or(NilGlispObject.instance)
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
      gl_cons(:progn, self)
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

  def car_or(default)
    default
  end

  def cdr_or(default)
    default
  end

  # carがシンボルの場合にRubyオブジェクトでシンボルを取得する
  # シンボルでない場合はnilを返す
  def car_to_sym
    a = car_or(nil)
    if a.is_a? SymbolGlispObject then
      a.symbol
    else
      nil
    end
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
    @car = gl_create(car)
    @cdr = gl_create(cdr)
  end

  def car
    @car
  end

  def cdr
    @cdr
  end

  def eval(env, stack, step, level)

    sym = car_to_sym

    if sym == :"stack-get" then
      # 通常は stack-get 命令は StackGetGlispObject が生成されるはずだが、
      # 手動で生成した場合はここで処理する
      index = cdr_or_nill.car_or(nil)
      if index.is_a? NumberGlispObject and index.val.is_a? Integer then
        return StackGetGlispObject.new(index.val).eval(env, stack, step, level)
      end
      return [gl_list(:throw,
                      'Stack index needs Integer, but: %s' % [index],
                      :Exception), step - 1]
    end

    if sym == :"global-get" then
      # 通常は global-get 命令は GlobalGetGlispObject が生成されるはずだが、
      # 手動で生成した場合はここで処理する
      name = cdr_or_nill.car_or(nil)
      if name.is_a? SymbolGlispObject then
        return GlobalGetGlispObject.new(name).eval(env, stack, step, level)
      end
      return [gl_list(:throw,
                      'Global variable name needs Symbol, but: %s' % [name],
                      :Exception), step - 1]
    end

    if sym == :car then
      return _eval_car(env, stack, step, level)
    end

    if sym == :cdr then
      return _eval_cdr(env, stack, step, level)
    end

    if sym == :cons then
      return _eval_cons(env, stack, step, level)
    end

    if sym == :quote then
      return _eval_quote(env, stack, step, level)
    end

    if sym == :unquote then
      return eval_force.eval(env, stack, step, level)
    end

    if sym == :func then
      # TODO
    end

    if sym == :selfref then
      # TODO
    end

    if sym == :if then
      # TODO
    end

    return _eval_func_call(env, stack, step, level)

  end

  def _eval_car(env, stack, step, level)
    begin
      [cdr.car.car, step - 1]
    rescue
      if cdr.car_or(nil) == nil then
        return [gl_list(:throw,
                        '\'Car\' needs an argument.',
                        :Exception), step - 1]
      else
        return [gl_list(:throw,
                        '\'Car\' needs list.',
                        :Exception), step - 1]
      end
    end
  end

  def _eval_cdr(env, stack, step, level)
    begin
      [cdr.car.cdr, step - 1]
    rescue
      if cdr.car_or(nil) == nil then
        return [gl_list(:throw,
                        '\'Cdr\' needs an argument.',
                        :Exception), step - 1]
      else
        return [gl_list(:throw,
                        '\'Cdr\' needs list.',
                        :Exception), step - 1]
      end
    end
  end

  def _eval_quote(env, stack, step, level)
    _eval_quote_sub(env, stack, step, level, 0)
  end

  def _eval_quote_sub(env, stack, step, level, quote_depth)
    sym = car_to_sym
    value = cdr.car_or(nil)
    if sym == :quote then
      # eval から呼び出された最初は必ずこの分岐に入る
      if value == nil then
        return [gl_list(:throw,
                        '\'Quote\' needs an argument.',
                        :Exception), step - 1]
      end
      value, step = value._eval_quote_sub(env, stack, step, level, quote_depth + 1)
      [List.list2(:quote, value), step]
    elsif sym == :unquote then
      if value == nil then
        return [gl_list(:throw,
                        '\'Unquote\' needs an argument.',
                        :Exception), step - 1]
      end
      if quote_level == 1 then
        prev_step = step
        value, step = value.eval(env, stack, step, level)
        return [gl_cons(:unquote, value), step] if step == 0
        # if step == prev_step
        [value.eval_force, step - 1]
      else
        value, step = value._eval_quote_sub(env, stack, step, level, quote_depth - 1)
        [gl_cons(:quote, value), step]
      end
    else
      new_car = car._eval_quote_sub(env, stack, step, level, quote_depth)
      return [gl_cons(new_car, cdr), step] if step == 0
      new_cdr = cdr._eval_quote_sub(env, stack, step, level, quote_depth)
      [gl_cons(new_car, cdr), step]
    end
  end

  def _eval_func_call(env, stack, step, level)
    # TODO
  end

  def eval_force
    sym = car_to_sym
    if sym == :quote then
      cdr_or_nill.car_or_nill
    else
      self
    end
  end

end # ConsGlispObject

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

    # stack-get は参照先が SelfRefGlispObject だった場合は参照解決をしない

    # TODO

    [self, step]

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

    # stack-get は参照先が SelfRefGlispObject だった場合は参照解決をしない

    # TODO

    [self, step]

  end

end # StackGetGlispObject

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
      return gl_list2(:quote, _read_expr)
    when :',' then
      return gl_list2(:unquote, _read_expr)
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

  do_test_sub(env, "`(a b c)",
              '( quote ( a b c ) )')

end

def do_test_sub(env, str, expected_pattern)
  expected_pattern_regexp = _test_convert_pattern(expected_pattern)
  io = StringIO.new(str)
  reader = Reader.new(io)
  expr = reader.read
  result = repl_eval_expr(expr, env).to_s
  if not expected_pattern_regexp =~ result then
    print "FAILED! Expected: %s\n" % [expected_pattern]
  end
  print "\n"
end

def _test_convert_pattern(pattern)
  Regexp.new('^' + pattern.gsub(/\(/, '\(').gsub(/\)/, '\)').gsub(/\*/, '[^>]+') + '$')
end

def repl_eval_expr(expr, env)
  print "expr: %s\n" % [expr.to_s]
  STDOUT.flush
  while true
    expr, step = expr.eval(env, [], 1, EVAL_FINAL)
    print "expr: %s\n" % [expr.to_s]
    STDOUT.flush
    if step > 0 then
      return expr
    end
  end
end

if __FILE__ == $PROGRAM_NAME then
  do_test
end



