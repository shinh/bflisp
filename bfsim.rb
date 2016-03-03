#!/usr/bin/env ruby

require './common'

class BFSim
  def initialize
    @a = 0
    @b = 0
    @c = 0
    @d = 0
    @pc = 0
    @bp = 0
    @sp = 0
    @cond = false
    @mem = [0] * 65536
  end

  def set(r, v)
    case r
    when :a
      @a = v
    when :b
      @b = v
    when :c
      @c = v
    when :d
      @d = v
    when :bp
      @bp = v
    when :sp
      @sp = v
    when :pc
      @pc = v
    else
      raise "invalid dest reg #{r}"
    end
  end

  def src(o)
    case o
    when :a
      @a
    when :b
      @b
    when :c
      @c
    when :d
      @d
    when :bp
      @bp
    when :sp
      @sp
    when :pc
      @pc
    else
      o
    end
  end

  def run(code, data)
    if !$quiet
      STDERR.puts "code size: #{code.size}"
      STDERR.puts "data size: #{data.size}"
    end

    if code.size >= 65536
      STDERR.puts "too much code size: #{code.size}"
    end

    data.each do |d, i|
      @mem[i] = d
    end

    running = true
    while running
      npc = nil
      code[@pc].each do |op, *args, lineno|
        hp = @mem[256]
        if @sp != 0 && @sp <= hp
          STDERR.puts "stack overflow!!! #{@sp} vs #{hp}"
        end

        if $verbose
          STDERR.puts "PC=#@pc A=#@a B=#@b C=#@c D=#@d BP=#@bp SP=#@sp"
          STDERR.print "STK:"
          32.times{|i|
            STDERR.print " #{@mem[-32+i]}"
          }
          STDERR.puts
          STDERR.puts "#{op} #{args} at #{lineno}"
        end

        if !op
          raise "out of bound pc=#{@pc}"
        end
        npc = @pc + 1

        case op
        when :mov
          set(args[0], src(args[1]))

        when :add
          set(args[0], (src(args[0]) + src(args[1])) & 65535)

        when :sub
          set(args[0], (src(args[0]) - src(args[1])) & 65535)

        when :load
          s = src(args[1])
          v = @mem[s]
          if s < 256
            STDERR.puts "zero-page load: addr=#{s} (#{v}) @#{lineno}"
          end
          set(args[0], @mem[src(args[1])])

        when :store
          v = src(args[0])
          d = src(args[1])
          if d < 256
            STDERR.puts "zero-page store: addr=#{d} (#{v}) @#{lineno}"
          end
          @mem[d] = v

        when :jmp, :jeq, :jne, :jlt, :jgt, :jle, :jge
          ok = true
          case op
          when :jeq
            ok = src(args[1]) == src(args[2])
          when :jne
            ok = src(args[1]) != src(args[2])
          when :jlt
            ok = src(args[1]) < src(args[2])
          when :jgt
            ok = src(args[1]) > src(args[2])
          when :jle
            ok = src(args[1]) <= src(args[2])
          when :jge
            ok = src(args[1]) >= src(args[2])
          end
          if ok
            npc = src(args[0])
          end

        when :eq
          set(args[0], src(args[0]) == src(args[1]) ? 1 : 0)
        when :ne
          set(args[0], src(args[0]) != src(args[1]) ? 1 : 0)
        when :lt
          set(args[0], src(args[0]) < src(args[1]) ? 1 : 0)
        when :gt
          set(args[0], src(args[0]) > src(args[1]) ? 1 : 0)
        when :le
          set(args[0], src(args[0]) <= src(args[1]) ? 1 : 0)
        when :ge
          set(args[0], src(args[0]) >= src(args[1]) ? 1 : 0)

        when :putc
          putc src(args[0])

        when :getc
          c = STDIN.read(1)
          set(args[0], c ? c.ord : 0)

        when :exit
          running = false
          break
        end
      end

      @pc = npc
    end

    if !$quiet
      STDERR.puts "last heap: #{@mem[256]}"
    end

  end
end

if $0 == __FILE__
  require './bfasm'

  asm = BFAsm.new
  code, data = asm.parse(File.read(ARGV[0]))

  sim = BFSim.new
  sim.run(code, data)
end
