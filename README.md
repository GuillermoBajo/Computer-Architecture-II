# Computer-Architecture-II

This repository is part of the **AOC2 course at the University of Zaragoza**. It focuses on implementing and testing a **memory hierarchy** for a custom **MIPS processor**. The work builds on the processor designed in Project 1, adding advanced memory structures like caches, scratch memory, and a semi-synchronous bus system. The main goal is to enhance performance, implement robust error handling, and verify functionality with various tests.

---

## Project Breakdown

### **Project 1: MIPS Processor**

- **Objective**: Design a basic MIPS processor.
- **Description**:
  - Implements the core functionality of a MIPS processor, including fetch, decode, and execute stages.
  - Features a simple memory interface as a starting point for later enhancements.
- **Outcome**: A functional MIPS processor to serve as the base for integrating a more advanced memory hierarchy in Project 2.

---

### **Project 2: Memory Hierarchy for MIPS**

- **Objective**: Design and implement an optimized memory hierarchy for the MIPS processor.
- **Components**:
  1. **Main Memory**:
     - **Classical Memory**: Standard memory for general use.
     - **Scratch Memory**: A smaller, faster memory for specific data-handling tasks.
  2. **2-Way Set Associative Cache**:
     - Features 4 sets with 2 blocks each, each block storing 4 words.
     - Utilizes a **FIFO replacement policy**, **write-through** for writes, and **fetch-on-write-miss** for missed writes.
  3. **IO_MASTER Peripheral**:
     - Handles system input/output by monitoring and storing inputs in the scratch memory.
  4. **Semi-Synchronous Bus**:
     - Connects the processor and memory components.
     - Arbitration ensures fair access to shared resources.
  5. **Controller State Machine**:
     - Manages cache operations like misses, block fetching, and writes.
     - Controls bus access and handles error scenarios effectively.
- **Error Handling**:
  - A dedicated state machine to detect and respond to issues like unaligned addresses or invalid memory access.

---

## Testing and Verification

### **Testing Process**

1. **Predefined Tests**:
   - Provided by the course materials to validate the functionality of the memory components.
2. **Integration Tests**:
   - Verifies the performance of the memory hierarchy within the MIPS processor.

### **Custom Test Programs**

1. **TestMC**:
   - A comprehensive test that validates:
     - Cache hits and misses.
     - Scratch memory access.
     - Set replacements and the use of all cache sets/ways.
     - Proper handling of errors (e.g., invalid addresses).
   - Combines memory operations with features from the original processor.
2. **sumaVectores**:
   - A real-world example program that adds two vectors.
   - Demonstrates the practical functionality and efficiency of the memory hierarchy.

### **Debugging with GTKWAVE**

- Waveform visualizations highlight signal activity and state transitions.
- Provides insights into key operations like cache hits/misses, bus requests, and error handling.

---

## Key Insights

- **Performance**: The memory hierarchy significantly enhances the efficiency of the MIPS processor through faster access times and reduced memory conflicts.
- **Robustness**: Comprehensive error handling ensures stability during invalid operations.
- **Practicality**: Custom tests demonstrate real-world applicability and the hierarchy’s ability to handle diverse scenarios effectively.
