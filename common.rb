if ENV['BFS24']
  $bfs24 = true
  BITS = 24
else
  BITS = 16
end
UINT_MAX = (1 << BITS) - 1
INT_MIN = -(1 << (BITS - 1))

while true
  if ARGV[0] == '-v'
    $verbose = true
    ARGV.shift
  elsif ARGV[0] == '-q'
    $quiet = true
    ARGV.shift
  elsif ARGV[0] == '-m'
    $bfs24 = true
    ARGV.shift
  else
    break
  end
end

RUNNING = 0
PC = 2
NPC = 8
A = 14
B = 20
C = 26
D = 32
BP = 38
SP = 44
OP = 50

WRK = 60

LOAD_REQ = 67
STORE_REQ = 68

MEM = 70
MEM_V = 0
MEM_A = 2
MEM_WRK = 4
MEM_USE = 8
MEM_CTL_LEN = 9
MEM_BLK_LEN = 512 + MEM_CTL_LEN

def sym?(o)
  o.class == Symbol
end

def error(loc, msg)
  filename, lineno, column, len = *loc
  r = "#{filename}:#{lineno}:#{column}"
  if len > 1
    r += "-#{column+len-1}"
  end
  STDERR.puts("#{r}: #{msg}")
  exit 1
end
