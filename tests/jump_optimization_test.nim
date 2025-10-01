# Test jump optimization functionality

import "../src/asm_x86"

proc testJumpOptimization() =
  echo "=== Jump Optimization Test ===\n"

  # Test 1: Short jumps that can be optimized
  echo "1. Testing short jumps (should be optimized to 8-bit):"
  var buf = initBuffer()

  # Create a short forward jump
  let target1 = buf.createLabel()
  emitJmp(buf, target1)  # Jump to target
  emitNop(buf)           # NOP
  emitNop(buf)           # NOP
  emitNop(buf)           # NOP
  buf.defineLabel(target1)
  emitRet(buf)           # Target instruction

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  # Optimize jumps
  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo "   Saved: ", 5 - buf.len, " bytes\n"

  # Test 2: Conditional jumps
  echo "2. Testing conditional short jumps:"
  buf = initBuffer()

  let target2 = buf.createLabel()
  emitJe(buf, target2)   # Jump if equal to target
  emitNop(buf)           # 1 NOP
  buf.defineLabel(target2)
  emitRet(buf)           # Target instruction

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo "   Saved: ", 6 - buf.len, " bytes\n"

  # Test 3: Long jumps that cannot be optimized
  echo "3. Testing long jumps (cannot be optimized):"
  buf = initBuffer()

  let target3 = buf.createLabel()
  emitJmp(buf, target3)  # Jump to target (will be far)
  for i in 0..<50:
    emitNop(buf)         # Create distance
  buf.defineLabel(target3)
  emitRet(buf)           # Target instruction

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo "   No optimization possible (distance too large)\n"

  # Test 4: Mixed short and long jumps
  echo "4. Testing mixed jump types:"
  buf = initBuffer()

  # Short jump
  let target4a = buf.createLabel()
  emitJe(buf, target4a)
  emitNop(buf)
  emitNop(buf)
  buf.defineLabel(target4a)
  emitRet(buf)

  # Long jump
  let target4b = buf.createLabel()
  emitJmp(buf, target4b)
  for i in 0..<25:
    emitNop(buf)
  buf.defineLabel(target4b)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  # Test 5: All conditional jump types
  echo "5. Testing all conditional jump types:"
  buf = initBuffer()

  let target5 = buf.createLabel()
  emitJe(buf, target5)    # JE
  emitJne(buf, target5)    # JNE
  emitJg(buf, target5)     # JG
  emitJl(buf, target5)     # JL
  emitJge(buf, target5)    # JGE
  emitJle(buf, target5)    # JLE
  emitJa(buf, target5)     # JA
  emitJb(buf, target5)     # JB
  emitJae(buf, target5)    # JAE
  emitJbe(buf, target5)    # JBE
  buf.defineLabel(target5)
  emitRet(buf)             # Target for all jumps

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo "   Saved: ", 60 - buf.len, " bytes\n"

  echo "=== Jump optimization test completed! ==="

when isMainModule:
  testJumpOptimization()
