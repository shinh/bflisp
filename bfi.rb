#!/usr/bin/env ruby

require './bfopt'
require './common'

class BFInt
  def initialize(code, filename=nil)
    @filename = filename
    @code = code

    @mp = 0
    @mem = [0]
  end

  def check_bound
    if @mp < 0
      error(@loc, "memory pointer out of bound")
    end
  end

  def alloc_mem
    while @mp >= @mem.size
      @mem << 0
    end
  end

  def run
    loop_stack = []
    pc = 0
    while @code[pc]
      op, loc, args = @code[pc]
      @op = op
      @loc = loc

      case op
      when "+"
        @mem[@mp] += 1
        @mem[@mp] &= 255

      when "-"
        @mem[@mp] -= 1
        @mem[@mp] &= 255

      when ">"
        @mp += 1
        alloc_mem

      when "<"
        @mp -= 1
        check_bound

      when "["
        if @mem[@mp] == 0
          if args
            pc = args
          else
            d = 1
            while d > 0
              pc += 1
              case @code[pc][0]
              when "["
                d += 1
              when "]"
                d -= 1
              when nil
                error(@loc, "unmatched open paren")
              end
            end
          end
        else
          loop_stack << pc
        end

      when "]"
        if loop_stack.empty?
          error(@loc, "unmatched close paren")
        end
        pc = loop_stack.pop - 1

      when "."
        putc @mem[@mp]

      when ","
        c = STDIN.read(1)
        @mem[@mp] = c ? c.ord : 255

      when "@"
        if $verbose
          a = []
          [['PC', NPC], ['A', A], ['B', B], ['C', C], ['D', D],
           ['BP', BP], ['SP', SP]].each do |n, i|
            v = @mem[i] * 256 + @mem[i+1]
            if i == NPC
              v -= 1
            end
            a << "#{n}=#{v}"
          end
          a << "mp=#{@mp}"
          puts a * " "

          mem = (-12..12).map{|i|
            "#{i==0?"*":""}#{@mem[@mp+i]}"
          }
          puts mem * " "

          STDOUT.flush

          #wrks = (0..7).map{|i|@mem[WRK+i]}
          #puts "mp=#{@mp} WRK=#{wrks*' '}"

          #wrks = (0..7).map{|i|@mem[MEM+i]}
          #puts "mp=#{@mp} MEM=#{wrks*' '}"
        end

      when :clear
        @mem[@mp] = 0

      when :add_mem
        @mem[@mp] += args
        @mem[@mp] &= 255

      when :add_ptr
        @mp += args
        check_bound
        alloc_mem

      else
        error(@loc, "unknown op: #{op}")

      end

      pc += 1
    end

  end
end

if $0 == __FILE__
  filename = ARGV[0]
  bfopt = BFOpt.new(File.read(filename), filename)
  code = bfopt.optimize
  BFInt.new(code, filename).run
end
