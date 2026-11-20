@studyCraft_List

**68. State the CAP theorem.**
---
A distributed data store cannot guarantee all three of **Consistency**, **Availability** and **Partition tolerance** at once. Because partitions happen, you choose between C and A when one occurs.
===
**69. What is the halting problem?**
---
The problem of deciding whether an arbitrary program halts on a given input. Alan Turing showed in 1936 that **no algorithm can solve it in general**: it is *undecidable*.
===
**70. What question does P vs NP ask?**
---
Whether every problem whose solution can be **verified** in polynomial time can also be **solved** in polynomial time. It is still unsolved (a Clay Millennium Prize problem).
===
**71. What is an NP-complete problem? Give an example.**
---
A problem in NP to which **every** problem in NP can be reduced in polynomial time. Examples: SAT, the decision version of the traveling salesman problem, graph coloring.
===
**72. What is amortized analysis?**
---
Analyzing the **average cost per operation over a sequence** of operations, even if single operations are expensive. Example: appending to a dynamic array is O(1) amortized, although an occasional resize costs O(n).
===
**73. How can a hash table handle collisions?**
---
**Chaining** (each bucket holds a list) or **open addressing** (probe for another free slot: linear, quadratic, double hashing). It resizes when the load factor gets too high.
===
**74. What is a B-tree, and why do databases use it?**
---
A balanced search tree with **many keys per node** (high fan-out), sized to disk pages. It needs very few disk reads (O(log n) with a tiny base) and supports range scans.
===
**75. What are Paxos and Raft?**
---
**Consensus algorithms**: they let a cluster of replicas agree on a sequence of values despite crashes and message loss. Raft (leader election plus log replication) was designed to be easier to understand.
===
**76. What is eventual consistency?**
---
Replicas may disagree for a while, but if updates stop they **converge to the same state**. It trades strict consistency for availability and latency (Dynamo, Cassandra).
===
**77. What are the SOLID principles?**
---
**S**ingle responsibility, **O**pen/closed, **L**iskov substitution, **I**nterface segregation, **D**ependency inversion.
===
**78. What is the difference between concurrency and parallelism?**
---
**Concurrency** is *dealing with* many tasks at once (interleaving them).

**Parallelism** is *doing* many tasks at the same instant on multiple cores.
===
**79. Why does memory locality matter for performance?**
---
CPUs fetch memory in **cache lines**. Data stored together (arrays) is read much faster than data scattered across the heap (linked lists), because a cache miss can cost about 100× a hit.
===
**80. What is the lambda calculus?**
---
A formal system built only from **function abstraction and application** (Alonzo Church). It is Turing-complete and the theoretical foundation of functional programming.
===
**81. What is a monad in functional programming?**
---
A type with **`return`** (wrap a value) and **`bind`/`flatMap`** (chain computations) that obey three laws. It sequences computations with context, e.g. `Optional`, `Promise`, `List`.
===
**82. What is the Church–Turing thesis?**
---
Everything that can be **effectively computed** can be computed by a Turing machine. It is a thesis, not a theorem, because “effectively computable” is informal.
===
**83. What is a context-free grammar, and what recognizes its languages?**
---
A grammar whose rules have a single non-terminal on the left (`A → α`). Its languages are recognized by **pushdown automata**. Programming-language syntax is usually specified this way.
===
**84. What is the difference between a DFA and an NFA?**
---
A **DFA** has exactly one transition per symbol; an **NFA** may have several (or ε-transitions). Both recognize exactly the **regular languages**; converting an NFA to a DFA can blow up the number of states exponentially.
===
**85. How does a TLS 1.3 handshake work (high level)?**
---
1. Client and server agree on parameters and exchange **ephemeral Diffie–Hellman** key shares (forward secrecy).
2. The server proves its identity with a **certificate** signed by a trusted CA.
3. Both derive symmetric keys and encrypt all further traffic (AEAD).

It takes just one round trip.
===
**86. What is a Merkle tree, and where is it used?**
---
A tree where every leaf is a data hash and every parent is the hash of its children. It allows **efficient integrity checks** of large data. Used in Git, Bitcoin and certificate transparency.
===
**87. Optimistic vs pessimistic concurrency control?**
---
**Pessimistic**: lock the data before use.

**Optimistic**: work without locks and check for conflicts at commit time (version numbers, compare-and-swap), retrying on conflict.
===
**88. Name the SQL isolation levels and the anomalies they prevent.**
---
**Read uncommitted** (allows dirty reads) → **Read committed** (no dirty reads) → **Repeatable read** (no non-repeatable reads) → **Serializable** (no phantoms).
===
**89. What is an LSM tree, and how does it differ from a B+ tree?**
---
An LSM tree **buffers writes in memory**, flushes them as sorted files, and merges (compacts) them in the background: very fast writes (RocksDB, Cassandra). A B+ tree updates pages in place: faster, more predictable reads.
===
**90. What is MapReduce?**
---
A model for distributed batch processing: **map** turns input into key-value pairs, a **shuffle** groups them by key, **reduce** aggregates each group (Hadoop).
===
**91. Round robin vs priority scheduling?**
---
**Round robin** gives each process a time slice in turn: fair and responsive.

**Priority scheduling** runs the highest priority first, which risks **starvation** of low-priority tasks (solved with aging).
===
**92. How does the LRU page replacement policy work?**
---
When memory is full, it evicts the **least recently used** page. True LRU is expensive, so systems approximate it (e.g. the clock algorithm).
===
**93. What is the difference between kernel mode and user mode, and what is a system call?**
---
The CPU runs OS code in privileged **kernel mode** and applications in restricted **user mode**. A **system call** is the controlled way for a program to ask the kernel for a service (read a file, open a socket).
===
**94. What is type inference?**
---
The compiler **deduces types** from context, so you get static type checking without writing every type (Haskell, Rust, Swift, TypeScript).
===
**95. What is Rust’s ownership model?**
---
Every value has a single **owner**. References are checked at compile time: either **one mutable** or **many shared** references. This gives memory safety **without a garbage collector**.
===
**96. How long does it take to build a heap from n elements?**
---
**O(n)** with bottom-up *heapify*, not O(n log n): most nodes are near the leaves and move only a short distance.
===
**97. What is the Master theorem for?**
---
It solves divide-and-conquer recurrences of the form **T(n) = a·T(n/b) + f(n)**. Example: merge sort has T(n) = 2T(n/2) + O(n), so **O(n log n)**.
===
**98. What is the Two Generals’ problem?**
---
It shows that two parties **cannot guarantee agreement over an unreliable channel**: any acknowledgment may be lost. It is why protocols such as TCP only reduce uncertainty.
===
**99. What is a Bloom filter?**
---
A compact, probabilistic set: **k hash functions** set bits in a bit array. It can give **false positives but never false negatives**, and uses very little memory.
===
**100. What is a zero-knowledge proof?**
---
A way to **prove that a statement is true without revealing anything else**. It must be complete, sound and reveal zero knowledge. Used in privacy-preserving authentication and blockchains.
