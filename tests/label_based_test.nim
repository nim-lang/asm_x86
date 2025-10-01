# Test label-based jump optimization

import "../src/asm_x86"

proc testLabelBasedOptimization() =
  echo "=== Label-Based Jump Optimization Test ===\n"

  # Test 1: Simple label-based jumps
  echo "1. Testing simple label-based jumps:"
  var buf = initBuffer()

  # Create labels
  let startLabel = buf.createLabel()
  let endLabel = buf.createLabel()

  # Define start label
  buf.defineLabel(startLabel)

  # Emit some instructions
  emitMov(buf, RAX, RBX)
  emitAdd(buf, RAX, RCX)

  # Jump to end (will be optimized)
  emitJmp(buf, endLabel)

  # Some padding
  emitNop(buf)
  emitNop(buf)

  # Define end label
  buf.defineLabel(endLabel)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  # Optimize jumps
  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  # Test 2: Conditional jumps with labels
  echo "2. Testing conditional jumps with labels:"
  buf = initBuffer()

  let loopStart = buf.createLabel()
  let loopEnd = buf.createLabel()

  # Define loop start
  buf.defineLabel(loopStart)

  # Some loop body
  emitMov(buf, RAX, RBX)
  emitCmp(buf, RAX, RCX)

  # Conditional jump (will be optimized)
  emitJe(buf, loopEnd)

  # More instructions
  emitAdd(buf, RAX, RDX)
  emitJmp(buf, loopStart)

  # Define loop end
  buf.defineLabel(loopEnd)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  # Test 3: Multiple jumps to same label
  echo "3. Testing multiple jumps to same label:"
  buf = initBuffer()

  let target = buf.createLabel()

  # First jump
  emitJmp(buf, target)
  emitNop(buf)

  # Second jump
  emitJe(buf, target)
  emitNop(buf)

  # Third jump
  emitJne(buf, target)
  emitNop(buf)

  # Define target
  buf.defineLabel(target)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  # Test 4: Complex control flow
  echo "4. Testing complex control flow:"
  buf = initBuffer()

  let entry = buf.createLabel()
  let loop = buf.createLabel()
  let exit = buf.createLabel()

  # Entry point
  buf.defineLabel(entry)
  emitMov(buf, RAX, RBX)
  emitCmp(buf, RAX, RCX)
  emitJg(buf, loop)  # Jump if greater

  # Exit path
  emitJmp(buf, exit)

  # Loop body
  buf.defineLabel(loop)
  emitAdd(buf, RAX, RDX)
  emitCmp(buf, RAX, RCX)
  emitJl(buf, loop)  # Jump if less (back to loop)

  # Exit
  buf.defineLabel(exit)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  # Test 5: Forward and backward jumps
  echo "5. Testing forward and backward jumps:"
  buf = initBuffer()

  let forward = buf.createLabel()
  let backward = buf.createLabel()

  # Forward jump
  emitJmp(buf, forward)

  # Backward target
  buf.defineLabel(backward)
  emitNop(buf)
  emitJmp(buf, backward)  # Backward jump

  # Forward target
  buf.defineLabel(forward)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes\n"

  echo "=== Label-based jump optimization test completed! ==="

when isMainModule:
  testLabelBasedOptimization()
