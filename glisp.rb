#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'


EVAL = :"*eval*"
EVAL_ERROR = :"*eval-error*"
EVAL_RESULT = :"*eval-result*"
UNDEFINED = :"*undefined*"
EOF = :"*EOF*"

LET = :"*let*"
FUNC = :"*func*"
MACRO = :"*macro*"

class ConsGl

  def initialize(car, cdr)
    @car = car
    @cdr = cdr
    if is_resolved then
      @resolved = self
    else
      @resolved = UNDEFINED
    end
  end

  def ==(other)
    return false if not other.is_a? ConsGl
    return false if @car != other.car
    return @cdr == other.cdr
  end

  def eq?(other)
    self == other
  end

  def to_s
    '(' + _to_s_internal([]).join(' ') + ')'
  end

  def _to_s_internal(arr)
    arr.push(gl_to_s(car))
    tail = cdr
    return arr if tail.nil?
    return tail._to_s_internal(arr) if tail.is_a? ConsGl
    arr.push('.')
    arr.push(gl_to_s(tail))
    return arr
  end

  def car
    @car
  end

  def cdr
    @cdr
  end

  def gets(count)
    _gets_sub([], count)
  end

  def _gets_sub(arr, count)
    if count == 0
      arr.push(self)
    else
      arr.push(gl_resolved(@car))
      d = gl_resolved(@cdr)
      if d.nil? && count == 1 then
        arr.push(nil)
        return arr
      end
      raise IndexError if not d.is_a? ConsGl
      d._gets_sub(arr, count - 1)
    end
    return arr
  end

  # キーと値のペアのリストを対象にキーから値を取得する。
  # インデックス, 値, リストのマッチして以降のリストを返す。
  # スタックを想定しており、
  # 遅延評価の解決はいっさいしない。
  # ただし、値に遅延評価が含まれているのは構わない。
  def get_by_key(key)
    if @car.is_a? ConsGl then
      k = @car.car
      if ! k.nil? && k == key then
        begin
          v = @car.cdr
          return [0, v, self]
        rescue IndexError
          # nothing
        end
      end
    end
    return [false, nil, nil] if not @cdr.is_a? ConsGl
    index, value, tail = @cdr.get_by_key(key)
    return [index + 1, value, tail] if index
    return [false, nil, nil]
  end

  def is_resolved
    @car != EVAL
  end

  def is_error
    @car == EVAL_ERROR
  end

  def resolved
    return @resolved if @resolved != UNDEFINED
    @resolved = _resolve
    raise Exception if ! gl_is_resolved(@resolved)
    return @resolved
  end

  def resolved_or_self
    return self if @resolved == UNDEFINED
    return @resolved
  end

  def _resolve
    raise Exception if @car != EVAL
    return nil if not @cdr.is_a? ConsGl
    return gl_eval(@cdr.resolved)
  end

  # 関数呼び出しの引数ために配列にする
  # count は必要な引数の数で、-1は無制限
  def _args_to_array(count, is_special)
    r = resolved
    return [[], true] if r.nil? && count <= 0
    raise IndexError if not r.is_a? ConsGl
    r._args_to_array_sub([], count, is_special)
  end

  def _args_to_array_sub(arr, count, is_special)
    return [arr, true] if count == 0
    is_success = true
    if is_special then
      arr.push(gl_resolved_or_self(car))
    else
      a = gl_eval(car)
      is_success = false if gl_is_error(car)
      arr.push(a)
    end
    tail = gl_resolved(cdr)
    return [arr, is_success] if tail.nil? && count <= 1
    raise IndexError if not tail.is_a? ConsGl
    arr, tail_is_success = tail._args_to_array_sub(arr, count - 1, is_special)
    return [arr, is_success && tail_is_success]
  end

end # ConsGl

