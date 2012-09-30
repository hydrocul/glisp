#!/usr/bin/ruby
# -*- ruby-mode -*- -*- coding: utf-8 -*-

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
    cdr.is_permanent_all
    # NilGlispObject で再実装している
  end

end # GlispObject

class InterpreterEnv

  def initialize
    @primitives = gl_nil
    @globals = gl_nil
  end

  def push(key, value)
    InterpreterEnv.new(@primitives, gl_cons(gl_list2(key, value), @globals))
  end

end

if __FILE__ == $PROGRAM_NAME then
  puts "TEST"
end

