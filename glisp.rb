#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

require 'stringio'

################################
# 定数定義
################################

# 以下は、式からシンボルで直接参照できてはいけないので、
# 本当はシンボルではなく専用のオブジェクトとすべき

EVAL       = :"*eval*"
EVAL_ERROR = :"*eval-error*"
QUOTE      = :"*quote*"
UNDEFINED  = :"*undefined*"
EOF        = :"*EOF*"
LET   = :"*let*"
FUNC  = :"*func*"
MACRO = :"*macro*"

################################
# ConsGl
################################

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

################################
# ProcGl
################################

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

################################
# データ生成・変換のための関数群
################################

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

################################
# 評価のための関数群
################################

# [結果, 評価成功かどうか, スタック] を返す。
# エラーの場合は2つ目として false を返す。
# この関数では EVAL_ERROR をつけない。
# 3つ目の返り値は REPL のため。
def gl_eval(expr)

  expr = gl_resolved(expr)

  return [expr, true, nil] if not expr.is_a? ConsGl

  func = gl_resolved(expr.car)
  args = gl_resolved(expr.cdr)

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

  elsif func == FUNC then

    return [gl_cons(func, args), true, nil]

  elsif func.is_a? ProcGl then

    if args.nil? then
      proc_args = []
      is_success = true
    elsif not args.is_a? ConsGl then
      return [gl_cons(func, args), false, nil]
    else
      begin
        proc_args, is_success = _gl_args_to_array(args, func.args_count, false, func.is_force)
      rescue IndexError => ex
        return [gl_cons(func, args), false, nil]
      end
    end
    if not is_success then
      args = gl_list(* proc_args) if ! args.nil?
      return [gl_cons(func, args), false, nil]
    end
    begin
      return [func.proc.call(* proc_args), true, nil]
    rescue
      args = gl_list(* proc_args) if ! args.nil?
      return [gl_cons(func, args), false, nil]
    end

  elsif func.is_a? ConsGl then

    func_label = gl_resolved(func.car)
    if func_label == FUNC then

      # TODO

    else

      # TODO

    end

  else

    # TODO

  end

  return [gl_cons(func, args), false, nil]

end

def gl_eval_symbol_eval(stack, expr)

  if expr.is_a? Symbol then
    result = _gl_eval_symbol_eval_symbol(stack, expr)
    return result
  end

  return expr if not expr.is_a? ConsGl

  func = gl_eval_symbol_eval(stack, expr.car)
  args = expr.cdr

  if func == QUOTE then

    return gl_cons(QUOTE, args)

  elsif func == EVAL then

    # 式コンテキストの中でさらに EVAL があるのは、マクロ適用を回避させたい場合を想定

    args = gl_eval_symbol_eval(stack, args)
    return gl_cons(EVAL, args)

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

  elsif func == FUNC then

    target = args
    return gl_cons(FUNC, target) if target == nil
    target_stack = gl_cons(gl_cons(:'_', UNDEFINED), stack)
    target_result = gl_eval_symbol_eval(target_stack, target)
    return gl_cons(FUNC, target_result)

  elsif func.is_a? ProcGl then

    args = _gl_eval_symbol_args(stack, args)
    return gl_cons(func, args)

  elsif func.is_a? ConsGl then

    func_label = gl_resolved(func.car)
    if func_label == FUNC then

      # TODO

    else

      # TODO

    end

  else

    # TODO

  end

  return expr # TODO

end

def gl_eval_symbol_value(stack, expr)

  expr = gl_resolved(expr)

  if expr.is_a? Symbol then
    result = _gl_eval_symbol_value_symbol(stack, expr)
    return result
  end

  return expr if not expr.is_a? ConsGl

  func = gl_eval_symbol_value(stack, expr.car)
  args = expr.cdr

  return gl_cons(func, args) if ! args.nil? && ! args.is_a?(ConsGl)

  if func == EVAL then

    return gl_cons(EVAL, gl_eval_symbol_eval(stack, args))

  elsif func == EVAL_ERROR then

    return gl_cons(EVAL_ERROR, args)

  else

    return gl_cons(func, nil) if args.nil?
    args = gl_eval_symbol_value(stack, args)
    return gl_cons(func, args)

  end

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