class ProcGl

  def initialize(proc, name, args_count, is_special)
    @proc = proc
    @name = name
    @args_count = args_count
    @is_special = is_special
  end

  def ==(other)
    other.is_a? ProcGl and other.proc == proc
  end

  def eq?(other)
    self == other
  end

  def to_s
    '*' + @name + '*'
  end

  def proc
    @proc
  end

  def args_count
    @args_count
  end

  def is_special
    @is_special
  end

end # ProcGl

def gl_cons(car, cdr)
  ConsGl.new(car, cdr)
end

def gl_list(*x)
  if x.empty? then
    nil
  else
    gl_cons(x[0], gl_list(*x[1..-1]))
  end
end

def gl_list2(e1, e2)
  gl_cons(e1, gl_cons(e2, nil))
end

def gl_list0(*x)
  if x.size < 2 then
    raise Exception
  elsif x.size == 2 then
    gl_cons(x[0], x[1])
  else
    gl_cons(x[0], gl_list0(*x[1..-1]))
  end
end

def gl_to_s(expr)
  if expr.nil? then
    '()'
  elsif expr.is_a? String then
    '"' + expr.to_s + '"' # TODO
  else
    expr.to_s
  end
end

def gl_is_resolved(expr)
  return true if not expr.is_a? ConsGl
  return expr.is_resolved
end

def gl_is_error(expr)
  return false if not expr.is_a? ConsGl
  return expr.is_error
end

def gl_resolved(expr)
  return expr if not expr.is_a? ConsGl
  return expr.resolved
end

def gl_resolved_or_self(expr)
  return expr if not expr.is_a? ConsGl
  return expr.resolved_or_self
end

def gl_eval_root(expr, stack)
  if expr.is_a? ConsGl then
    car = gl_resolved(expr.car)
    if car == LET then
      _, pair, = expr.gets(2)
      if pair.is_a? ConsGl then
        sym = gl_resolved(pair.car)
        if sym.is_a? Symbol then
          value = gl_resolved(pair.cdr)
          value = _gl_eval_symbol(stack, value)
          stack = gl_cons(gl_cons(sym, value), stack)
          return [value, stack]
        end
      end
    end
  end
  expr = _gl_eval_symbol(stack, expr)
  result = gl_resolved(expr)
  return [result, stack]
end

def gl_eval(expr)
  return expr if not expr.is_a? ConsGl
  func = gl_resolved(expr.car)
  args = gl_resolved(expr.cdr)
  return gl_list0(EVAL_ERROR, func, args) if ! args.nil? && ! args.is_a?(ConsGl)
  if func == EVAL_RESULT then
    return args
  elsif func == FUNC then
    return expr
  elsif func.is_a? ProcGl then
    if args.nil? then
      proc_args = []
      is_success = true
    else
      begin
        proc_args, is_success = args._args_to_array(func.args_count, func.is_special)
      rescue IndexError => ex
        return gl_list0(EVAL_ERROR, func, args)
      end
    end
    if ! is_success then
      args = gl_list(* proc_args) if ! args.nil?
      return gl_list0(EVAL_ERROR, func, args)
    end
    begin
      return func.proc.call(* proc_args)
    rescue
      args = gl_list(* proc_args) if ! args.nil?
      return gl_list0(EVAL_ERROR, func, args)
    end
  elsif func.is_a? ConsGl then
    func_head = gl_resolved(func.car)
    if func_head == FUNC then
      func_body = gl_resolved(func.cdr)
      stack = gl_cons(gl_cons(:'_', args), nil)
      result = _gl_eval_symbol(stack, func_body)
      return gl_eval(result)
    else
      return func
    end
  else
    return func
  end
end

