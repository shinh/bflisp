#!/usr/bin/env ruby

class BFOpt
  def initialize(code, filename=nil)
    @filename = filename

    @code = []
    lineno = 1
    column = 0
    code.each_char{|b|
      case b
      when '+', '-', '>', '<', '[', ']', '.', ',', '@'
        @code << [b, [@filename, lineno, column, 1]]
      when "\n"
        lineno += 1
        column = -1
      end
      column += 1
    }

    match_loops
  end

  def match_loops
    loop_stack = []
    @code.each_with_index do |c, pc|
      op, loc, *_ = *c
      if op == '['
        loop_stack << pc
      elsif op == ']'
        if loop_stack.empty?
          error(loc, "unmatched close paren")
        end

        ppc = loop_stack.pop
        c[2] = ppc
        @code[ppc][2] = pc
      end
    end
    if !loop_stack.empty?
      error(@code[loop_stack.pop][1], "unmatched open paren")
    end
  end

  def code
    @code
  end

  def substr(st, ed)
    code = @code[st...ed].map do |op, loc, *_|
      if sym?(op)
        error(loc, "cannot stringify internal operations: #{op}")
      end
      op
    end * ''
    loc = @code[st][1]
    eloc = @code[ed-1][1]
    loc[3] = eloc[2] + eloc[3] - loc[2]
    [code, loc]
  end

  def optimize
    optimize_loops
    optimize_repetitions
    match_loops
    @code
  end

  def optimize_loops
    optimized = []
    i = 0
    while @code[i]
      c = @code[i]
      if c[0] != '['
        optimized << c
        i += 1
        next
      end

      loop_code, loc = substr(i, c[2]+1)
      if loop_code == '[-]'
        optimized << [:clear, loc]
        i += loop_code.size
        next
      end

      optimized << c
      i += 1
    end

    @code = optimized
  end

  def optimize_repetitions
    optimized = []
    i = 0
    while @code[i]
      c = @code[i]
      op, loc, args = c

      done = false
      [['+', '-', :add_mem],
       ['>', '<', :add_ptr]].each do |plus, minus, opt_op|
        if op == plus || op == minus
          j = i
          while @code[j] && (@code[j][0] == plus || @code[j][0] == minus)
            j += 1
          end
          code, loc = substr(i, j)
          d = code.count(plus) - code.count(minus)
          if d != 0
            optimized << [opt_op, loc, d]
          end
          i += code.size
          done = true
        end
      end

      if !done
        optimized << c
        i += 1
      end
    end

    @code = optimized
  end

end
