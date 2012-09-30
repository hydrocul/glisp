#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

def gl_create(rubyObj)
  if rubyObj.is_a? GlispObject then
    rubyObj
  elsif rubyObj.is_a? Symbol then
    SymbolGlispObject.new(rubyObj)
  elsif rubyObj.is_a? String then
    StringGlispObject.new(rubyObj)
  elsif rubyObj.is_a? Integer then
    IntegerGlispObject.new(rubyObj)
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
#   NilGlispObject
#   ConsGlispObject

class GlispObject

  def ==(other)
    raise RuntimeError
    # 各サブクラスで再実装している
  end

  def eq?(other)
    self == other
  end

  def to_rubyObj
    raise RuntimeError
    # 各サブクラスで再実装している
  end

  def to_s
    to_ss.join(' ')
  end

  # 文字列表現のもととなる文字列の配列を返す
  def to_ss
    raise RuntimeError
    # 各サブクラスで再実装している
  end

  def to_ss_internal
    raise RuntimeError
    # ConsGlispObject, NilGlispObject で再実装している
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

  def is_string
    false
    # StringGlispObject で再実装している
  end

  def string
    raise RuntimeError
    # StringGlispObject で再実装している
  end

  def string_or(default)
    default
    # StringGlispObject で再実装している
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

  def to_boolean
    true
    # BooleanGlispObject, NilGlispObject で再実装している
  end

  def is_list
    false
    # ConsGlispObject, NilGlispObject で再実装している
  end

  def is_nil
    raise RuntimeError
    # ConsGlispObject, NilGlispObject で再実装している
  end

  # Rubyの配列に変換する
  def array
    raise RuntimeError
    # ConsGlispObject, NilGlispObject で再実装している
  end

  def is_undefined
    false
    # UndefinedGlispObject で再実装している
  end

  def length
    raise RuntimeError
    # ConsGlispObject, NilGlispObject で再実装している
  end

  def car
    raise RuntimeError
    # ConsGlispObject で再実装している
  end

  def cdr
    raise RuntimeError
    # ConsGlispObject で再実装している
  end

  def car_or(default)
    default
    # ConsGlispObject で再実装している
  end

  def cdr_or(default)
    default
    # ConsGlispObject で再実装している
  end

  def car_symbol_or(default)
    car_or(gl_nil).symbol_or(default)
  end

  def car_car_or(default)
    car_or(gl_nil).car_or(default)
  end

  # [存在するかどうかの論理値, 取得した値] を返す
  def get_by_index(index)
    [false, nil]
    # ConsGlispObject で再実装している
  end

  # ((a 1) (b 2) (c 3)) のような形式でマップを表現されたときの
  # キーから値を取得する。各ペアの1つ目がキー、2つ目が値。
  # [インデックス, 取得した値] を返す。
  # 存在しない場合は [false, nil] を返す
  def get_by_key(key)
    [false, nil]
    # ConsGlispObject で再実装している
  end

  def is_permanent
    true
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # (eval-result ...) の場合に eval-result を削除する
  def decode
    self
    # ConsGlispObject で再実装している
  end

  # is_permanent でない場合に eval-result をつける
  def encode
    self
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [結果, step]。
  def eval(env, step)
    [self, step]
    # SymbolGlispObject, ConsGlispObject のサブクラスで再実装している
  end

  # 返り値は [結果, env, step]。
  def eval_progn_def(env, step)
    [self, env, step]
    # ConsGlispObject のサブクラスで再実装している
  end

  # 返り値は [結果, env, step]。
  def eval_progn_last(env, step)
    [self, env, step]
    # SymbolGlispObject, ConsGlispObject のサブクラスで再実装している
  end

  # 返り値は [結果, env, step]。
  def eval_progn_repl(env, step)
    [self, env, step]
    # SymbolGlispObject, ConsGlispObject のサブクラスで再実装している
  end

  # 返り値は [結果, step, 評価が完了しているかどうか]。
  def eval_quote(env, stack, step, quote_depth)
    [self, step, true]
    # ConsGlispObject で再実装している
  end

  # 返り値は [結果, step]。
  def eval_func_call(env, stack, step, level, args)
    [self, step]
    # ProcGlispObject, ConsGlispObject で再実装している
  end

  # 以下はlistについてのメソッド

  def is_permanent_all
    return false if not car.is_permanent
    return cdr.is_permanent_all
    # NilGlispObject で再実装している
  end

end # GlispObject

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

