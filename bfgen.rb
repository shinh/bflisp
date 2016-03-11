require './common'

class BFGen
  def initialize
    @mp = 0
  end

  def emit(s)
    @started = true
    print s
  end

  def comment(s)
    puts if @started
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
    #move(from-1, to-1, mul) if $bfs24
    move(from, to, mul)
    move(from+1, to+1, mul)
  end

  def move_word2(from, to, to2)
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
    add(ptr, v / 256)
    add(ptr+1, v % 256)
  end

  def add(ptr, v)
    move_ptr(ptr)
    emit v > 0 ? '+' * v : '-' * -v
  end

  def loop(ptr, &cb)
    move_ptr(ptr)
    emit '['
    cb[]
    move_ptr(ptr)
    emit ']'
  end

  def save_ptr(&cb)
    omp = @mp
    @mp = 0
    cb[]
    @mp = omp
  end

  def ifzero(off, reset=false, &cb)
    omp = @mp
    @mp = 0

    add(off * 2, -1)
    move_ptr(0)
    emit '['
    if reset
      emit '[-]'
    end
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
    clear(ptr)
    clear(ptr+1)
  end

  def dbg(msg, ptr)
    return if !$verbose
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
