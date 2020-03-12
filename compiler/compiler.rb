#!/usr/bin/env ruby

class Tokenizer
  TOKEN_TYPES = [
    [:def, /\bdef\b/],
    [:end, /\bend\b/],
    [:identifier, /\b[a-zA-Z]+\b/],
    [:integer, /\b[0-9]+\b/],
    [:oparen, /\(/],
    [:cparen, /\)/],
    [:comma, /,/]
  ].freeze

  def initialize(code)
    @code = code
  end

  def tokenize
    tokens = []
    until @code.empty?
      tokens << tokenize_one_token
      @code.strip!
    end

    tokens
  end

  def tokenize_one_token
    TOKEN_TYPES.each do |type, re|
      re = /\A(#{re})/
      if @code =~ re
        value = $1
        @code = @code[value.length..-1]
        return Token.new(type, value)
      end
    end

    raise "Couldn't match token on #{@code.inspect}"
  end
end

Token = Struct.new(:type, :value)

class Parser
  def initialize(tokens)
    @tokens = tokens
  end

  def parse
    parse_def
  end

  def parse_def
    consume(:def)
    name = consume(:identifier).value
    args_names = parse_arg_names
    body = parse_expr
    consume(:end)
    DefNode.new(name, args_names, body)
  end

  def parse_arg_names
    args_names = []

    consume(:oparen)
    if peek(:identifier)
      args_names << consume(:identifier).value
      while peek(:comma)
        consume(:comma)
        args_names << consume(:identifier).value
      end
    end
    consume(:cparen)
    args_names
  end

  def parse_expr
    if peek(:integer)
      parse_integer
    elsif peek(:identifier) && peek(:oparen, 1)
      parse_call
    else
      parse_ver_ref
    end
  end

  def parse_integer
    IntegerNode.new(consume(:integer).value.to_i)
  end

  def parse_call
    name = consume(:identifier).value
    arg_exprs = parse_arg_exprs
    CallNode.new(name, arg_exprs)
  end

  def parse_ver_ref
    VarRefNode.new(consume(:identifier).value)
  end

  def parse_arg_exprs
    arg_exprs = []

    consume(:oparen)
    if !peek(:cparen)
      arg_exprs << parse_expr
      while peek(:comma)
        consume(:comma)
        arg_exprs << parse_expr
      end
    end
    consume(:cparen)
    arg_exprs
  end

  def consume(expected_type)
    token = @tokens.shift
    if token.type == expected_type
      token
    else
      raise "Expected type #{expected_type.inspect} but got #{token.type.inspect}"
    end
  end

  def peek(expected_type, offset = 0)
    @tokens.fetch(offset).type == expected_type
  end
end

DefNode = Struct.new(:name, :args_names, :body)
IntegerNode = Struct.new(:value)
CallNode = Struct.new(:name, :arg_exprs)
VarRefNode = Struct.new(:value)

class Generator
  def generate(node)
    case node
    when DefNode
      "function %s(%s) { return %s };" % [
        node.name,
        node.args_names.join(','),
        generate(node.body)
      ]
    when CallNode
      "%s(%s)" % [
        node.name,
        node.arg_exprs.map(&method(:generate)).join(',')
      ]
    when VarRefNode
      node.value
    when IntegerNode
      node.value
    else
      raise "Unexpected node type: #{node.class}"
    end
  end
end

tokens = Tokenizer.new(File.read("compiler/test.src")).tokenize
tree = Parser.new(tokens).parse
RUNTIME = "function add(x,y) { return x + y };"
TEST = "console.log(f(1, 2));"
generated = Generator.new.generate(tree)
puts [RUNTIME, generated, TEST].join("\n")