class NilGlispObject < GlispObject

  @@singleton = NilGlispObject.new

  def self.instance
    @@singleton
  end

  def ==(other)
    return false if not other.is_list
    return true if other.is_nil
    return false
  end

  def to_rubyObj
    []
  end

  def to_ss
    ['(', ')']
  end

  def to_ss_internal
    []
  end

  def to_boolean
    false
  end

  def is_list
    true
  end

  def is_nil
    true
  end

  # Rubyの配列に変換する
  def array
    []
  end

  def length
    0
  end

  def is_permanent_all
    return true
  end

end # NilGlispObject

class ConsGlispObject < GlispObject

  def initialize(car, cdr)
    @car = gl_create(car)
    @cdr = gl_create(cdr)
    @result = nil
    if not @cdr.is_list then
      raise RuntimeError
    end
  end

  def ==(other)
    return false if not other.is_list
    return false if other.is_nil
    return false if other.car != self.car
    return self.cdr == other.cdr
  end

  def to_rubyObj
    array
  end

  # 文字列表現のもととなる文字列の配列を返す
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

  def array
    list = self
    args = []
    while not list.is_nil
      args.push list.car
      list = list.cdr
    end
    args
  end

  def length
    cdr.length + 1
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
    if car_car_or(nil) == key then
      return [0, car.cdr.car]
    end
    index, value = cdr.get_by_key(key)
    if index then
      return [index + 1, value]
    else
      [false, nil]
    end
  end

  def is_permanent
    car_symbol_or == :"eval-result"
  end

  def decode
    if car_symbol_or != :"eval-result" then
      raise RuntimeError
    end
    cdr.car
  end

  def encode
    gl_list2(:"eval-result", self)
  end

  def eval(env, step)
    raise RuntimeError, "TODO"
  end

  def eval_progn_def(env, step)
    raise RuntimeError, "TODO"
  end

  def eval_progn_last(env, step)
    raise RuntimeError, "TODO"
  end

  def eval_progn_repl(env, step)
    raise RuntimeError, "TODO"
  end

  def eval_quote(env, stack, step, quote_depth)
    raise RuntimeError, "TODO"
  end

  def eval_func_call(env, stack, step, level, args)
    raise RuntimeError, "TODO"
  end

end # ConsGlispObject

class InterpreterEnv

  def initialize(primitives = false, globals = false)
    if primitives == false then
      @primitives = gl_nil
    else
      @primitives = primitives
    end
    if globals == false then
      @globals = gl_nil
    else
      @globals = globals
    end
  end

  def push(key, value)
    InterpreterEnv.new(@primitives, gl_cons(gl_list2(key, value), @globals))
  end

end # InterpreterEnv

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

#  do_test_sub(env,
#              '"abc"',
#              [
#               '"abc"',
#              ])

  do_test_sub(env,
              '1',
              [
               '1',
              ])

  do_test_sub(env,
              '(+ 1 2)',
              [
               '( + 1 2 )',
               '3',
              ])

end

def do_test_sub(env, str, expected_patterns)
  io = StringIO.new(str)
  reader = Reader.new(io)
  expr = reader.read
  env1 = test_eval_step(expr, env, expected_patterns)
  env2 = test_eval_whole(expr, env, expected_patterns)
  if env1 != env2 then
    print "FAILED! env mismatch\n"
  end
  print "\n"
  env2
end

def pattern_to_regex(pattern)
  Regexp.new('^' + pattern.gsub(/\+/, '\\\\+').gsub(/\*/, '\\\\*').
             gsub(/\(/, '\(').gsub(/\)/, '\)') + '$')
end

def expr_to_string(expr)
  expr.to_s
end

def test_eval_step(expr, env, expected_patterns)

  offset = 0
  step = 0
  while true

    expr_s = expr_to_string(expr)

    print "%d expr:           %s\n" % [offset, expr_s]

    if offset >= expected_patterns.length then
      print "FAILED! Too much!\n"
      break
    end
    pattern = expected_patterns[offset]
    pattern_regexp = pattern_to_regex(pattern)
    offset = offset + 1
    if not pattern_regexp =~ expr_s then
      print "FAILED! Expected: %s\n" % [pattern]
      break
    end

    if expr.is_permanent then
      break
    end

    expr, env, step = expr.eval_progn_repl(env, 1)

  end

  env

end

def test_eval_whole(expr, env, expected_patterns)

  expr, env, step = expr.eval_progn_repl(env, -1)

  expr_s = expr_to_string(expr)
  pattern = expected_patterns[-1]
  pattern_regexp = pattern_to_regex(pattern)
  if not pattern_regexp =~ expr_s then
    print "(total)\nFAILED! Expected: %s\n             but: %s\n" % [pattern, expr_s]
    return env
  end

  if step != (- expected_patterns.length) then
    print "(total)\nFAILED! step = %d\n" % [step]
    return env
  end

  env

end

if __FILE__ == $PROGRAM_NAME then
  do_test
end

