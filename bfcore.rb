#!/usr/bin/env ruby

require './common'

class BFCore
  def initialize(g)
    @g = g
  end

  def gen_prologue(data)
    g = @g

    g.comment('init data')
    data.each do |d, i|
      raise if i > 65535
      hi = i / 256
      lo = i % 256
      ptr = MEM + MEM_BLK_LEN * hi + MEM_CTL_LEN + lo * (BITS / 8)
      g.add_word(ptr, d)
    end

    g.comment('prologue')
    g.add(RUNNING, 1)
    g.emit '['
    #g.emit '@'
  end

  def gen_core
    g = @g

    gen_mem_load
    gen_mem_store

    g.move_word(NPC, PC)
  end

  def gen_mem_load
    g = @g
    g.comment 'memory (load)'

    g.decloop(LOAD_REQ) {
      g.move_ptr(MEM)
      g.set_ptr(0)

      if $bfs24
        g.decloop(MEM_A-1) {
          g.move_word(MEM_A, MEM_A + MEM_BLK_LEN*256)
          g.move_ptr(MEM_A + MEM_BLK_LEN*256)
          g.set_ptr(MEM_A)
          g.add(MEM_USE+1, 1)
        }
      end

      g.decloop(MEM_A) {
        g.move_word(MEM_A, MEM_A + MEM_BLK_LEN)
        g.move_ptr(MEM_A + MEM_BLK_LEN)
        g.set_ptr(MEM_A)
        g.add(MEM_USE, 1)
      }

      256.times{|al|
        g.move_ptr(MEM_A + 1)
        g.ifzero(1) do
          g.copy_word(MEM_CTL_LEN + al * (BITS / 8), MEM_V, MEM_WRK + 2)
        end
        g.add(MEM_A + 1, -1)
      }
      g.clear(MEM_A + 1)

      g.decloop(MEM_USE) {
        g.move_word(MEM_V, MEM_V - MEM_BLK_LEN)
        g.move_ptr(MEM_V - MEM_BLK_LEN)
        g.set_ptr(MEM_V)
      }

      if $bfs24
        g.decloop(MEM_USE+1) {
          g.move_word(MEM_V, MEM_V - MEM_BLK_LEN*256)
          g.move_ptr(MEM_V - MEM_BLK_LEN*256)
          g.set_ptr(MEM_V)
        }
      end

      g.move_ptr(0)
      g.set_ptr(MEM)
      g.clear_word(A)
      g.move_word(MEM + MEM_V, A)
    }
  end

  def gen_mem_store
    g = @g
    g.comment 'memory (store)'

    g.decloop(STORE_REQ) {
      g.move_ptr(MEM)
      g.set_ptr(0)

      if $bfs24
        g.decloop(MEM_A-1) {
          g.move_word(MEM_V, MEM_V + MEM_BLK_LEN*256)
          g.move_word(MEM_A, MEM_A + MEM_BLK_LEN*256)
          g.move_ptr(MEM_A + MEM_BLK_LEN*256)
          g.set_ptr(MEM_A)
          g.add(MEM_USE+1, 1)
        }
      end

      g.decloop(MEM_A) {
        g.move_word(MEM_V, MEM_V + MEM_BLK_LEN)
        g.move_word(MEM_A, MEM_A + MEM_BLK_LEN)
        g.move_ptr(MEM_A + MEM_BLK_LEN)
        g.set_ptr(MEM_A)
        g.add(MEM_USE, 1)
      }

      # VH VL 0 AL 1
      256.times{|al|
        g.move_ptr(MEM_A + 1)
        g.ifzero(1) do
          g.clear_word(MEM_CTL_LEN + al * (BITS / 8))
          g.move_word(MEM_V, MEM_CTL_LEN + al * (BITS / 8))
        end
        g.add(MEM_A + 1, -1)
      }
      g.clear(MEM_A + 1)

      g.move_ptr(MEM_USE)
      g.emit '[-' + '<' * MEM_BLK_LEN + ']'

      if $bfs24
        g.move_ptr(MEM_USE+1)
        g.emit '[-' + '<' * (MEM_BLK_LEN*256) + ']'
      end

      g.move_ptr(0)
      g.set_ptr(MEM)
    }
  end

  def gen_epilogue
    g = @g
    g.comment('epilogue')
    g.move_ptr(RUNNING)
    g.emit ']'
  end

end

if __FILE__ == $0
  require './bfasm'
  require './bfgen'

  bfa = BFAsm.new
  code, data = bfa.parse(File.read(ARGV[0]))

  g = BFGen.new
  bfc = BFCore.new(g)
  bfc.gen_prologue(data)
  bfa.emit(g)
  bfc.gen_core
  bfc.gen_epilogue
end
