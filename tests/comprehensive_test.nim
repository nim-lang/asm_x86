# Comprehensive test for Nifasm x86_64 assembler
# This test demonstrates all major instruction categories

import "../src/asm_x86"

proc testAllInstructions() =
  echo "=== Nifasm x86_64 Assembler Comprehensive Test ===\n"

  # Test 1: Basic MOV instructions
  echo "1. Data Movement Instructions:"
  var buf = initBuffer()
  emitMov(buf, RAX, RBX)
  echo "   MOV RAX, RBX: ", buf

  buf = initBuffer()
  emitMovImmToReg(buf, RAX, 42)
  echo "   MOV RAX, 42: ", buf

  buf = initBuffer()
  emitMovImmToReg32(buf, RCX, 0x12345678)
  echo "   MOV RCX, 0x12345678: ", buf

  buf = initBuffer()
  emitMov(buf, R8, R9)
  echo "   MOV R8, R9: ", buf

  # Test 2: Arithmetic instructions
  echo "\n2. Arithmetic Instructions:"
  buf = initBuffer()
  emitAdd(buf, RAX, RBX)
  echo "   ADD RAX, RBX: ", buf

  buf = initBuffer()
  emitSub(buf, RCX, RDX)
  echo "   SUB RCX, RDX: ", buf

  buf = initBuffer()
  emitAddImm(buf, RAX, 10)
  echo "   ADD RAX, 10: ", buf

  buf = initBuffer()
  emitSubImm(buf, RBX, 5)
  echo "   SUB RBX, 5: ", buf

  buf = initBuffer()
  emitMul(buf, RCX)
  echo "   MUL RCX: ", buf

  buf = initBuffer()
  emitDiv(buf, RDX)
  echo "   DIV RDX: ", buf

  # Test 3: Bit manipulation instructions
  echo "\n3. Bit Manipulation Instructions:"
  buf = initBuffer()
  emitAnd(buf, RAX, RBX)
  echo "   AND RAX, RBX: ", buf

  buf = initBuffer()
  emitOr(buf, RCX, RDX)
  echo "   OR RCX, RDX: ", buf

  buf = initBuffer()
  emitXor(buf, RAX, RBX)
  echo "   XOR RAX, RBX: ", buf

  buf = initBuffer()
  emitNot(buf, RCX)
  echo "   NOT RCX: ", buf

  buf = initBuffer()
  emitShl(buf, RAX, 2)
  echo "   SHL RAX, 2: ", buf

  buf = initBuffer()
  emitShr(buf, RBX, 1)
  echo "   SHR RBX, 1: ", buf

  # Test 4: Control flow instructions
  echo "\n4. Control Flow Instructions:"
  buf = initBuffer()
  emitRet(buf)
  echo "   RET: ", buf

  buf = initBuffer()
  let callTarget = createLabel(buf)
  emitCall(buf, callTarget)
  defineLabel(buf, callTarget)
  echo "   CALL label: ", buf

  buf = initBuffer()
  let jmpTarget = createLabel(buf)
  emitJmp(buf, jmpTarget)
  defineLabel(buf, jmpTarget)
  echo "   JMP label: ", buf

  buf = initBuffer()
  emitJmpReg(buf, RAX)
  echo "   JMP RAX: ", buf

  buf = initBuffer()
  let jeTarget = createLabel(buf)
  emitJe(buf, jeTarget)
  defineLabel(buf, jeTarget)
  echo "   JE label: ", buf

  buf = initBuffer()
  let jneTarget = createLabel(buf)
  emitJne(buf, jneTarget)
  defineLabel(buf, jneTarget)
  echo "   JNE label: ", buf

  buf = initBuffer()
  let jgTarget = createLabel(buf)
  emitJg(buf, jgTarget)
  defineLabel(buf, jgTarget)
  echo "   JG label: ", buf

  buf = initBuffer()
  let jlTarget = createLabel(buf)
  emitJl(buf, jlTarget)
  defineLabel(buf, jlTarget)
  echo "   JL label: ", buf

  # Test 5: Stack operations (not implemented yet)
  echo "\n5. Stack Operations:"
  echo "   Stack operations (PUSH/POP) not yet implemented in the API"

  # Test 6: Comparison instructions
  echo "\n6. Comparison Instructions:"
  buf = initBuffer()
  emitCmp(buf, RAX, RBX)
  echo "   CMP RAX, RBX: ", buf

  buf = initBuffer()
  emitTest(buf, RCX, RDX)
  echo "   TEST RCX, RDX: ", buf

  # Test 7: System instructions
  echo "\n7. System Instructions:"
  buf = initBuffer()
  emitSyscall(buf)
  echo "   SYSCALL: ", buf

  # Note: INT instruction not yet implemented in the API
  echo "   INT instruction not yet implemented in the API"

  # Test 8: NOP instructions
  echo "\n8. NOP Instructions:"
  buf = initBuffer()
  emitNop(buf)
  echo "   NOP: ", buf

  # Note: Multi-byte NOP not yet implemented in the API
  echo "   Multi-byte NOP not yet implemented in the API"

  # Test 9: Complete function example
  echo "\n9. Complete Function Example:"
  buf = initBuffer()

  # Function: multiply_by_two(x) -> x * 2
  emitShl(buf, RAX, 1)  # SHL RAX, 1 (multiply by 2)
  emitRet(buf)          # RET

  echo "   multiply_by_two function: ", buf

  # Test 10: Complex function example
  echo "\n10. Complex Function Example:"
  buf = initBuffer()

  # Function: max(a, b) -> maximum of a and b
  emitCmp(buf, RAX, RBX)  # CMP RAX, RBX
  let skipLabel = createLabel(buf)
  emitJg(buf, skipLabel)  # JG skip (jump if RAX > RBX)
  emitMov(buf, RAX, RBX)  # MOV RAX, RBX (RAX = RBX)
  defineLabel(buf, skipLabel)
  emitRet(buf)           # RET

  echo "   max function: ", buf

  # Test 11: Optimization example
  echo "\n11. Optimization Example:"
  buf = initBuffer()

  # Create a function with multiple jumps
  let startLabel = createLabel(buf)
  defineLabel(buf, startLabel)
  emitMovImmToReg(buf, RAX, 10)
  emitCmp(buf, RAX, RBX)
  let endLabel = createLabel(buf)
  emitJg(buf, endLabel)
  emitAddImm(buf, RAX, 1)
  emitJmp(buf, startLabel)
  defineLabel(buf, endLabel)
  emitRet(buf)

  echo "   Before optimization: ", buf
  let optimized = optimizeJumps(buf)
  echo "   After optimization: ", optimized

  echo "\n=== All tests completed successfully! ==="

when isMainModule:
  testAllInstructions()
