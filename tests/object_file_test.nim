# Test object file generation using basic assembly API

import "../src/asm_x86"
import std/[strutils, sequtils, streams]

proc testObjectFileGeneration() =
  echo "=== Object File Generation Test ===\n"

  # Test 1: Simple function assembly
  echo "1. Testing simple function assembly:"
  var buf = initBuffer()

  # Create a label for our function
  let myFunctionLabel = buf.createLabel()
  buf.defineLabel(myFunctionLabel)

  # Generate the function
  emitMov(buf, RAX, RBX)
  emitAdd(buf, RAX, RCX)
  emitRet(buf)

  echo "   Function assembly: ", buf
  echo "   Function length: ", buf.len, " bytes"
  echo "   Function label position: ", buf.getLabelPosition(myFunctionLabel)
  echo ""

  # Test 2: Function with external call using labels
  echo "2. Testing function with external call using labels:"
  buf = initBuffer()

  # Create labels for function entry and external call
  let mainLabel = buf.createLabel()
  let printfLabel = buf.createLabel()

  # Define main function
  buf.defineLabel(mainLabel)
  emitMov(buf, RAX, RBX)
  emitCall(buf, printfLabel)  # Call external function using label
  emitRet(buf)

  # Note: printfLabel would be defined by the linker
  echo "   Main function with external call: ", buf
  echo "   Function length: ", buf.len, " bytes"
  echo "   External call at position: ", buf.getCurrentPosition() - 5  # CALL is 5 bytes
  echo ""

  # Test 3: Function with internal calls
  echo "3. Testing function with internal calls:"
  buf = initBuffer()

  # Create labels for different parts of the function
  let startLabel = buf.createLabel()
  let helperLabel = buf.createLabel()
  let endLabel = buf.createLabel()

  # Define start of function
  buf.defineLabel(startLabel)
  emitMov(buf, RAX, RBX)
  emitCmp(buf, RAX, RCX)
  emitJe(buf, endLabel)  # Jump to end if equal

  # Call helper function
  emitCall(buf, helperLabel)
  emitJmp(buf, endLabel)

  # Define helper function
  buf.defineLabel(helperLabel)
  emitAdd(buf, RAX, RDX)
  emitRet(buf)

  # Define end of function
  buf.defineLabel(endLabel)
  emitRet(buf)

  echo "   Function with internal calls: ", buf
  echo "   Function length: ", buf.len, " bytes"
  echo "   Internal calls: ", buf.jumps.len
  echo ""

  # Test 4: Optimized function with finalize
  echo "4. Testing optimized function with finalize:"
  buf = initBuffer()

  # Create labels for optimized function
  let optimizedLabel = buf.createLabel()
  let loopLabel = buf.createLabel()
  let exitLabel = buf.createLabel()

  # Define optimized function
  buf.defineLabel(optimizedLabel)
  emitMov(buf, RAX, RBX)
  emitCmp(buf, RAX, RCX)
  emitJe(buf, exitLabel)  # Conditional jump
  emitJmp(buf, loopLabel)  # Unconditional jump

  # Loop body
  buf.defineLabel(loopLabel)
  emitAdd(buf, RAX, RDX)
  emitCmp(buf, RAX, RCX)
  emitJl(buf, loopLabel)  # Loop back if less
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

  # Test 5: Write assembly to file
  echo "5. Testing assembly output to file:"
  buf = initBuffer()

  # Create a simple function
  let testLabel = buf.createLabel()
  buf.defineLabel(testLabel)
  emitMov(buf, RAX, RBX)
  emitAdd(buf, RAX, RCX)
  emitRet(buf)

  # Write assembly bytes to file
  let filename = "test_output.bin"
  let file = newFileStream(filename, fmWrite)
  for b in buf.data:
    file.write(b)
  file.close()

  echo "   Written assembly file: ", filename
  echo "   File size: ", buf.data.len, " bytes"
  echo "   Assembly bytes: ", buf.data.mapIt(it.toHex(2).toUpper()).join(" ")
  echo ""

  echo "=== Object file generation test completed! ==="
  echo ""
  echo "Note: This test uses the basic assembly API."
  echo "Higher-level object file generation APIs are not yet implemented."

when isMainModule:
  testObjectFileGeneration()