def _gl_eval_symbol(stack, expr)
  if expr.is_a? Symbol then

    result, = _gl_eval_symbol_symbol(stack, expr)
    return result

  elsif expr.is_a? ConsGl then

    car = gl_resolved(expr.car)
    cdr = gl_resolved(expr.cdr)

    if car == LET then

      sym, value, target = _gl_eval_parse_let(cdr)
      return expr if target == UNDEFINED
      return _gl_eval_symbol(stack, target) if sym.nil?
      value2 = value
      value2 = UNDEFINED if _gl_eval_symbol_exists_undefined(value)
      target_stack = gl_cons(gl_cons(sym, value2), stack)
      target_result = _gl_eval_symbol(target_stack, target)
      return target_result if value2 = UNDEFINED
      return gl_list0(LET, gl_cons(sym, value), target_result)

    elsif car == FUNC then

      target = cdr
      return expr if target == nil
      target_stack = gl_cons(gl_cons(:'_', UNDEFINED), stack)
      return gl_cons(FUNC, _gl_eval_symbol(target_stack, target))

    elsif car.is_a? Symbol then

      car, stack_tail = _gl_eval_symbol_symbol(stack, car)

      # マクロかどうかを調べて、マクロの場合は特別な処理
      if car.is_a? ConsGl then
        label = gl_resolved(car.car)
        if label == MACRO then
          macro_body = car.cdr
          macro_result = _gl_eval_symbol_eval_macro(macro_body, cdr)
          return _gl_eval_symbol(stack_tail, macro_result)
        end
      end

      # マクロでなかった場合
      cdr = _gl_eval_symbol(stack, cdr)
      return gl_cons(car, cdr)

    else

      car = _gl_eval_symbol(stack, car)
      cdr = _gl_eval_symbol(stack, cdr)
      return gl_cons(car, cdr)

    end

  else

    return expr

  end
end

def _gl_eval_symbol_symbol(stack, symbol)
  index, value, tail = stack.get_by_key(symbol)
  return [symbol, nil] if value == UNDEFINED
  return [symbol, nil] if ! index
  return [value, tail] if not value.is_a? ConsGl
  return [gl_cons(EVAL_RESULT, value), tail]
end

def _gl_eval_symbol_exists_undefined(expr)
  if expr.is_a? Symbol then
    return expr == UNDEFINED
  elsif expr.is_a? ConsGl then
    return true if _gl_eval_symbol_exists_undefined(expr.car)
    return _gl_eval_symbol_exists_undefined(expr.cdr)
  else
    return false
  end
end

def _gl_eval_symbol_eval_macro(macro_body, args)
  stack = gl_cons(:'_', args)
  macro_body = _gl_eval_symbol(stack, macro_body)
  return gl_eval(macro_body)
end

# [シンボル, 値, 式] を返す
def _gl_eval_parse_let(expr_cdr)
  return [nil, nil, UNDEFINED] if expr_cdr.nil?
  pair = gl_resolved(expr_cdr.car)
  target = gl_resolved(expr_cdr.cdr)
  if pair.is_a? Symbol then
    return [pair, UNDEFINED, target]
  end
  if not pair.is_a? ConsGl then
    return [nil, nil, target]
  end
  sym = gl_resolved(pair.car)
  return [nil, nil, target] if not sym.is_a? Symbol
  value = gl_resolved(pair.cdr)
  return [sym, value, target]
end

def build_initial_stack
  stack = _build_initial_stack_1
  _build_initial_script.each do |script|
    expr = gl_parse_source(script)
    result, stack = gl_eval_root(expr, stack)
  end
  return stack
end

def _build_initial_stack_1
  gl_list(
          gl_cons(:eval, EVAL),
          gl_cons(:let, LET),
          _build_basic_operator('+', -1, false) do |*xs|
            xs.inject(0) {|a, b| a + b}
          end,
          _build_basic_operator('-', 2, false) do |x, y|
            x - y
          end,
          _build_basic_operator('*', -1, false) do |*xs|
            xs.inject(1) {|a, b| a * b}
          end,
          _build_basic_operator('/', 2, false) do |x, y|
            x / y
          end,
          _build_basic_operator('car', 1, false) do |t|
            _builtin_car(t)
          end,
          _build_basic_operator('cdr', 1, false) do |t|
            _builtin_cdr(t)
          end,
          )
