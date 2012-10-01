#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

EOF = :"$EOF"

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
#   UndefinedGlispObject
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

  def cdr_car_or(default)
    cdr_or(gl_nil).car_or(default)
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

  def push_pair(key, value)
    gl_cons(gl_list2(key, value), self)
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

  # 返り値は [result, stack, step]。
  def eval_repl(stack, step)
    [self, stack, step]
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [result, step]。
  # シンボルの解決は eval_symbol で行い、このメソッドではシンボルはそのままにする
  def eval(step)
    [self, step]
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [result, step]。
  # 関数定義の中を関数定義するために評価する。
  def eval_fbody(step)
    [self, step]
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [result, step]
  # シンボルをすべて排除すると環境がなくても評価することができる。
  # 関数定義の中では関数の引数を参照している場合があるため、
  # すべてのシンボルを排除することはできない
  def eval_symbol(stack, step)
    [self, step]
    # SymbolGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [result, step, 評価が完了しているかどうか]。
  def eval_quote(step, quote_depth)
    [self, step, true]
    # ConsGlispObject で再実装している
  end

  # 返り値は [result, step, 評価が完了しているかどうか]。
  # 関数定義の中に quote があった場合の関数定義の評価をする
  def eval_quote_fbody(step, quote_depth)
    [self, step, true]
    # ConsGlispObject で再実装している
  end

  # 返り値は [result, step]。
  def eval_quote_symbol(stack, step, quote_depth)
    [self, step]
    # ConsGlispObject で再実装している
  end

  # 返り値は [result, step]。
  def eval_fcall(step, args)
    [self, step]
    # ProcGlispObject, ConsGlispObject で再実装している
  end

  # 返り値は [result, step]。
  # 関数定義の中に関数呼び出しがあった場合の関数定義の評価をする。
  def eval_fcall_fbody(step, args)
    [self, step]
    # ProcGlispObject, ConsGlispObject で再実装している
  end

  # 以下はlistについてのメソッド

  def is_permanent_all
    return false if not car.is_permanent
    return cdr.is_permanent_all
    # NilGlispObject で再実装している
  end

  def eval_each(step)
    new_car, step = car.eval(step)
    return [gl_cons(new_car, cdr), step] if step == 0
    new_cdr, step = cdr.eval_each(step)
    return [gl_cons(new_car, new_cdr), step]
    # NilGlispObject で再実装している
  end

  def eval_symbol_each(stack, step)
    new_car, step = car.eval_symbol(stack, step)
    return [gl_cons(new_car, cdr), step] if step == 0
    new_cdr, step = cdr.eval_symbol_each(stack, step)
    return [gl_cons(new_car, new_cdr), step]
    # NilGlispObject で再実装している
  end

end # GlispObject

class SymbolGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? SymbolGlispObject and other.symbol == symbol
  end

  def to_rubyObj
    @val
  end

  def to_ss
    [@val.to_s]
  end

  def is_symbol
    true
  end

  def symbol
    @val
  end

  def symbol_or(default)
    @val
  end

  def is_permanent
    false
  end

  def encode
    gl_list2(:"eval-result", self)
  end

  # 返り値は [result, stack, step]。
  def eval_repl(stack, step)
    [gl_list2(:"eval-result", self), stack, step - 1]
  end

  # 返り値は [result, step]。
  def eval(step)
    [gl_list2(:"eval-result", self), step - 1]
  end

  # 返り値は [result, step]。
  def eval_fbody(step)
    [gl_list2(:"eval-result", self), step - 1]
  end

  # 返り値は [result, step]
  def eval_symbol(stack, step)
    index, value = stack.get_by_key(self)
    if index then
      if value.is_undefined then
        return [self, step]
      else
        return [value, step - 1]
      end
    end
    return [self, step]
  end

end # SymbolGlispObject

class IntegerGlispObject < GlispObject

  def initialize(val)
    @val = val
  end

  def ==(other)
    other.is_a? IntegerGlispObject and other.integer == integer
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

class ProcGlispObject < GlispObject

  def initialize(proc, can_calc_on_compile, name)
    @proc = proc
    @can_calc_on_compile = can_calc_on_compile
    @name = name
  end

  def ==(other)
    other.is_a? ProcGlispObject and other.to_rubyObj == to_rubyObj
  end

  def to_rubyObj
    @proc
  end

  def to_ss
    ['<' + @name + '>']
  end

  def eval_fcall(step, args)
    args, step = args.eval_each(step)
    return [gl_cons(self, args), step] if step == 0 or not args.is_permanent_all
    _eval_fcall_sub(step, args)
  end

  def eval_fcall_fbody(step, args)
    args, step = args.eval_fbody_each(step)
    return [gl_cons(self, args), step] if step == 0 or not args.is_permanent_all
    return [gl_cons(self, args), step] if not @can_calc_on_compile
    _eval_fcall_sub(step, args)
  end

  def _eval_fcall_sub(step, args)
    begin
      return [gl_create(@proc.call(* args.array)), step - 1]
    rescue => e
      return [gl_list(:throw,
                      '[%s] %s' % [e.class, e.message],
                      :Exception), step - 1]
    end
  end

