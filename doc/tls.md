# Thread Local Storage (TLS) Support in Nifasm

## Overview

Nifasm now provides comprehensive support for Thread Local Storage (TLS), allowing you to create and access thread-local variables that are unique to each thread in your application. This is essential for writing thread-safe code and implementing per-thread state.

## Key Features

### ✅ **Complete TLS Support**
- **TLS Symbol Management**: Define thread-local variables with string names
- **Multiple TLS Models**: Support for all x86_64 TLS access models (GD, LD, IE, LE)
- **TLS Sections**: Automatic .tdata and .tbss section management
- **TLS Relocations**: Proper relocation entries for linking
- **Runtime Integration**: Generated code works with standard TLS runtime

### ✅ **TLS Access Models**
- **General Dynamic (GD)**: For external TLS variables
- **Local Dynamic (LD)**: For local TLS variables in the same module
- **Initial Exec (IE)**: For TLS variables loaded at program startup
- **Local Exec (LE)**: For TLS variables with known offsets

## API Reference

### TLS Symbol Management

```nim
# Add TLS block (container for TLS variables)
buf.addTlsBlock("my_tls_block", alignment=8)

# Add TLS variables
buf.addTlsSymbol("tls_counter", size=8, alignment=8, sbGlobal, true)
buf.addTlsSymbol("tls_buffer", size=1024, alignment=8, sbGlobal, true)
buf.addTlsSymbol("tls_flag", size=1, alignment=1, sbLocal, true)

# Check TLS symbols
if buf.hasTlsSymbol("tls_counter"):
  let sym = buf.getTlsSymbol("tls_counter")
```

### TLS Access Instructions

```nim
# Access TLS variable using specific model
buf.emitTlsAccess("tls_counter", RAX, tmGeneralDynamic)
buf.emitTlsAccess("tls_buffer", RBX, tmLocalExec)

# Individual TLS access functions
buf.emitTlsGdCall("external_tls_var")         # General Dynamic
buf.emitTlsLdCall()                           # Local Dynamic
buf.emitTlsIeAccess("local_tls_var", RAX)     # Initial Exec
buf.emitTlsLeAccess("known_tls_var", RAX)     # Local Exec
```

### TLS Models

```nim
# TLS model enumeration
TlsModel = enum
  tmGeneralDynamic  # GD - General Dynamic model (slowest, most flexible)
  tmLocalDynamic    # LD - Local Dynamic model (faster for same module)
  tmInitialExec     # IE - Initial Exec model (faster, program startup)
  tmLocalExec       # LE - Local Exec model (fastest, known offsets)
```

## Complete Examples

### Example 1: Basic TLS Variables

```nim
import nifasm
import std/streams

var buf = initBuffer()

# Define TLS variables
buf.addTlsSymbol("thread_id", 8, 8, sbGlobal, true)      # 8-byte thread ID
buf.addTlsSymbol("thread_buffer", 256, 8, sbGlobal, true) # 256-byte buffer
buf.addTlsSymbol("thread_flag", 1, 1, sbLocal, true)     # 1-byte flag

# Function that accesses TLS variables
buf.defineFunction("access_tls") do (buf: var Buffer):
  # Get thread ID (General Dynamic model)
  buf.emitTlsAccess("thread_id", RAX, tmGeneralDynamic)

  # Set flag (Local Exec model - fastest)
  buf.emitTlsAccess("thread_flag", RBX, tmLocalExec)
  buf.emitMovImmToReg(buf, RCX, 1)
  buf.emitMov(buf, RBX, RCX)  # Set flag to 1

  buf.emitRet()

# Generate object file
let objectFile = buf.generateObjectFile()
let file = newFileStream("tls_example.o", fmWrite)
for b in objectFile:
  file.write(b)
file.close()
```

### Example 2: TLS Counter

```nim
import nifasm

var buf = initBuffer()

# Define TLS counter
buf.addTlsSymbol("thread_counter", 8, 8, sbGlobal, true)

# Function to increment TLS counter
buf.defineFunction("increment_counter") do (buf: var Buffer):
  # Load TLS counter address
  buf.emitTlsAccess("thread_counter", RAX, tmGeneralDynamic)

  # Load current value
  buf.emitMov(buf, RBX, RAX)  # RBX = address of counter
  # Note: In real usage, you'd emit MOV RBX, [RAX] to load the value

  # Increment counter
  buf.emitAdd(buf, RBX, 1)

  # Store back (in real usage: MOV [RAX], RBX)
  buf.emitMov(buf, RAX, RBX)

  buf.emitRet()
```

### Example 3: Multiple TLS Models

```nim
import nifasm

var buf = initBuffer()

# Define different types of TLS variables
buf.addTlsSymbol("external_var", 8, 8, sbGlobal, false)  # External
buf.addTlsSymbol("local_var", 8, 8, sbGlobal, true)     # Local
buf.addTlsSymbol("fast_var", 8, 8, sbLocal, true)       # Fast access

# Functions using different TLS models
buf.defineFunction("access_external") do (buf: var Buffer):
  # External TLS variable - use General Dynamic
  buf.emitTlsAccess("external_var", RAX, tmGeneralDynamic)
  buf.emitRet()

buf.defineFunction("access_local") do (buf: var Buffer):
  # Local TLS variable - use Initial Exec
  buf.emitTlsAccess("local_var", RAX, tmInitialExec)
  buf.emitRet()

buf.defineFunction("access_fast") do (buf: var Buffer):
  # Fast TLS variable - use Local Exec
  buf.emitTlsAccess("fast_var", RAX, tmLocalExec)
  buf.emitRet()
```

