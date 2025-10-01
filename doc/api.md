# Nifasm x86_64 Assembler API Documentation

## Overview

Nifasm is a dependency-free x86_64 assembler that emits binary instruction bytes. It provides a clean, type-safe API for generating machine code without relying on external assemblers or text-based assembly syntax.

## Core Types

### Registers
```nim
type Register* = enum
  RAX = 0, RCX = 1, RDX = 2, RBX = 3, RSP = 4, RBP = 5, RSI = 6, RDI = 7,
  R8 = 8, R9 = 9, R10 = 10, R11 = 11, R12 = 12, R13 = 13, R14 = 14, R15 = 15
```

### Buffer
The `Buffer` type accumulates instruction bytes:
```nim
type Buffer* = object
  data*: seq[byte]

proc initBuffer*(): Buffer
proc add*(buf: var Buffer; b: byte)
proc `$`*(buf: Buffer): string  # Returns hex representation
```

## Instruction Categories

### 1. Data Movement Instructions

#### `emitMov(dest: var Buffer; a, b: Register)`
Moves data from register `b` to register `a`.
```nim
var buf = initBuffer()
emitMov(buf, RAX, RBX)  # MOV RAX, RBX
```

#### `emitMovImmToReg(dest: var Buffer; reg: Register; imm: int64)`
Moves a 64-bit immediate value to a register.
```nim
emitMovImmToReg(buf, RAX, 42)  # MOV RAX, 42
```

#### `emitMovImmToReg32(dest: var Buffer; reg: Register; imm: int32)`
Moves a 32-bit immediate value to a register (sign-extended to 64-bit).
```nim
emitMovImmToReg32(buf, RAX, 0x12345678)  # MOV RAX, 0x12345678
```

### 2. Arithmetic Instructions

#### `emitAdd(dest: var Buffer; a, b: Register)`
Adds register `b` to register `a`.
```nim
emitAdd(buf, RAX, RBX)  # ADD RAX, RBX
```

#### `emitSub(dest: var Buffer; a, b: Register)`
Subtracts register `b` from register `a`.
```nim
emitSub(buf, RAX, RBX)  # SUB RAX, RBX
```

#### `emitAddImm(dest: var Buffer; reg: Register; imm: int32)`
Adds an immediate value to a register.
```nim
emitAddImm(buf, RAX, 10)  # ADD RAX, 10
```

#### `emitSubImm(dest: var Buffer; reg: Register; imm: int32)`
Subtracts an immediate value from a register.
```nim
emitSubImm(buf, RAX, 5)  # SUB RAX, 5
```

#### `emitMul(dest: var Buffer; reg: Register)`
Unsigned multiply. Multiplies `RAX` by `reg`, result in `RAX:RDX`.
```nim
emitMul(buf, RBX)  # MUL RBX
```

#### `emitDiv(dest: var Buffer; reg: Register)`
Unsigned divide. Divides `RAX:RDX` by `reg`, quotient in `RAX`, remainder in `RDX`.
```nim
emitDiv(buf, RBX)  # DIV RBX
```

### 3. Bit Manipulation Instructions

#### `emitAnd(dest: var Buffer; a, b: Register)`
Bitwise AND of registers `a` and `b`.
```nim
emitAnd(buf, RAX, RBX)  # AND RAX, RBX
```

#### `emitOr(dest: var Buffer; a, b: Register)`
Bitwise OR of registers `a` and `b`.
```nim
emitOr(buf, RAX, RBX)  # OR RAX, RBX
```

#### `emitXor(dest: var Buffer; a, b: Register)`
Bitwise XOR of registers `a` and `b`.
```nim
emitXor(buf, RAX, RBX)  # XOR RAX, RBX
```

#### `emitNot(dest: var Buffer; reg: Register)`
Bitwise NOT of register.
```nim
emitNot(buf, RAX)  # NOT RAX
```

#### `emitShl(dest: var Buffer; reg: Register; count: int)`
Shift left by `count` bits.
```nim
emitShl(buf, RAX, 2)  # SHL RAX, 2
```

