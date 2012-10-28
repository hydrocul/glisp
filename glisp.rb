#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

EVAL       = :"*eval*"
EVAL_ERROR = :"*eval-error*"
QUOTE      = :"*quote*"
UNDEFINED  = :"*undefined*"
EOF        = :"*EOF*"

LET   = :"*let*"
FUNC  = :"*func*"
MACRO = :"*macro*"

class ConsGl

  def initialize(car, cdr)
    @car = car
    @cdr = cdr
    if is_resolved or is_error then
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
      if ! d.is_a?(ConsGl) && count == 1 then
        arr.push(d)
        return arr
      end
      raise IndexError if not d.is_a? ConsGl
      d._gets_sub(arr, count - 1)
    end
    return arr
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
    raise Exception if ! gl_is_resolved(@resolved) &&  ! gl_is_error(@resolved)
    return @resolved
  end

  def resolved_or_self
    return self if @resolved == UNDEFINED
    return @resolved
  end

  def _resolve
    return self if @car != EVAL
    return gl_eval_to_value(@cdr)
  end

end # ConsGl

class ProcGl

  def initialize(proc, name, args_count, is_force)
    @proc = proc
    @name = name
    @args_count = args_count
    @is_force = is_force
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

  def is_force
    @is_force
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

def gl_wrap_eval(expr)
  return expr if not expr.is_a? ConsGl
  return gl_cons(EVAL, expr)
end

def gl_wrap_eval_error(expr)
  return expr if not expr.is_a? ConsGl
  return gl_cons(EVAL_ERROR, expr)
end

def gl_wrap_quote(expr)
  return expr if not expr.is_a? ConsGl
  return gl_cons(QUOTE, expr)
end

def gl_eval_to_value(expr)
  result, success_flag = gl_eval(expr)
  return result if success_flag
  return gl_wrap_eval_error(result)
end

def gl_eval_root(expr, stack)
  expr = gl_eval_symbol_eval(stack, expr)
  result, success_flag, stack2 = gl_eval(expr)
  return [gl_wrap_eval_error(result), stack] if not success_flag
  stack = _gl_push_stack(stack, stack2)
  return [result, stack]
end

def _gl_push_stack(stack, stack_head)
  return stack if stack_head.nil?
  stack = _gl_push_stack(stack, stack_head.cdr)
  return gl_cons(stack_head, stack)
end

# [結果, 評価成功かどうか, スタック] を返す。
# エラーの場合は2つ目として false を返す。
# この関数では EVAL_ERROR をつけない。
# 3つ目の返り値は REPL のため。
def gl_eval(expr)

  return [expr, true, nil] if not expr.is_a? ConsGl

  func = gl_resolved(expr.car)
  args = gl_resolved(expr.cdr)

  return [gl_cons(func, args), false, nil] if ! args.nil? && ! args.is_a?(ConsGl)

  if func == QUOTE then

    return [args, true, nil]

  elsif func == EVAL_ERROR then

    return [args, false, nil]

  elsif func == LET then

    sym, value, target = _gl_eval_parse_let(args)
    return [gl_cons(LET, args), false] if target == UNDEFINED
    return [gl_cons(LET, args), false] if sym.nil?
    value2 = gl_wrap_eval(value)
    target_stack = gl_cons(gl_cons(sym, value2), nil)
    target_result = gl_eval_symbol_eval(target_stack, target)
    target_result, success_flag = gl_eval(target_result)
    return [target_result, success_flag]

  end

  return [gl_cons(func, args), false, nil]

end

def gl_eval_symbol_eval(stack, expr)

  if expr.is_a? Symbol then
    result = _gl_eval_symbol_eval_symbol(stack, expr)
    return result
  end

  return expr if not expr.is_a? ConsGl

  func = expr.car
  args = expr.cdr

  return gl_cons(func, args) if ! args.nil? && ! args.is_a?(ConsGl)

  if func == QUOTE then

    return gl_cons(QUOTE, gl_eval_symbol_value(stack, args))

  elsif func == EVAL_ERROR then

    return gl_cons(EVAL_ERROR, args)

  elsif func == LET then

    sym, value, target = _gl_eval_parse_let(args)
    return gl_cons(LET, args) if target == UNDEFINED
    return gl_cons(LET, args) if sym.nil?
    value2 = gl_wrap_eval(value)
    value2 = UNDEFINED if _gl_eval_symbol_exists_undefined(value)
    target_stack = gl_cons(gl_cons(sym, value2), stack)
    target_result = gl_eval_symbol_eval(target_stack, target)
    return target_result if value2 != UNDEFINED
    return gl_list0(LET, gl_cons(sym, value), target_result)

  end

  return expr # TODO

end

def gl_eval_symbol_value(stack, expr)

  if expr.is_a? Symbol then
    result = _gl_eval_symbol_value_symbol(stack, expr)
    return result
  end

  return expr if not expr.is_a? ConsGl

  func = expr.car
  args = expr.cdr

  return gl_cons(func, args) if ! args.nil? && ! args.is_a?(ConsGl)

  if func == EVAL then

    return gl_cons(EVAL, gl_eval_symbol_eval(stack, args))

  end


  return expr # TODO

end

def _gl_eval_symbol_eval_symbol(stack, symbol)
  index, value = _gl_get_by_key_from_stack(stack, symbol)
  return symbol if value == UNDEFINED
  return symbol if ! index
  return value if not value.is_a? ConsGl
  return value.cdr if value.car == EVAL
  return gl_wrap_quote(value)
end

def _gl_eval_symbol_value_symbol(stack, symbol)
  index, value = _gl_get_by_key_from_stack(stack, symbol)
  return symbol if value == UNDEFINED
  return symbol if ! index
  return value
end

