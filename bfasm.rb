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

    @code << [[:jmp, 'main', -1]]
    @labels['main'] = 1
    @labeled_pcs = { 1 => true }

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
    if @data.size > 60000
      raise "Too much data!"
    end
  end

  def parse(code)
    in_data = false
    prev_op = nil
    code.split("\n").each_with_index do |line, lineno|
      lineno += 1

      # TODO: Weird!
      line.sub!(/(^#| # ).*/, '')
      line.strip!
      next if line.empty?

      if line =~ /^\.(text|data)/
        in_data = $1 == 'data'
        if in_data
          if $' =~ / (-?\d+)/
            add_data(cur_data_addr + $1.to_i)
          end
        end
        next
      end

      if line =~ /^(\.?\w+):$/
        if @labels[$1] && $1 != 'main'
          raise "multiple label definition (#$1) at line #{lineno}"
        end
        if in_data
          @labels[$1] = cur_data_addr
        else
          @labeled_pcs[@code.size] = true
          @labels[$1] = @code.size
        end
        next
      end

      if in_data
        if line =~ /^\.long (-?\d+)/
          add_data($1.to_i & UINT_MAX)
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

      if (@code.size == 1 || @labeled_pcs[@code.size] ||
          (%i(load store putc getc exit) + @jmp_ops.keys).include?(prev_op))
        @code << [[op, *args, lineno]]
      else
        @code[-1] << [op, *args, lineno]
      end
      prev_op = op
    end

    @data[0][0] = cur_data_addr

    @code = @code.each_with_index.map{|opa, i|
      opa.map do |op, *args, lineno|
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
            if a < INT_MIN || a > UINT_MAX
              raise "number (#{a}) out of bound at line #{i+1}"
            end
            a & UINT_MAX
          end
        end
        [op, *args, lineno]
      end
    }

    return [@code, @data]
  end

  def emit_cmp(g, op, lhs, rhs)
    if op == :jmp
      g.add(WRK, 1)
    else
      lhspos = WRK
      rhspos = WRK+3
      if op == :gt || op == :le
        lhspos = WRK+3
        rhspos = WRK
      end

      g.copy_word(regpos(lhs), lhspos, WRK+6)
      if sym?(rhs)
        g.copy_word(regpos(rhs), rhspos, WRK+6)
      else
        g.add_word(rhspos, rhs)
      end

      if op == :eq || op == :ne
        r = (($bfs24 ? -1 : 0) .. 1)
        r.each {|i|
          g.move(WRK+i, WRK+3+i, -1)
        }

        if op == :eq
          g.add(WRK, 1)
          r.each {|i|
            g.loop(WRK+3+i){
              g.clear(WRK+3+i)
              g.clear(WRK)
            }
          }
        else
          r.each {|i|
            g.loop(WRK+3+i){
              g.clear(WRK+3+i)
              g.add(WRK, 1)
            }
          }
        end
      else
        ge_rest = proc {
          # Compare the higher byte first.
          g.decloop(WRK){
            g.move_ptr(WRK+3)
            # If the RHS becomes zero at this moment, LHS >=
            # RHS. Modify the next byte.
            g.ifzero(3) do
              g.clear(WRK+4)
              g.add(WRK+3, 1)
              g.clear(WRK)
            end
            g.add(WRK+3, -1)
          }

          # LH=0. If RH is also zero compare the lower byte.
          g.move_ptr(WRK+3)
          g.ifzero(3, true) {
            # Compare the lower byte.
            g.decloop(WRK+1) {
              g.move_ptr(WRK+4)
              g.ifzero(1) do
                g.add(WRK, 1)
              end
              g.add(WRK+4, -1)
            }

            # LL=0. Check RL again.
            g.move_ptr(WRK+4)
            g.ifzero(1, true) do
              g.add(WRK, 1)
            end
          }
        }

        if $bfs24
          g.decloop(WRK-1){
            g.move_ptr(WRK+2)
            # If the RHS becomes zero at this moment, LHS >=
            # RHS. Modify the next byte.
            g.ifzero(5) do
              g.clear(WRK-1)
              g.clear(WRK)
              g.clear(WRK+1)
              g.clear(WRK+3)
              g.clear(WRK+4)
              g.add(WRK+2, 1)
            end
            g.add(WRK+2, -1)
          }

          g.move_ptr(WRK+2)
          g.ifzero(4, true, '<<[-]>>') {
            ge_rest[]
          }
        else
          ge_rest[]
        end

        g.clear(WRK+1)
        g.clear_word(WRK+3)
        g.clear_word(WRK+6)

        # Negate the result.
        if op == :lt || op == :gt
          g.move_ptr(WRK)
          g.ifzero(1, true) {
            g.add(WRK, 1)
          }
        end

      end
    end
  end

  def emit_op(g, op, args, lineno)
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
        g.copy_word(src, WRK, WRK+3)
      else
        g.add_word(WRK, args[1])
      end

      # Add WRK to dest.
      g.decloop(WRK+1) {
        # Increment.
        g.move_ptr(dest+1)
        g.emit '+'
        # Carry?
        g.ifzero(1) {
          g.add(dest, 1)
          if $bfs24
            g.move_ptr(dest)
            g.ifzero(2) {
              g.add(dest-1, 1)
            }
          end
        }
      }

      if $bfs24
        g.decloop(WRK) {
          # Increment.
          g.move_ptr(dest)
          g.emit '+'
          # Carry?
          g.ifzero(2) {
            g.add(dest-1, 1)
          }
        }
        g.move(WRK-1, dest-1)
      else
        # Dest wasn't cleared, so this is actually an addition.
        g.move(WRK, dest)
      end

    when :sub
      dest = regpos(args[0])
      if sym?(args[1])
        src = regpos(args[1])
        if src == dest
          raise 'TODO?'
        end
        g.copy_word(src, WRK, WRK+3)
      else
        g.add_word(WRK, args[1])
      end

      # Subtract WRK from dest.
      g.decloop(WRK+1) {
        g.move_ptr(dest+1)
        # Carry?
        g.ifzero(1) {
          if $bfs24
            g.move_ptr(dest)
            g.ifzero(2) {
              g.add(dest-1, -1)
            }
          end
          g.add(dest, -1)
        }
        # Decrement.
        g.add(dest+1, -1)
      }

      if $bfs24
        g.decloop(WRK) {
          g.move_ptr(dest)
          # Carry?
          g.ifzero(2) {
            g.add(dest-1, -1)
          }
          # Decrement.
          g.add(dest, -1)
        }
        g.move(WRK-1, dest-1, -1)
      else
        # Dest wasn't cleared, so this is actually a subtraction.
         g.move(WRK, dest, -1)
      end

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
        r = regpos(args[0])
        g.copy_word(r, NPC, WRK)
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

        g.add(OP+3, -1)
        g.move_ptr(OP+1)
        g.emit '[>]>+[->+'
        g.set_ptr(OP+3)

        a.each{|op, *args, lineno|
          g.comment("pc=#{pc} op=#{op} #{args*" "}")
          g.emit '@' if $verbose
          g.dbg("#{op} pc=#{pc}\n", OP+3)

          emit_op(g, op, args, lineno)
        }

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