#### `emitShr(dest: var Buffer; reg: Register; count: int)`
Shift right by `count` bits.
```nim
emitShr(buf, RAX, 1)  # SHR RAX, 1
```

### 4. Control Flow Instructions

#### `emitRet(dest: var Buffer)`
Return from function.
```nim
emitRet(buf)  # RET
```

#### `emitCall(dest: var Buffer; target: int32)`
Relative call to `target` (32-bit signed offset).
```nim
emitCall(buf, 100)  # CALL +100
```

#### `emitJmp(dest: var Buffer; target: int32)`
Relative jump to `target` (32-bit signed offset).
```nim
emitJmp(buf, -50)  # JMP -50
```

#### `emitJmpReg(dest: var Buffer; reg: Register)`
Indirect jump to address in register.
```nim
emitJmpReg(buf, RAX)  # JMP RAX
```

#### Conditional Jumps
```nim
emitJe(buf, target)    # JE target   (jump if equal)
emitJne(buf, target)   # JNE target  (jump if not equal)
emitJg(buf, target)    # JG target   (jump if greater)
emitJl(buf, target)    # JL target   (jump if less)
```

### 5. Stack Operations

#### `emitPush(dest: var Buffer; reg: Register)`
Push register onto stack.
```nim
emitPush(buf, RAX)  # PUSH RAX
```

#### `emitPop(dest: var Buffer; reg: Register)`
Pop value from stack into register.
```nim
emitPop(buf, RAX)  # POP RAX
```

### 6. Comparison Instructions

#### `emitCmp(dest: var Buffer; a, b: Register)`
Compare registers `a` and `b`.
```nim
emitCmp(buf, RAX, RBX)  # CMP RAX, RBX
```

#### `emitTest(dest: var Buffer; a, b: Register)`
Test registers `a` and `b` (bitwise AND, sets flags).
```nim
emitTest(buf, RAX, RBX)  # TEST RAX, RBX
```

### 7. System Instructions

#### `emitSyscall(dest: var Buffer)`
System call.
```nim
emitSyscall(buf)  # SYSCALL
```

#### `emitInt(dest: var Buffer; vector: byte)`
Software interrupt.
```nim
emitInt(buf, 0x80)  # INT 0x80
```

### 8. NOP Instructions

#### `emitNop(dest: var Buffer)`
Single NOP instruction.
```nim
emitNop(buf)  # NOP
```

#### `emitNop(dest: var Buffer; length: int)`
NOP instruction of specified length (1-5 bytes, or multiple 1-byte NOPs).
```nim
emitNop(buf, 3)  # 3-byte NOP
```

## Example Usage

```nim
import nifasm

# Create a buffer
var buf = initBuffer()

# Assemble a simple function: add_two_numbers(a, b) -> a + b
emitMov(buf, RAX, RCX)  # MOV RAX, RCX (first argument)
emitAdd(buf, RAX, RDX)  # ADD RAX, RDX (add second argument)
emitRet(buf)           # RET (return result in RAX)

# Print the generated bytes
echo "Generated code: ", buf
# Output: Generated code: 48 89 C8 48 01 D0 C3
```

## Technical Details

### REX Prefix
The API automatically handles REX prefixes for:
- 64-bit operand size (W bit)
- Extended registers R8-R15 (R, X, B bits)

### ModR/M Encoding
The API automatically generates ModR/M bytes for register addressing modes.

### SIB Encoding
Complex addressing modes with index registers are supported through SIB byte encoding.

### Endianness
All immediate values and displacements are encoded in little-endian format as required by x86_64.

## Error Handling

The API is designed to be robust and will generate correct machine code for all supported instruction combinations. Invalid register combinations or unsupported addressing modes will be caught at compile time through Nim's type system.

## Performance

The API is designed for high performance with minimal overhead:
- No string parsing or text processing
- Direct byte generation
- Minimal memory allocations
- Type-safe compile-time checks
