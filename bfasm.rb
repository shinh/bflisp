#!/usr/bin/env ruby

require './common'

# 16bit CPU.
# Registers: A, B, C, D, BP, and SP
#
# mov   <reg>, <reg|simm|label>
# add   <reg>, <reg|simm>
# sub   <reg>, <reg|simm>
# load  <reg>, <reg|simm>
# store <reg>, <reg|simm>
# eq    <reg>, <reg|simm>
# ne    <reg>, <reg|simm>
# lt    <reg>, <reg|simm>
# gt    <reg>, <reg|simm>
# le    <reg>, <reg|simm>
# ge    <reg>, <reg|simm>
# jmp   <reg|label>
# jeq   <reg|label>, <reg>, <reg|simm>
# jne   <reg|label>, <reg>, <reg|simm>
# jlt   <reg|label>, <reg>, <reg|simm>
# jgt   <reg|label>, <reg>, <reg|simm>
# jle   <reg|label>, <reg>, <reg|simm>
# jge   <reg|label>, <reg>, <reg|simm>
# putc  <reg|simm>
# getc  <reg>
# exit

class BFAsm
  def initialize
    @jmp_ops = {
      :jmp => 1,
      :jeq => 3,
      :jne => 3,
      :jlt => 3,
      :jgt => 3,
      :jle => 3,
      :jge => 3,
    }

    @ops = {
      :mov => 2,
      :add => 2,
      :sub => 2,
      :load => 2,
      :store => 2,
      :eq => 2,
      :ne => 2,
      :lt => 2,
      :gt => 2,
      :le => 2,
      :ge => 2,
      :putc => 1,
      :getc => 1,
      :exit => 0,
      :dump => 0,
    }
    @jmp_ops.each do |k, v|
      @ops[k] = v
    end

    @code = []
    @data = []
    @labels = {}

    @code << [:jmp, 'main', -1]
    @labels['main'] = 1

    @labels['_edata'] = cur_data_addr
    add_data(0)
  end

  def regpos(r)
    case r
    when :a
      A
    when :b
      B
    when :c
      C
    when :d
      D
    when :pc
      PC
    when :bp
      BP
    when :sp
      SP
    else
      raise "unknown reg: #{r}"
    end
  end

  def cur_data_addr
    @data.size + 256
  end

  def add_data(v)
    @data << [v, cur_data_addr]
  end

  def parse(code)
    in_data = false
    code.split("\n").each_with_index do |line, lineno|
      lineno += 1

      # TODO: Weird!
      line.sub!(/(^#| # ).*/, '')
      line.strip!
      next if line.empty?

      if line =~ /^\.(text|data)/
        in_data = $1 == 'data'
        next
      end

      if line =~ /^(\.?\w+):$/
        @labels[$1] = in_data ? cur_data_addr : @code.size
        next
      end

      if in_data
        if line =~ /^\.long (-?\d+)/
          add_data($1.to_i & 65535)
        elsif line =~ /^\.long (\.?\w+)/
          if !@labels[$1]
            raise 'TODO'
          end
          add_data(@labels[$1])
        elsif line =~ /^\.lcomm (\w+), (\d+)/
          name = $1
          size = $2.to_i
          @labels[name] = cur_data_addr
          size.times{
            add_data(0)
          }
        elsif line =~ /^\.string (".*")/
          str = eval($1)
          str.each_byte{|b|
            add_data(b)
          }
          add_data(0)
        else
          raise "unknown data at line #{lineno}"
        end
        next
      end

      op = line[/^\S+/].to_sym
      args = $'.split(',')
      if !@ops[op]
        raise "invalid op (#{op}) at line #{lineno}"
      end

      if @ops[op] != args.size
        raise "invalid number of args for #{op} at line #{lineno}"
      end

      args = args.each_with_index.map{|a, i|
        a.strip!
        if a =~ /^-?0x(\d+)$/
          a.hex
        elsif a =~ /^-?\d+$/
          a.to_i
        elsif a =~ /^(a|b|c|d|pc|bp|sp)$/i
          $1.downcase.to_sym
        elsif a =~ /^\.?\w+$/ && ((@jmp_ops[op] && i == 0) ||
                                  (op == :mov && i == 1))
          a
        else
          raise "invalid use of #{op} at line #{lineno}"
        end
      }

      if args.size == 2
        if !sym?(args[0])
          raise "invalid first arg for #{op} at line #{lineno}"
        end
      end

      if op == :getc && !sym?(args[0])
        raise "invalid arg for #{op} at line #{lineno}"
      end

      @code << [op, *args, lineno]
    end

    @data[0][0] = cur_data_addr

    @code = @code.each_with_index.map{|opa, i|
      op, *args, lineno = *opa
      args = args.each_with_index.map do |a, j|
        if a.class == String
          if (@jmp_ops[op] && j == 0) || (op == :mov && j == 1)
            if !@labels[a]
              raise "undefined label #{a} at line #{lineno}"
            end
            @labels[a]
          else
            raise "unexpected label (#{a}) in #{op}"
          end
        elsif sym?(a)
          a
        else
          if a < -32768 || a > 65535
            raise "number (#{a}) out of bound at line #{i+1}"
          end
          a & 65535
        end
      end
      [op, *args, lineno]
    }

    return [@code, @data]
  end

  def emit_cmp(g, op, lhs, rhs)
    if op == :jmp
      g.add(WRK, 1)
    else
      lhspos = WRK
      rhspos = WRK+2
      if op == :gt || op == :le
        lhspos = WRK+2
        rhspos = WRK
      end

      g.copy_word(regpos(lhs), lhspos, WRK+4)
      if sym?(rhs)
        g.copy_word(regpos(rhs), rhspos, WRK+4)
      else
        g.add_word(rhspos, rhs)
      end

      if op == :eq || op == :ne
        g.move_ptr(WRK)
        g.emit '[->>-<<]'
        g.move_ptr(WRK+1)
        g.emit '[->>-<<]'

        if op == :eq
          g.add(WRK, 1)
          g.move_ptr(WRK+2)
          g.emit '[[-]<<[-]>>]'
          g.move_ptr(WRK+3)
          g.emit '[[-]<<<[-]>>>]'
        else
          g.move_ptr(WRK+2)
          g.emit '[[-]<<+>>]'
          g.move_ptr(WRK+3)
          g.emit '[[-]<<<+>>>]'
        end
      else
        # Compare the higher byte first.
        g.move_ptr(WRK)
        g.emit '[->>'
        # If the RHS becomes zero at this moment, LHS >=
        # RHS. Modify the next byte.
        g.ifzero(2) do
          g.emit '<[-]<+<<[-]>>>>'
        end
        g.emit '<<<<'
        g.emit '-<<]'

        # LH=0. If RH is also zero compare the lower byte.
        g.emit '>>>>>>-<<<<[[-]>>]>>+'  # 0 LL RH RL 0 0 -1
        g.emit '[-<<<'

        # Compare the lower byte.
        g.emit '[->>'
        g.ifzero(1) do
          g.emit '<<<<+>>>>'
        end
        g.emit '<<'
        g.emit '-<<]'

        # LL=0. Check RL again.
        g.emit '>>'
        g.ifzero(1, true) do
          g.emit '<<<<+>>>>'
        end
        g.emit '>+]'

        g.set_ptr(WRK+6)

        g.clear(WRK+1)
        g.clear_word(WRK+2)
        g.clear_word(WRK+4)

        # Negate the result.
        if op == :lt || op == :gt
          g.move_ptr(WRK+2)
          g.emit '-<<[[-]>]>+[-<+>>+]'
        end

      end
    end
  end

  def emit(g)
    g.comment 'fetch pc'
    g.move_word2(PC, NPC, OP)

    g.comment 'increment pc'
    g.move_ptr(NPC+3)
    g.emit '-'
    g.move_ptr(NPC+1)
    g.emit '+'
    g.emit '[>]>+'
    # if 0
    g.emit '[-<<+>>>+]'
    g.set_ptr(NPC+3)

    # -1 0 PC_H PC_L 0 -1
    256.times do |pc_h|
      g.comment("pc_h=#{pc_h}")

      g.add(OP-2, -1)
      g.move_ptr(OP)
      g.emit '[<]<+[-<+'
      g.set_ptr(OP-2)

      256.times do |pc_l|
        pc = pc_h * 256 + pc_l
        a = @code[pc]
        break if !a
        op, *args, lineno = *a
        g.comment("pc=#{pc} op=#{op} #{args*" "}")

        g.add(OP+3, -1)
        g.move_ptr(OP+1)
        g.emit '[>]>+[->+'
        g.set_ptr(OP+3)

        g.emit '@' if $verbose
        g.dbg("#{op} pc=#{pc}\n", OP+3)

        case op
        when :mov
          dest = regpos(args[0])
          if sym?(args[1])
            src = regpos(args[1])
            if src != dest
              g.clear_word(dest)
              g.copy_word(src, dest, WRK)
            end
          else
            g.clear_word(dest)
            g.add_word(dest, args[1])
          end

        when :add
          dest = regpos(args[0])
          if sym?(args[1])
            src = regpos(args[1])
            if src == dest
              raise 'TODO?'
            end
            g.copy_word(src, WRK, WRK+2)
          else
            g.add_word(WRK, args[1])
          end

          # Add WRK to dest.
          g.move_ptr(WRK+1)
          g.emit '[-'
          # Put marker.
          g.add(dest+3, -1)
          # Increment.
          g.move_ptr(dest+1)
          g.emit '+'
          # Carry?
          g.emit '[>]>+[-'
          g.emit '<<+>>>'
          g.emit '+]'
          g.set_ptr(dest+3)

          g.move_ptr(WRK+1)
          g.emit ']'

          # Dest wasn't cleared, so this is actually an addition.
          g.move(WRK, dest)

        when :sub
          dest = regpos(args[0])
          if sym?(args[1])
            src = regpos(args[1])
            if src == dest
              raise 'TODO?'
            end
            g.copy_word(src, WRK, WRK+2)
          else
            g.add_word(WRK, args[1])
          end

          # Subtract WRK from dest.
          g.move_ptr(WRK+1)
          g.emit '[-'
          # Put marker.
          g.add(dest+3, -1)
          g.move_ptr(dest+1)
          # Carry?
          g.emit '[>]>+[-'
          g.emit '<<->>>'
          g.emit '+]'
          g.set_ptr(dest+3)
          # Decrement.
          g.move_ptr(dest+1)
          g.emit '-'

          g.move_ptr(WRK+1)
          g.emit ']'

          # Dest wasn't cleared, so this is actually a subtraction.
          g.move(WRK, dest, -1)

        when :eq, :ne, :lt, :gt, :le, :ge
          emit_cmp(g, op, args[0], args[1])

          dest = regpos(args[0])
          g.clear_word(dest)
          g.move_word(WRK, dest+1)

        when :jmp, :jeq, :jne, :jlt, :jgt, :jle, :jge
          cmpop = op
          if cmpop != :jmp
            cmpop = cmpop.to_s[1,2].to_sym
          end
          emit_cmp(g, cmpop, args[1], args[2])

          g.move_ptr(WRK)
          g.emit '[[-]'
          g.clear_word(NPC)
          if sym?(args[0])
            g.copy_word(regpos(args[0]), NPC, WRK)
          else
            g.add_word(NPC, args[0])
          end
          g.move_ptr(WRK)
          g.emit ']'

        when :load
          g.add(LOAD_REQ, 1)
          if regpos(args[0]) != A
            raise 'only "load a, X" is supported'
          end
          if sym?(args[1])
            g.copy_word(regpos(args[1]), MEM + MEM_A, WRK)
          else
            g.add_word(MEM + MEM_A, args[1])
          end

        when :store
          g.add(STORE_REQ, 1)
          g.copy_word(regpos(args[0]), MEM + MEM_V, WRK)
          if sym?(args[1])
            g.copy_word(regpos(args[1]), MEM + MEM_A, WRK)
          else
            g.add_word(MEM + MEM_A, args[1])
          end

        when :putc
          if sym?(args[0])
            src = regpos(args[0])
            g.move_ptr(src+1)
            g.emit '.'
          else
            g.add(WRK, args[0] % 256)
            g.emit '.'
            g.clear(WRK)
          end

        when :getc
          src = regpos(args[0])
          g.clear_word(src)
          g.move_ptr(src+1)
          g.emit ','
          g.emit '+'
          g.ifzero(1) do
            g.add(src + 1, 1)
          end
          g.add(src + 1, -1)

        when :exit
          g.clear(RUNNING)

        when :dump
          g.emit '@'

        end

        g.move_ptr(OP+3)
        g.emit ']'
        g.add(OP+1, -1)

      end

      g.move_ptr(OP-2)
      g.emit ']'
      g.add(OP, -1)

    end

    g.clear_word(OP)

  end

  def dump
    @code.each do |c|
      p c
    end
  end

end

if $0 == __FILE__
  asm = BFAsm.new
  asm.parse(File.read(ARGV[0]))
  asm.dump
end