end # ProcGlispObject

class NilGlispObject < GlispObject

  @@singleton = NilGlispObject.new

  def self.instance
    @@singleton
  end

  def ==(other)
    return false if other == nil
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

  def eval_each(step)
    return [self, step]
  end

  def eval_symbol_each(stack, step)
    return [self, step]
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
    return false if other == nil
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
    car_symbol_or(nil) == :"eval-result"
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

  def eval_repl(stack, step)

    sym = car_symbol_or(nil)

    if sym == :"def" then
      raise RuntimeError, "TODO"
    end

    result, step = eval_symbol(stack, step)
    return [result, stack, step] if step == 0

    result, step = result.eval(step)
    return [result, stack, step]

  end

  def eval(step)

    sym = car_symbol_or(nil)

    if sym == :"eval-result" then
      return [self, step]
    end

    if sym == :quote then
      result, step, = eval_quote(step, 0)
      return [result, step]
    end

    func, step = car.eval(step)
    args = cdr
    return [gl_cons(func, args), step] if step == 0
    if not func.is_permanent then
      return [gl_cons(func, args), step]
    end

    func = func.decode

    result, step = func.eval_fcall(step, args)
    return [result, step]

  end

  def eval_fbody(step)

    sym = car_symbol_or(nil)

    if sym == :"eval-result" then
      return [self, step]
    end

    if sym == :quote then
      result, step, = eval_quote_fbody(step, 0)
      return [result, step]
    end

    func, step = car.eval_fbody(step)
    args = cdr
    return [gl_cons(func, args), step] if step == 0
    if not func.is_permanent then
      args, step = args.eval_fbody_each(env, step)
      return [gl_cons(func, args), step]
    end

    func = func.decode

    result, step = func.eval_fcall_fbody(step, args)
    return [result, step]

  end

  def eval_symbol(stack, step)

    sym = car_symbol_or(nil)

    if sym == :"eval-result" then
      return [self, step]
    end

    if sym == :quote then
      return eval_quote_symbol(stack, step, 0)
    end

    return eval_symbol_each(stack, step)

  end

  def eval_quote(step, quote_depth)

    sym = car_symbol_or(nil)
    value = cdr_car_or(nil)

    if sym == :quote then
      # eval から呼び出された最初は必ずこの分岐に入る

      if value == nil then
        return [gl_nil, step - 1, true]
      end
      value, step, completed = value.eval_quote(step, quote_depth + 1)
      return [gl_list2(:quote, value), step, true] if quote_depth > 0 and completed
      return [gl_list2(:quote, value), step, false] if step == 0 or not completed
      return [gl_list2(:"eval-result", value), step - 1, true]

    elsif sym == :unquote then

      if value == nil then
        return [gl_nil, step - 1, true]
      end
      if quote_depth == 1 then
        value, step = value.eval(step)
        return [gl_list2(:unquote, value), step, false] if step == 0 or not value.is_permanent
        return [value.decode, step - 1, true]
      else
        value, step, completed = value.eval_quote(step, quote_depth - 1)
        return [gl_list2(:unquote, value), step, completed]
      end

    else

      new_car, step, completed1 = car.eval_quote(step, quote_depth)
      return [gl_cons(new_car, cdr), step, false] if step == 0
      new_cdr, step, completed2 = cdr.eval_quote(step, quote_depth)
      return [gl_cons(new_car, new_cdr), step, completed1 && completed2]

    end

  end

  def eval_quote_fbody(step, quote_depth)
    raise RuntimeError, "TODO"
  end

  def eval_quote_symbol(stack, step, quote_depth)

    sym = car_symbol_or(nil)
    value = cdr_car_or(nil)

    if sym == :quote then
      # eval_symbol から呼び出された最初は必ずこの分岐に入る

      if value == nil then
        return [gl_nil, step - 1]
      end
      value, step = value.eval_quote_symbol(stack, step, quote_depth + 1)
      return [gl_list2(:quote, value), step] if quote_depth > 0 or step == 0
      return [gl_list2(:"eval-result", value), step - 1]

    elsif sym == :unquote then

      if value == nil then
        return [gl_nil, step - 1]
      end
      if quote_depth == 1 then
        value, step = value.eval_symbol(stack, step)
        return [gl_list2(:unquote, value), step] if step == 0 or not value.is_permanent
        return [value.decode, step - 1]
      else
        value, step = value.eval_quote_symbol(stack, step, quote_depth - 1)
        return [gl_list2(:unquote, value), step]
      end

    else

      new_car, step = car.eval_quote_symbol(stack, step, quote_depth)
      return [gl_cons(new_car, cdr), step] if step == 0
      new_cdr, step = cdr.eval_quote_symbol(stack, step, quote_depth)
      return [gl_cons(new_car, new_cdr), step]

    end

  end

  def eval_fcall(step, args)
    if not is_permanent then
      raise RuntimeError
    end
    raise RuntimeError, "TODO"
  end

  def eval_fcall_fbody(step, args)
    if not is_permanent then
      raise RuntimeError
    end
    raise RuntimeError, "TODO"
  end


