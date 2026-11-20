@studyCraft_List

**35. What is the difference between stack and heap memory?**
---
**Stack**: automatic, fast, LIFO memory for function calls and local variables; small and fixed in size.

**Heap**: memory allocated dynamically at runtime; larger and flexible, but slower, and must be freed (manually or by a garbage collector).
===
**36. What is a pointer?**
---
A variable that stores the **memory address** of another value. It lets you share and modify data without copying it.
===
**37. What is garbage collection?**
---
Automatic reclaiming of memory that is no longer reachable by the program (Java, Go, C#). Swift and Python mostly use reference counting, with extra handling for cycles.
===
**38. What is polymorphism?**
---
The ability to use **one interface for different implementations**: a call such as `shape.area()` runs the right code for a circle or a square (overriding, interfaces, generics).
===
**39. Inheritance or composition: what is the difference?**
---
**Inheritance** models “is-a” and reuses code by subclassing.

**Composition** models “has-a” by building objects from other objects. Prefer composition: it is more flexible and less tightly coupled.
===
**40. What does ACID stand for in databases?**
---
**A**tomicity (all or nothing), **C**onsistency (valid state to valid state), **I**solation (concurrent transactions don’t interfere), **D**urability (committed data survives crashes).
===
**41. What is database normalization?**
---
Structuring tables to **reduce redundancy** and avoid update anomalies (1NF, 2NF, 3NF…) by splitting data into related tables.
===
**42. What is the difference between INNER JOIN and LEFT JOIN?**
---
**INNER JOIN**: only rows that match in both tables.

**LEFT JOIN**: all rows of the left table, plus matches from the right (NULL where there is none).
===
**43. What is a database index, and what is the trade-off?**
---
An extra structure (often a B-tree) that makes lookups and sorting **much faster**. The cost: more storage and **slower writes**, because the index must be updated.
===
**44. What are the layers of the TCP/IP model?**
---
**Link**, **Internet** (IP), **Transport** (TCP/UDP), **Application** (HTTP, DNS…). The OSI model splits it into 7 layers.
===
**45. What is the difference between TCP and UDP?**
---
**TCP**: connection-oriented, reliable, ordered, with congestion control.

**UDP**: connectionless, no delivery guarantee, low latency (streaming, games, DNS).
===
**46. What happens when you type a URL into a browser and press Enter?**
---
1. DNS resolves the name to an IP address
2. A TCP connection (and TLS handshake for HTTPS) is opened
3. The browser sends an HTTP request
4. The server responds with HTML
5. The browser parses it and loads CSS, JS and images, then renders the page
===
**47. What is a deadlock, and what conditions cause it?**
---
Several threads wait forever for each other’s resources. It requires all four **Coffman conditions**: mutual exclusion, hold and wait, no preemption, circular wait.
===
**48. What is a race condition?**
---
A bug where the result depends on the **unpredictable timing** of concurrent accesses to shared data. Fix it with locks, atomic operations or immutable data.
===
**49. What is the difference between a mutex and a semaphore?**
---
A **mutex** is a lock owned by one thread at a time (mutual exclusion).

A **semaphore** is a counter that allows up to N threads in, or is used to signal between threads.
===
**50. What is virtual memory?**
---
An abstraction that gives each process its **own address space**. The OS maps virtual pages to physical RAM (and can swap pages to disk), which gives isolation and more usable memory.
===
**51. What is the time complexity of quicksort?**
---
**O(n log n) on average**, **O(n²) in the worst case** (consistently bad pivots). It sorts in place and is usually fast in practice.
===
**52. What are the properties of merge sort?**
---
**O(n log n) always**, **stable**, but needs **O(n) extra space**. It divides the array, sorts the halves and merges them.
===
**53. What is the difference between BFS and DFS?**
---
**BFS** explores level by level using a **queue**; it finds shortest paths in unweighted graphs.

**DFS** goes as deep as possible using a **stack/recursion**; it is used for cycle detection and topological sort.
===
**54. What is a binary search tree, and what is its weakness?**
---
A binary tree where **left < node < right**. Operations are O(log n) on average but degrade to **O(n)** if the tree becomes unbalanced; AVL and red-black trees stay balanced.
===
**55. What is a heap (priority queue)?**
---
A complete binary tree where every parent is ≤ (min-heap) or ≥ (max-heap) its children. Insert and remove-min are **O(log n)**, peek is O(1). Used in heapsort and Dijkstra.
===
**56. What is dynamic programming?**
---
Solving a problem by splitting it into **overlapping subproblems** and storing their results (memoization or a table) to avoid recomputation. Examples: Fibonacci, knapsack, edit distance.
===
**57. What does Dijkstra’s algorithm do, and what is its limitation?**
---
It finds **shortest paths from one source** in a weighted graph. With a heap it runs in O((V+E) log V). It **fails with negative edge weights** (use Bellman–Ford).
===
**58. What is a greedy algorithm?**
---
One that always takes the **locally best choice**. It is correct only if the problem has the greedy-choice property, e.g. Huffman coding, Kruskal and Prim.
===
**59. What is public-key cryptography?**
---
Each party has a **public key** (shared) and a **private key** (secret). Encrypt with the public key, decrypt with the private key; sign with the private key, verify with the public key (RSA, ECC).
===
**60. What properties should a cryptographic hash function have?**
---
Deterministic, fast, **pre-image resistant** (can’t invert), **collision resistant**, and an **avalanche effect** (a tiny change in input changes the whole output).
===
**61. What is the difference between symmetric and asymmetric encryption?**
---
**Symmetric** (AES): one shared key; fast.

**Asymmetric** (RSA, ECC): key pair; slower, but no secret exchange needed. TLS combines them.
===
**62. What is SQL injection, and how do you prevent it?**
---
Attacker-controlled input changes the meaning of a query. Prevent it with **parameterized queries / prepared statements**, input validation and least-privilege database accounts.
===
**63. What is REST?**
---
An architectural style for web APIs: **resources** have URLs, requests are **stateless**, and standard HTTP methods are used (GET, POST, PUT, DELETE).
===
**64. What is the difference between Big-O, Big-Omega and Big-Theta?**
---
**O**: upper bound. **Ω**: lower bound. **Θ**: tight bound (both).
===
**65. What is a JIT compiler?**
---
A **just-in-time** compiler translates bytecode to machine code **while the program runs**, optimizing hot code paths (JVM, JavaScript engines).
===
**66. What is a design pattern? Name three.**
---
A reusable solution to a common design problem. Examples: **Singleton**, **Observer**, **Factory**, **Strategy**, **Decorator**.
===
**67. What is the difference between unit, integration and end-to-end tests?**
---
**Unit**: one function or class in isolation.

**Integration**: several components together.

**End-to-end**: the whole system as a user would use it.