end

def _build_basic_operator(name, args_count, is_special)
  f = proc do |*xs|
    yield(*xs)
  end
  gl_cons(name.to_sym, ProcGl.new(f, name, args_count, is_special))
end

def _builtin_car(t)
  return gl_list(EVAL_ERROR, :'*car*', t) if not t.is_a? ConsGl
  return gl_resolved(t.car)
end

def _builtin_cdr(t)
  return gl_list(EVAL_ERROR, :'*cdr*', t) if not t.is_a? ConsGl
  return gl_resolved(t.cdr)
end

def _build_initial_script
  ['(*let* (func-one-arg . (macro . 1)))']
end

def gl_parse_source(input)
  io = StringIO.new(input)
  reader = Reader.new(io)
  reader.read
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
      return _read_list(true)
    when :')' then
      raise StandardError, 'unexpected: ' + t.to_s
    when :'`' then
      return gl_list2(:quote, _read_expr)
    when :',' then
      return gl_list2(:unquote, _read_expr)
    else
      return t
    end
  end

  def _read_list(is_start)
    t = _read_token
    case t
    when :')' then
      return nil
    when :'.' then
      raise StandardError, 'unexpected: \'.\'' if is_start
      tail = _read_expr
      t = _read_token
      raise StandardError, 'expected: \')\', but: ' + t.to_s if t != :')'
      return tail
    when EOF then
      raise StandardError, 'unexpected: ' + t.to_s
    else
      _read_back(t)
      head = _read_expr
      tail = _read_list(false)
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
    when 'true' then
      token = true
    when 'false' then
      token = false
    when /\A\".*\"\z/ then # TODO
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
  test_case = [
               ['3', '3'],
               ['3.14', '3.14'],
               ['"abc"', '"abc"'],
               ['abc', 'abc'],
               ['(1 2 3)', '(1 2 3)'],
               ['(1 2 . (3 4))', '(1 2 3 4)'],
               ['(eval + 1 2)', '3'],
               ['(eval +)', '0'],
               ['(eval + 1)', '1'],
               ['(eval - 10 (+ 1 2))', '7'],
               ['(1 eval + 2 3)', '(1 *eval* *+* 2 3)'],
               ['(1 . 2)', '(1 . 2)'],
               ['(eval cdr (*eval-result* 1 eval + 2 3))', '5'],
               ['(eval cdr (*eval-result* 1 . (eval + 2 3)))', '5'],
               ['(eval *eval-result* 1 2 (eval + 3 4))', '(1 2 (*eval* *+* 3 4))'],
               ['(eval / 1 0)', '(*eval-error* */* 1 0)'],
               ['', '*EOF*'],
               ['(eval *let* (a . 3) . (+ a 2))', '5'],
               ['(eval (*func* . (+ (car _) 1)) 3)', '4'],
               ['(eval *let* (a . 10) . (*func* . (+ (car _) a)))', '(*func* *+* (*car* _) 10)'],
               ['(eval *let* (a . 10) . ((*func* . (+ (car _) a)) 3))', '13'],
               ['(func-one-arg)', '*EOF*'],
              ]
  count = 0
  test_case.each do |c|
    if do_expr_test(c[0], c[1]) then
      count = count + 1
    end
  end
  print "Test complete! ( %d / %d )\n" % [count, test_case.length]
end

def do_expr_test(input, expected)
  expr = gl_parse_source(input)
  stack = build_initial_stack
  result, stack = gl_eval_root(expr, stack)
  result_s = gl_to_s(result)
  if result_s == expected then
    print "  OK    input: %s\n       output: %s\n" % [input, result_s]
    true
  else
    print "FAILED! input: %s\n       output: %s\n     expected: %s\n" % [input, result_s, expected]
    false
  end
end

if __FILE__ == $PROGRAM_NAME then
  do_test
end