## TLS Models Explained

### 1. General Dynamic (GD) - `tmGeneralDynamic`
- **Use case**: TLS variables that may be defined in other shared libraries
- **Speed**: Slowest (requires runtime lookup)
- **Flexibility**: Most flexible, works with any TLS variable
- **Generated code**: Calls `__tls_get_addr()` with GOT entries

```nim
buf.emitTlsAccess("external_tls_var", RAX, tmGeneralDynamic)
```

### 2. Local Dynamic (LD) - `tmLocalDynamic`
- **Use case**: TLS variables defined in the same module
- **Speed**: Faster than GD (shared module lookup)
- **Flexibility**: Works with module-local TLS variables
- **Generated code**: Calls `__tls_get_addr()` once per module

```nim
buf.emitTlsAccess("module_tls_var", RAX, tmLocalDynamic)
```

### 3. Initial Exec (IE) - `tmInitialExec`
- **Use case**: TLS variables in executables or libraries loaded at startup
- **Speed**: Fast (direct memory access with offset)
- **Flexibility**: Limited to startup-time TLS allocation
- **Generated code**: Direct access through GOT with known offset

```nim
buf.emitTlsAccess("startup_tls_var", RAX, tmInitialExec)
```

### 4. Local Exec (LE) - `tmLocalExec`
- **Use case**: TLS variables in the main executable
- **Speed**: Fastest (direct access with known offset)
- **Flexibility**: Only for main executable TLS
- **Generated code**: Direct access using GS segment register

```nim
buf.emitTlsAccess("main_tls_var", RAX, tmLocalExec)
```

## TLS Sections

When you use TLS, the following sections are automatically created:

### .tdata Section
- Contains initialized TLS data
- Copied to each thread's TLS block at thread creation
- Similar to .data section but for thread-local variables

### .tbss Section
- Contains uninitialized TLS data
- Zero-initialized for each thread
- Similar to .bss section but for thread-local variables

## Runtime Integration

### Linking
```bash
# Link TLS-enabled object files
gcc tls_program.o -o tls_program

# The linker automatically handles TLS sections and relocations
```

### Runtime Behavior
- Each thread gets its own copy of TLS variables
- TLS variables are automatically initialized when threads are created
- TLS variables are automatically cleaned up when threads exit

## Performance Considerations

### TLS Model Performance (fastest to slowest)
1. **Local Exec (LE)** - Direct GS-segment access
2. **Initial Exec (IE)** - Single memory indirection
3. **Local Dynamic (LD)** - Function call + offset calculation
4. **General Dynamic (GD)** - Function call + full lookup

### Best Practices
- Use **Local Exec** for main executable TLS variables
- Use **Initial Exec** for library TLS variables loaded at startup
- Use **Local Dynamic** for module-local TLS variables
- Use **General Dynamic** only when necessary for external TLS

## Advanced Features

### TLS with Function Calls

```nim
var buf = initBuffer()

buf.addTlsSymbol("error_code", 4, 4, sbGlobal, true)

buf.defineFunction("set_error") do (buf: var Buffer):
  # Set thread-local error code
  buf.emitTlsAccess("error_code", RAX, tmLocalExec)
  buf.emitMovImmToReg(buf, RBX, 42)  # Error code 42
  buf.emitMov(buf, RAX, RBX)
  buf.emitRet()

buf.defineFunction("get_error") do (buf: var Buffer):
  # Get thread-local error code
  buf.emitTlsAccess("error_code", RAX, tmLocalExec)
  # Return value already in RAX
  buf.emitRet()
```

### TLS with Data Structures

```nim
var buf = initBuffer()

# Define TLS structure (simplified)
buf.addTlsSymbol("thread_context", 64, 8, sbGlobal, true)  # 64-byte structure

buf.defineFunction("init_context") do (buf: var Buffer):
  # Get pointer to thread context
  buf.emitTlsAccess("thread_context", RAX, tmInitialExec)

  # Initialize structure fields (simplified)
  buf.emitMovImmToReg(buf, RBX, 0x12345678)
  buf.emitMov(buf, RAX, RBX)  # context.field1 = value

  buf.emitRet()
```

## Debugging TLS

### View TLS Sections
```bash
# View TLS sections in object file
objdump -h myfile.o | grep -E '\.(tdata|tbss)'

# View TLS symbols
objdump -t myfile.o | grep TLS

# View TLS relocations
objdump -r myfile.o | grep TLS
```

### Common Issues
1. **Missing TLS runtime**: Ensure your system supports TLS
2. **Wrong TLS model**: Choose appropriate model for your use case
3. **Alignment issues**: Use proper alignment for TLS variables
4. **Relocation errors**: Ensure proper symbol definitions

## Integration with C/C++

TLS variables generated by Nifasm are compatible with C/C++ TLS:

### C Code
```c
// In C
extern __thread int nifasm_tls_var;

void access_nifasm_tls() {
    nifasm_tls_var = 42;
}
```

### Linking
```bash
gcc nifasm_tls.o c_code.o -o mixed_program
```

The TLS support in Nifasm provides a complete solution for thread-local storage that integrates seamlessly with existing C/C++ codebases and standard threading libraries.
