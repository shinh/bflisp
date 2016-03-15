require './common'

class BFGen
  def initialize
    @mp = 0
  end

  def emit(s)
    @colno = 0 if @colno == nil
    while s.length > 0 do
	if @colno + s.length >= 80
	    puts s.slice!(0, 80-@colno)
	    @colno = 0
	else
	    print s
	    @colno = @colno + s.length
	    return
	end
    end
  end

  def comment(s)
    puts if @colno && @colno > 0
    @colno = 0
    puts "# #{s}"
  end

  def set_ptr(ptr)
    @mp = ptr
  end

  def move_ptr(ptr)
    emit ptr > @mp ? '>' * (ptr - @mp) : '<' * (@mp - ptr)
    @mp = ptr
  end

  def get_memop(m)
    m < 0 ? '-' * -m : '+' * m
  end

  def move(from, to, mul=1)
    move_ptr(from)
    emit '[-'
    move_ptr(to)
    emit get_memop(mul)
    move_ptr(from)
    emit ']'
  end

  def move2(from, to, to2, mul=1)
    move_ptr(from)
    emit '[-'
    move_ptr(to)
    emit get_memop(mul)
    move_ptr(to2)
    emit get_memop(mul)
    move_ptr(from)
    emit ']'
  end

  def move_word(from, to, mul=1)
    move(from-1, to-1, mul) if $bfs24
    move(from, to, mul)
    move(from+1, to+1, mul)
  end

  def move_word2(from, to, to2)
    move2(from-1, to-1, to2-1) if $bfs24
    move2(from, to, to2)
    move2(from+1, to+1, to2+1)
  end

  def copy(from, to, wrk)
    move2(from, to, wrk)
    move(wrk, from)
  end

  def copy_word(from, to, wrk)
    move_word2(from, to, wrk)
    move_word(wrk, from)
  end

  def add_word(ptr, v)
    add(ptr-1, v / 65536) if $bfs24
    add(ptr, v / 256 % 256)
    add(ptr+1, v % 256)
  end

  def add(ptr, v)
    move_ptr(ptr)
    v = v % 256
    v = v - 256 if v > 127
    emit v > 0 ? '+' * v : '-' * -v
  end

  def loop(ptr, op=nil, &cb)
    move_ptr(ptr)
    emit '['
    emit op if op
    cb[]
    move_ptr(ptr)
    emit ']'
  end

  def decloop(ptr, &cb)
    loop(ptr, '-', &cb)
  end

  def not(from, to, wrk)
    add(to, 1)
    move(from, wrk)
    move_ptr(wrk)
    emit '[-'
    move_ptr(from)
    emit '+'
    move_ptr(to)
    emit '[-]'
    move_ptr(wrk)
    emit ']'
  end

  def save_ptr(&cb)
    omp = @mp
    @mp = 0
    cb[]
    @mp = omp
  end

  def ifzero(off, reset=false, ifnz='', &cb)
    omp = @mp
    @mp = 0

    add(off * 2, -1)
    move_ptr(0)
    emit '['
    if reset
      emit '[-]'
    end
    emit ifnz
    move_ptr(off)
    emit ']'
    move_ptr(off * 2)
    emit '+[-'

    @mp = omp + off
    cb[]
    move_ptr(omp + off)

    set_ptr(0)
    move_ptr(off)
    emit '+]'

    @mp = omp + off * 2
  end

  def clear(ptr)
    move_ptr(ptr)
    emit '[-]'
  end

  def clear_word(ptr)
    clear(ptr-1) if $bfs24
    clear(ptr)
    clear(ptr+1)
  end

  def dbg(msg, ptr)
    return if !$verbose
    info(msg, ptr)
  end

  def info(msg, ptr)
    clear(ptr)
    prev = 0
    msg.each_byte{|b|
      add(ptr, b - prev)
      emit '.'
      prev = b
    }
    clear(ptr)
  end

end