#  # 返り値は [結果, env, step]。
#  def _eval_sub(env, step, on_compile, is_def, is_repl, is_symbol)
#
#    sym = car_symbol_or(nil)
#
#    if sym == :"def" then
#      if is_symbol then
#        target = cdr.car
#        new_target, step = target.eval_symbol(env, step)
#        return [gl_list2(:def, new_target), env, step]
#      elsif is_def || is_repl then
#        raise RuntimeError, "TODO"
#      else
#        return [gl_list(:throw,
#                        'Unexpected `def\' expression',
#                        :Exception), step - 1]
#      end
#    end
#
#    if is_def then
#      raise RuntimeError, "TODO"
#      # return [gl_list(:throw,
#      #                 'Expected `def\' expression',
#      #                 :Exception), step - 1]
#    end
#
#    if sym == :"eval-result" then
#      return [self, env, step]
#    end
#
#    func, step = car.eval(env, step, on_compile)
#    args = cdr
#    return [gl_cons(func, args), env, step] if step == 0
#    if not func.is_permanent then
#      if on_compile then
#        args, step = args.eval_each(env, step, on_compile)
#      end
#      return [gl_cons(func, args), env, step]
#    end
#
#    result, step = func.eval_func_call(env, step, args, on_compile)
#    return [result, env, step]
#
#  end

end # ConsGlispObject

def createDefaultStack

  stack = gl_nil

#  stack = stack.push_pair(:true, true)
#  stack = stack.push_pair(:false, false)

  stack = push_basic_operator(stack, :+, true) do |*xs|
    xs.inject(0) {|a, b| a + b}
  end
  stack = push_basic_operator(stack, :-, true) do |x, y|
    x - y
  end

  return stack

end

def push_basic_operator(stack, symbol, can_calc_on_compile)
  f = proc do |*xs|
    args = xs.map {|x| x.to_rubyObj}
    ret = yield(*args)
    gl_create(ret)
  end
  stack.push_pair(symbol, ProcGlispObject.new(f, can_calc_on_compile, symbol.to_s))
end

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
  stack = createDefaultStack

#  do_test_sub(stack,
#              '"abc"',
#              [
#               '"abc"',
#              ])

  do_test_sub(stack,
              '1',
              [
               '1',
              ])

  do_test_sub(stack,
              '(+ 1 2)',
              [
               '( + 1 2 )',
               '( <+> 1 2 )',
               '3',
              ])

  do_test_sub(stack,
              '(quote (1 (unquote (+ 1 2))))',
              [
               '( quote ( 1 ( unquote ( + 1 2 ) ) ) )',
               '( quote ( 1 ( unquote ( <+> 1 2 ) ) ) )',
               '( quote ( 1 ( unquote 3 ) ) )',
               '( quote ( 1 3 ) )',
               '( eval-result ( 1 3 ) )',
              ])

end

def do_test_sub(stack, str, expected_patterns)
  io = StringIO.new(str)
  reader = Reader.new(io)
  expr = reader.read
  stack1 = test_eval_step(expr, stack, expected_patterns)
  stack2 = test_eval_whole(expr, stack, expected_patterns)
  if stack1 != stack2 then
    print "FAILED! stack mismatch\n"
  end
  print "\n"
  stack2
end

def pattern_to_regex(pattern)
  Regexp.new('^' + pattern.gsub(/\+/, '\\\\+').gsub(/\*/, '\\\\*').
             gsub(/\(/, '\(').gsub(/\)/, '\)') + '$')
end

def expr_to_string(expr)
  expr.to_s
end

def test_eval_step(expr, stack, expected_patterns)

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

    expr, stack, step = expr.eval_repl(stack, 1)

  end

  stack

end

def test_eval_whole(expr, stack, expected_patterns)

  expr, stack, step = expr.eval_repl(stack, -1)

  expr_s = expr_to_string(expr)
  pattern = expected_patterns[-1]
  pattern_regexp = pattern_to_regex(pattern)
  if not pattern_regexp =~ expr_s then
    print "(total)\nFAILED! Expected: %s\n             but: %s\n" % [pattern, expr_s]
    return stack
  end

  if step != (- expected_patterns.length) then
    print "(total)\nFAILED! step = %d\n" % [step]
    return stack
  end

  stack

end

if __FILE__ == $PROGRAM_NAME then
  do_test
end