# [シンボル, 値, 式] を返す
def _gl_eval_parse_let(expr_cdr)
  return [nil, nil, UNDEFINED] if expr_cdr.nil?
  return [nil, nil, UNDEFINED] if not expr_cdr.is_a? ConsGl
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

def _gl_eval_symbol_exists_undefined(expr)
  if expr.is_a? Symbol then
    return expr == UNDEFINED
  elsif not expr.is_a? ConsGl then
    return false
  end
  return true if _gl_eval_symbol_exists_undefined(expr.car)
  return _gl_eval_symbol_exists_undefined(expr.cdr)
end

# キーと値のペアのリストを対象にキーから値を取得する。
# インデックス, 値を返す。
# スタックを想定しており、
# 遅延評価の解決はいっさいしない。
# ただし、値に遅延評価が含まれているのは構わない。
def _gl_get_by_key_from_stack(stack, key)
  if stack.car.is_a? ConsGl then
    k = stack.car.car
    if ! k.nil? && k == key then
      begin
        v = gl_resolved_or_self(stack.car.cdr)
        return [0, v]
      rescue IndexError
        # nothing
      end
    end
  end
  return [false, nil] if not stack.cdr.is_a? ConsGl
  index, value = _gl_get_by_key_from_stack(stack.cdr, key)
  return [index + 1, value] if index
  return [false, nil]
end

def gl_build_initial_stack
  stack = _gl_build_initial_stack_1
  exprs = gl_parse_source(_gl_build_initial_script)
  exprs.each do |expr|
    result, stack = gl_eval_root(expr, stack)
  end
  return stack
end

def _gl_build_initial_stack_1
  gl_list(
          _gl_build_basic_operator('+', -1, true) do |*xs|
            xs.inject(0) {|a, b| a + b}
          end,
          _gl_build_basic_operator('-', 2, true) do |x, y|
            x - y
          end,
          _gl_build_basic_operator('*', -1, true) do |*xs|
            xs.inject(1) {|a, b| a * b}
          end,
          _gl_build_basic_operator('/', 2, true) do |x, y|
            x / y
          end,
          _gl_build_basic_operator('car', 1, true) do |t|
            _gl_builtin_car(t)
          end,
          _gl_build_basic_operator('cdr', 1, true) do |t|
            _gl_builtin_cdr(t)
          end,
          )
end

def _gl_build_basic_operator(name, args_count, is_force)
  f = proc do |*xs|
    yield(*xs)
  end
  gl_cons(name.to_sym, ProcGl.new(f, name, args_count, is_force))
end

def _gl_builtin_car(t)
  return gl_list(EVAL_ERROR, :'*car*', t) if not t.is_a? ConsGl
  return gl_resolved(t.car)
end

def _gl_builtin_cdr(t)
  return gl_list(EVAL_ERROR, :'*cdr*', t) if not t.is_a? ConsGl
  return gl_resolved(t.cdr)
end

def _gl_build_initial_script
  ''
end

# input に含まれるS式をすべて読み込んで配列で返す
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
    ret = []
    while true do
      r = _read_expr
      if r == EOF then
        break
      end
      ret.push(r)
    end
    return ret
  end

  def _read_expr
    t = _read_token
    case t
    when :'(' then
      return _read_list(true)
    when :')' then
      raise StandardError, 'unexpected: ' + t.to_s
    when :'\'' then
      return gl_cons(:quote, _read_expr)
    when :'`' then
      return gl_cons(:quasiquote, _read_expr)
    when :',' then
      return gl_cons(:unquote, _read_expr)
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
    when '(', ')', '\'', '`', ',', '.' then
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
               ['3   3.14 "abc" \'DEF\'', '3 3.14 "abc" \'DEF\''],
               ['', ''],
               ['(*quote* 1 2 3)', '(1 2 3)'],
               ['(*eval* + 1 2)', '(*eval-error* *eval* + 1 2)'],
               ['(*let* (a . 1) . a)', '1'],
               ['(*let* (a . (*quote* 1 2 3)). a)', '(1 2 3)'],
               ['(*let* a . a)', 'a'],
               ['(*let* a)', '()'],
               ['(*let* 1 . a)', '(*eval-error* *let* 1 . a)'],
               ['(*let* . a)', '(*eval-error* *let* . a)'],
#               ['(1 2 . (3 4))', '(1 2 3 4)'],
#               ['(eval + 1 2)', '3'],
#               ['(eval +)', '0'],
#               ['(eval + 1)', '1'],
#               ['(eval - 10 (+ 1 2))', '7'],
#               ['(1 eval + 2 3)', '(1 *eval* *+* 2 3)'],
#               ['(1 . 2)', '(1 . 2)'],
#               ['(eval cdr (*eval-result* 1 eval + 2 3))', '5'],
#               ['(eval cdr (*eval-result* 1 . (eval + 2 3)))', '5'],
#               ['(eval *eval-result* 1 2 (eval + 3 4))', '(1 2 (*eval* *+* 3 4))'],
#               ['(eval / 1 0)', '(*eval-error* */* 1 0)'],
#               ['(eval *let* (a . 3) . (+ a 2))', '5'],
#               ['(eval (*func* . (+ (car _) 1)) 3)', '4'],
#               ['(eval *let* (a . 10) . (*func* . (+ (car _) a)))', '(*func* *+* (*car* _) 10)'],
#               ['(eval *let* (a . 10) . ((*func* . (+ (car _) a)) 3))', '13'],
#               ['(func-one-arg)', '*EOF*'],
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
  result_s = ''
  expr.each do |expr|
    stack = gl_build_initial_stack
    result, stack = gl_eval_root(expr, stack)
    if result_s.length > 0 then
      result_s = result_s + ' '
    end
    result_s = result_s + gl_to_s(result)
  end
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