def _gl_eval_symbol_args(stack, args)
  return nil if args.nil?
  args = gl_resolved(args)
  return gl_eval_symbol_eval(stack, args) if not args.is_a? ConsGl
  car = gl_eval_symbol_eval(stack, args.car)
  cdr = _gl_eval_symbol_args(stack, args.cdr)
  return gl_cons(car, cdr)
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

# 関数呼び出しの引数ために配列にする
# count は必要な引数の数で、-1は無制限
# args は解決済みの ConsGl か nil である前提
def _gl_args_to_array(args, count, is_macro, is_force)
  return [[], true] if args.nil? && count <= 0
  raise IndexError if not args.is_a? ConsGl
  _gl_args_to_array_sub(args, [], count, is_macro, is_force)
end

# args は解決済みの ConsGl である前提
def _gl_args_to_array_sub(args, arr, count, is_macro, is_force)
  return [arr, true] if count == 0
  is_success = true
  if is_macro then
    arr.push(args.car)
  elsif is_force then
    a, success_flag = gl_eval(gl_resolved(args.car))
    if not success_flag then
      a = gl_wrap_eval_error(a)
      is_success = false
    end
    arr.push(a)
  else
    arr.push(gl_wrap_eval(args.car))
  end
  tail = gl_resolved(args.cdr)
  return [arr, is_success] if tail.nil? && count <= 1
  raise IndexError if not tail.is_a? ConsGl
  arr, tail_is_success = _gl_args_to_array_sub(tail, arr, count - 1, is_macro, is_force)
  return [arr, is_success && tail_is_success]
end

################################
# 初期スタックの定義
################################

# 初期のスタックを生成する
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
          _gl_build_basic_operator('list', -1, true) do |*xs|
            _gl_builtin_list(xs)
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

################################
# 初期スタックで定義される関数の実装
################################

def _gl_builtin_car(t)
  return gl_list(EVAL_ERROR, :'*car*', t) if not t.is_a? ConsGl
  return gl_resolved(t.car)
end

def _gl_builtin_cdr(t)
  return gl_list(EVAL_ERROR, :'*cdr*', t) if not t.is_a? ConsGl
  return gl_resolved(t.cdr)
end

def _gl_builtin_list(xs)
  return gl_list(* xs)
end

# 初期のスタックを生成するために最初に実行するスクリプト
def _gl_build_initial_script
  ''
end

################################
# 文字列を式に変換するパーサ
################################

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

################################
# テスト
################################

def do_test
  test_case = [
               ['3', '3'],
               ['3   3.14 "abc" \'DEF\'', '3 3.14 "abc" \'DEF\''],
               ['', ''],
               ['(*quote* 1 2 3)', '(1 2 3)'],
               ['(*eval* + 1 2)', '3'],
               ['(*eval* list + 1 2)', '3'],
               ['(*eval* list list + 1 2)', '(*+* 1 2)'],
               ['(*let* (a . 1) . a)', '1'],
               ['(*let* (a . (*quote* 1 2 3)). a)', '(1 2 3)'],
               ['(*let* a . a)', 'a'],
               ['(*let* a)', '()'],
               ['(*let* 1 . a)', '(*eval-error* *let* 1 . a)'],
               ['(*let* . a)', '(*eval-error* *let* . a)'],
               ['(+ 1 2)', '3'],
               ['(+ 1)', '1'],
               ['(+ . 1)', '(*eval-error* *+* . 1)'],
               ['(*let* (a . 1) + a 2)', '3'],
               ['(*func* *quote* _ 2 3)', '(*func* *quote* _ 2 3)'],
               ['(*let* (a . 2) *func* *quote* _ a 3)', '(*func* *quote* _ a 3)'],
               ['(*let* (a . 2) *func* list _ a 3)', '(*func* *list* _ 2 3)'],
               ['((*func* *quote* _ 2 3) . 1)', '(1 2 3)'],
               ['((*func* *quote* _ 2 3) 1)', '((1) 2 3)'],
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

################################


