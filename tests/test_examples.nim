# Test examples for Nifasm x86_64 assembler

import "../src/asm_x86"

# Test basic MOV instructions
proc testMovInstructions() =
  echo "Testing MOV instructions..."

  var buf = initBuffer()

  # MOV RAX, RBX
  emitMov(buf, RAX, RBX)
  echo "MOV RAX, RBX: ", buf

  buf = initBuffer()
  # MOV RAX, 42
  emitMovImmToReg(buf, RAX, 42)
  echo "MOV RAX, 42: ", buf

  buf = initBuffer()
  # MOV RAX, 0x12345678 (32-bit immediate)
  emitMovImmToReg32(buf, RAX, 0x12345678)
  echo "MOV RAX, 0x12345678: ", buf

  buf = initBuffer()
  # MOV R8, R9 (extended registers)
  emitMov(buf, R8, R9)
  echo "MOV R8, R9: ", buf

  buf = initBuffer()
  # MOV R15, 0x123456789ABCDEF0
  emitMovImmToReg(buf, R15, 0x123456789ABCDEF0)
  echo "MOV R15, 0x123456789ABCDEF0: ", buf

# Test arithmetic instructions
proc testArithmeticInstructions() =
  echo "\nTesting arithmetic instructions..."

  var buf = initBuffer()

  # ADD RAX, RBX
  emitAdd(buf, RAX, RBX)
  echo "ADD RAX, RBX: ", buf

  buf = initBuffer()
  # SUB RCX, RDX
  emitSub(buf, RCX, RDX)
  echo "SUB RCX, RDX: ", buf

  buf = initBuffer()
  # ADD R8, R9 (extended registers)
  emitAdd(buf, R8, R9)
  echo "ADD R8, R9: ", buf

# Test bit manipulation instructions
proc testBitManipulationInstructions() =
  echo "\nTesting bit manipulation instructions..."

  var buf = initBuffer()

  # AND RAX, RBX
  emitAnd(buf, RAX, RBX)
  echo "AND RAX, RBX: ", buf

  buf = initBuffer()
  # OR RCX, RDX
  emitOr(buf, RCX, RDX)
  echo "OR RCX, RDX: ", buf

  buf = initBuffer()
  # XOR R8, R9
  emitXor(buf, R8, R9)
  echo "XOR R8, R9: ", buf

# Test control flow instructions
proc testControlFlowInstructions() =
  echo "\nTesting control flow instructions..."

  var buf = initBuffer()

  # RET
  emitRet(buf)
  echo "RET: ", buf

  buf = initBuffer()
  # CALL +100 (relative call)
  emitCall(buf, 100)
  echo "CALL +100: ", buf

  buf = initBuffer()
  # JMP -50 (relative jump)
  emitJmp(buf, -50)
  echo "JMP -50: ", buf

# Test system instructions
proc testSystemInstructions() =
  echo "\nTesting system instructions..."

  var buf = initBuffer()

  # SYSCALL
  emitSyscall(buf)
  echo "SYSCALL: ", buf

  buf = initBuffer()
  # NOP
  emitNop(buf)
  echo "NOP: ", buf

# Test a complete function
proc testCompleteFunction() =
  echo "\nTesting complete function assembly..."

  var buf = initBuffer()

  # Function: add_two_numbers(a, b) -> a + b
  # Entry point
  emitMov(buf, RAX, RCX)  # MOV RAX, RCX (move first argument)
  emitAdd(buf, RAX, RDX)  # ADD RAX, RDX (add second argument)
  emitRet(buf)           # RET (return result in RAX)

  echo "Complete function (add_two_numbers): ", buf

# Run all tests
when isMainModule:
  testMovInstructions()
  testArithmeticInstructions()
  testBitManipulationInstructions()
  testControlFlowInstructions()
  testSystemInstructions()
  testCompleteFunction()

  echo "\nAll tests completed!"
