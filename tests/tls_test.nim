# Test Thread Local Storage (TLS) functionality using basic assembly API

import "../src/asm_x86"
import std/[streams, sequtils, strutils]

proc testTlsFunctionality() =
  echo "=== Thread Local Storage Test ===\n"

  # Test 1: Simulate TLS variable access patterns
  echo "1. Simulating TLS variable access patterns:"

  var buf = initBuffer()

  # Create labels for TLS functions
  let tlsCounterLabel = buf.createLabel()
  let tlsFlagLabel = buf.createLabel()
  let tlsBufferLabel = buf.createLabel()

  # Function that would increment TLS counter
  buf.defineLabel(tlsCounterLabel)
  # Simulate TLS access: load from TLS variable
  emitMov(buf, RAX, RBX)  # Simulate loading TLS counter
  emitAddImm(buf, RAX, 1)  # Increment counter
  emitMov(buf, RBX, RAX)  # Simulate storing back to TLS
  emitRet(buf)

  echo "   TLS counter function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Test 2: TLS flag operations
  echo "2. TLS flag operations:"

  buf = initBuffer()

  # Function that would set TLS flag
  buf.defineLabel(tlsFlagLabel)
  emitMovImmToReg(buf, RAX, 1)  # Set flag to 1
  emitMov(buf, RBX, RAX)  # Simulate storing to TLS flag
  emitRet(buf)

  echo "   TLS flag function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Test 3: TLS buffer access
  echo "3. TLS buffer access:"

  buf = initBuffer()

  # Function that would access TLS buffer
  buf.defineLabel(tlsBufferLabel)
  emitMovImmToReg(buf, RAX, 0x12345678)  # Load data
  emitMov(buf, RBX, RAX)  # Simulate storing to TLS buffer
  emitRet(buf)

  echo "   TLS buffer function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Test 4: Thread-specific operations
  echo "4. Thread-specific operations:"

  buf = initBuffer()

  # Create labels for thread functions
  let mainLabel = buf.createLabel()
  let threadLabel = buf.createLabel()
  let workLabel = buf.createLabel()

  # Main function that would use TLS
  buf.defineLabel(mainLabel)
  emitMov(buf, RAX, RBX)  # Simulate getting thread ID from TLS
  emitCall(buf, threadLabel)  # Call thread function
  emitRet(buf)

  # Thread function
  buf.defineLabel(threadLabel)
  emitMov(buf, RAX, RBX)  # Simulate accessing TLS thread data
  emitCmp(buf, RAX, RCX)
  emitJe(buf, workLabel)  # Conditional jump based on TLS data
  emitRet(buf)

  # Work function
  buf.defineLabel(workLabel)
  emitAdd(buf, RAX, RDX)  # Do work with TLS data
  emitRet(buf)

  echo "   Thread functions: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo "   Jumps: ", buf.jumps.len
  echo ""

  # Test 5: Optimized TLS operations
  echo "5. Optimized TLS operations:"

  buf = initBuffer()

  # Create labels for optimized TLS functions
  let optimizedLabel = buf.createLabel()
  let loopLabel = buf.createLabel()
  let exitLabel = buf.createLabel()

  # Optimized function with TLS-like operations
  buf.defineLabel(optimizedLabel)
  emitMov(buf, RAX, RBX)  # Simulate TLS variable access
  emitCmp(buf, RAX, RCX)
  emitJe(buf, exitLabel)  # Conditional jump
  emitJmp(buf, loopLabel)  # Loop

  # Loop body
  buf.defineLabel(loopLabel)
  emitAdd(buf, RAX, RDX)  # Work with TLS-like data
  emitCmp(buf, RAX, RCX)
  emitJl(buf, loopLabel)  # Loop back
  emitJmp(buf, exitLabel)

  # Exit
  buf.defineLabel(exitLabel)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  # Optimize jumps
  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Test 6: Write TLS-like assembly to file
  echo "6. Writing TLS-like assembly to file:"

  buf = initBuffer()

  # Create a complete TLS-like program
  let tlsMainLabel = buf.createLabel()
  let tlsHelperLabel = buf.createLabel()

  # Main TLS function
  buf.defineLabel(tlsMainLabel)
  emitMov(buf, RAX, RBX)  # Simulate TLS access
  emitCall(buf, tlsHelperLabel)  # Call helper
  emitRet(buf)

  # Helper function
  buf.defineLabel(tlsHelperLabel)
  emitAdd(buf, RAX, RCX)  # Work with TLS data
  emitRet(buf)

  # Write to file
  let filename = "tls_like.bin"
  let file = newFileStream(filename, fmWrite)
  for b in buf.data:
    file.write(b)
  file.close()

  echo "   Written TLS-like assembly: ", filename
  echo "   File size: ", buf.data.len, " bytes"
  echo "   Assembly bytes: ", buf.data.mapIt(it.toHex(2).toUpper()).join(" ")
  echo ""

  echo "=== TLS Test Complete ==="
  echo ""
  echo "Note: This test simulates TLS concepts using basic assembly."
  echo "Actual TLS support requires higher-level APIs not yet implemented."
  echo ""
  echo "TLS concepts demonstrated:"
  echo "  - Thread-local variable access patterns"
  echo "  - Conditional operations based on TLS data"
  echo "  - Function calls with TLS context"
  echo "  - Jump optimization for TLS operations"

when isMainModule:
  testTlsFunctionality()
