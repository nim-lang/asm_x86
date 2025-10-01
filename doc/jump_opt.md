# Jump Optimization in Nifasm

## Overview

Nifasm includes automatic jump optimization that reduces the size of generated machine code by using the smallest possible jump instruction encoding. This postprocessing step analyzes all jump instructions and optimizes them to use 8-bit displacements when possible, instead of the default 32-bit displacements.

## How It Works

### 1. Jump Tracking

When you emit jump instructions, Nifasm automatically tracks them in the buffer:

```nim
var buf = initBuffer()
emitJmp(buf, target)    # Tracks this jump for optimization
emitJe(buf, target)     # Tracks this conditional jump
```

### 2. Automatic Optimization

Call `finalize()` on your buffer to optimize all jumps:

```nim
buf.finalize()  # Optimizes all tracked jumps
```

### 3. Size Reduction

- **32-bit jumps**: 5-6 bytes (opcode + 4-byte displacement)
- **8-bit jumps**: 2 bytes (opcode + 1-byte displacement)
- **Savings**: Up to 3-4 bytes per optimized jump

## Supported Jump Instructions

### Unconditional Jumps
- `emitJmp(target)` - Relative jump
- `emitJmpReg(reg)` - Indirect jump (not optimized)

### Conditional Jumps (All Support Optimization)
- `emitJe(target)` - Jump if equal
- `emitJne(target)` - Jump if not equal
- `emitJg(target)` - Jump if greater
- `emitJl(target)` - Jump if less
- `emitJge(target)` - Jump if greater or equal
- `emitJle(target)` - Jump if less or equal
- `emitJa(target)` - Jump if above (unsigned)
- `emitJb(target)` - Jump if below (unsigned)
- `emitJae(target)` - Jump if above or equal (unsigned)
- `emitJbe(target)` - Jump if below or equal (unsigned)

### Function Calls
- `emitCall(target)` - Relative call (not optimized, as CALL doesn't have 8-bit form)

## Optimization Criteria

A jump is optimized to 8-bit form if:
1. The distance is between -128 and +127 bytes
2. The jump instruction supports 8-bit encoding

## Example Usage

```nim
import nifasm

var buf = initBuffer()

# Create a short jump (will be optimized)
emitJmp(buf, 5)      # Jump forward 5 bytes
emitNop(buf, 3)      # Some padding
emitRet(buf)         # Target instruction

echo "Before optimization: ", buf
echo "Length: ", buf.len, " bytes"

# Optimize all jumps
buf.finalize()

echo "After optimization: ", buf
echo "Length: ", buf.len, " bytes"
```

## Performance Benefits

### Code Size Reduction
- **Small functions**: 20-40% size reduction
- **Tight loops**: Significant savings on conditional jumps
- **Dense code**: Multiple short jumps can save substantial space

### Runtime Performance
- **Cache efficiency**: Smaller code fits better in instruction cache
- **Branch prediction**: Shorter jumps may have better prediction
- **Memory bandwidth**: Less code to load from memory

## Technical Details

### Jump Distance Calculation
```nim
distance = target_position - (jump_position + 1)
```

### 8-bit Jump Opcodes
- `JMP rel8`: `0xEB`
- `JE rel8`: `0x74`
- `JNE rel8`: `0x75`
- `JG rel8`: `0x7F`
- `JL rel8`: `0x7C`
- `JGE rel8`: `0x7D`
- `JLE rel8`: `0x7E`
- `JA rel8`: `0x77`
- `JB rel8`: `0x72`
- `JAE rel8`: `0x73`
- `JBE rel8`: `0x76`

### Buffer Management
When a jump is optimized from 32-bit to 8-bit:
1. The opcode is replaced with the 8-bit version
2. The displacement is updated to 8-bit
3. Excess bytes are removed by shifting the remaining data
4. The buffer length is updated

## Best Practices

### 1. Always Call finalize()
```nim
var buf = initBuffer()
# ... emit instructions ...
buf.finalize()  # Don't forget this!
```

### 2. Design for Short Jumps
- Keep related code blocks close together
- Use short conditional branches for tight loops
- Consider code layout for optimization opportunities

### 3. Monitor Optimization Results
```nim
let originalLength = buf.len
buf.finalize()
let optimizedLength = buf.len
echo "Saved ", originalLength - optimizedLength, " bytes"
```

## Limitations

### Unsupported Optimizations
- **CALL instructions**: No 8-bit form available
- **Indirect jumps**: `emitJmpReg()` cannot be optimized
- **Very long jumps**: Distances > 127 bytes cannot use 8-bit form

### Distance Limitations
- **Forward jumps**: Must be ≤ 127 bytes
- **Backward jumps**: Must be ≥ -128 bytes
- **Cross-function jumps**: Often too far for optimization

## Advanced Usage

### Manual Optimization Control
```nim
# Check if a jump can be optimized
let distance = calculateJumpDistance(fromPos, toPos)
if canUseShortJump(distance):
  echo "This jump can be optimized"
```

### Custom Jump Tracking
```nim
# Manually add jump entries (advanced usage)
buf.addJump(position, target, jtJmp, 5)
```

## Integration with Existing Code

The jump optimization is designed to be:
- **Transparent**: Existing code works without changes
- **Automatic**: No manual intervention required
- **Safe**: Never changes jump semantics, only encoding
- **Efficient**: Minimal overhead during assembly

Simply add `buf.finalize()` after emitting all instructions to get automatic optimization.
