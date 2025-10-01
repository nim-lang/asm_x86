# Example: How to define functions using the basic assembly API

import "../src/asm_x86"

proc exampleFunctionDefinition() =
  echo "=== Function Definition Example ===\n"

  # Method 1: Simple function definition using labels
  echo "1. Basic function definition using labels:"

  var buf = initBuffer()

  # Create labels for functions
  let addNumbersLabel = buf.createLabel()
  let multiplyLabel = buf.createLabel()
  let helperLabel = buf.createLabel()

  # Define add_numbers function
  buf.defineLabel(addNumbersLabel)
  emitMov(buf, RAX, RBX)      # Move first argument to RAX
  emitAdd(buf, RAX, RCX)       # Add second argument
  emitRet(buf)                 # Return result in RAX

  # Define multiply function
  buf.defineLabel(multiplyLabel)
  emitMov(buf, RAX, RBX)      # Move first argument to RAX
  emitImul(buf, RAX, RCX)      # Multiply by second argument
  emitRet(buf)                 # Return result in RAX

  # Define helper function
  buf.defineLabel(helperLabel)
  emitMov(buf, RAX, RBX)
  emitRet(buf)

  echo "   add_numbers function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Method 2: Function with conditional logic
  echo "2. Function with conditional logic:"

  buf = initBuffer()

  # Create labels for conditional jumps
  let maxLabel = buf.createLabel()
  let skipLabel = buf.createLabel()

  # Define max function: max(a, b) -> maximum of a and b
  buf.defineLabel(maxLabel)
  emitCmp(buf, RAX, RBX)       # Compare RAX and RBX
  emitJg(buf, skipLabel)      # Jump if RAX > RBX
  emitMov(buf, RAX, RBX)       # RAX = RBX (if RAX <= RBX)
  buf.defineLabel(skipLabel)
  emitRet(buf)                # Return result in RAX

  echo "   max function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Method 3: Function with loops
  echo "3. Function with loops:"

  buf = initBuffer()

  let loopStartLabel = buf.createLabel()
  let exitLabel = buf.createLabel()

  # Define loop function: count down from RAX to 0
  # First, set RCX to 0 for comparison
  emitMovImmToReg(buf, RCX, 0)
  buf.defineLabel(loopStartLabel)
  emitCmp(buf, RAX, RCX)        # Compare RAX with RCX (0)
  emitJe(buf, exitLabel)        # Exit if RAX == 0
  emitSubImm(buf, RAX, 1)       # RAX = RAX - 1
  emitJmp(buf, loopStartLabel)  # Loop back
  buf.defineLabel(exitLabel)
  emitRet(buf)

  echo "   countdown function: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  # Method 4: Optimized function with finalize
  echo "4. Optimized function with finalize:"

  buf = initBuffer()

  let optimizedLabel = buf.createLabel()
  let jumpLabel = buf.createLabel()

  # Define optimized function
  buf.defineLabel(optimizedLabel)
  emitMov(buf, RAX, RBX)
  emitCmp(buf, RAX, RCX)
  emitJe(buf, jumpLabel)      # Conditional jump
  emitAdd(buf, RAX, RDX)
  buf.defineLabel(jumpLabel)
  emitRet(buf)

  echo "   Before optimization: ", buf
  echo "   Length: ", buf.len, " bytes"

  # Optimize jumps
  buf.finalize()

  echo "   After optimization: ", buf
  echo "   Length: ", buf.len, " bytes"
  echo ""

  echo "=== Function Definition Example Complete ==="
  echo ""
  echo "Note: This example uses the basic assembly API."
  echo "Higher-level function definition APIs are not yet implemented."

when isMainModule:
  exampleFunctionDefinition()
