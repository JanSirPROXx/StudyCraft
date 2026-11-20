@studyCraft_List

**1. What is an algorithm?**
---
A finite, well-defined sequence of steps that solves a problem or performs a computation.
===
**2. What is the difference between a compiler and an interpreter?**
---
A **compiler** translates the whole program into machine code (or bytecode) *before* it runs.

An **interpreter** executes the source code step by step *while* it runs.
===
**3. What is a variable?**
---
A named location in memory that holds a value, which can change while the program runs.
===
**4. What is the difference between an array and a linked list?**
---
| | Array | Linked list |
|---|---|---|
| Memory | contiguous | nodes linked by pointers |
| Access by index | O(1) | O(n) |
| Insert/remove in the middle | O(n) | O(1) if you hold the node |
===
**5. What does Big-O notation describe?**
---
How the running time (or memory use) of an algorithm **grows with the input size n**, ignoring constant factors. It states an upper bound, e.g. O(n²).
===
**6. What is the time complexity of binary search, and what must be true of the data?**
---
**O(log n)**. The data must be **sorted** (and allow random access), because each step halves the search range.
===
**7. What is a stack?**
---
A collection with **LIFO** order (last in, first out): you `push` and `pop` at the top.

Used for the call stack, undo, and expression parsing.
===
**8. What is a queue?**
---
A collection with **FIFO** order (first in, first out): you enqueue at the back and dequeue at the front.

Used for scheduling and breadth-first search.
===
**9. Why do computers use binary?**
---
Digital circuits have two reliable states (on/off, high/low voltage), which map directly to the digits 0 and 1. Binary is simple and robust to noise.
===
**10. How many bits are in a byte, and how many different values can it hold?**
---
**8 bits**, so 2⁸ = **256** values (0–255).
===
**11. What is the difference between RAM and disk storage?**
---
**RAM** is fast, working memory that is lost when power is off (volatile).

**Disk/SSD** is slower but keeps data permanently (persistent).
===
**12. What does an operating system do?**
---
It manages hardware and resources (CPU time, memory, files, devices) and gives programs a safe, uniform way to use them.
===
**13. What is the difference between a process and a thread?**
---
A **process** is a running program with its own address space.

**Threads** are execution paths inside a process and share its memory.
===
**14. What is a function, and why do we use them?**
---
A named, reusable block of code that can take inputs and return a result. Functions avoid repetition and let us build programs from small, testable pieces (abstraction).
===
**15. What is recursion?**
---
When a function calls **itself** on a smaller version of the problem. It needs a **base case** to stop.

```python
def factorial(n):
    if n <= 1:      # base case
        return 1
    return n * factorial(n - 1)
```
===
**16. What is an IP address?**
---
A numeric label that identifies a device on a network. IPv4 uses 32 bits (e.g. `192.168.0.1`), IPv6 uses 128 bits.
===
**17. What does DNS do?**
---
The Domain Name System **translates domain names** like `example.com` **into IP addresses**.
===
**18. What is HTTP, and what does HTTPS add?**
---
HTTP is the request/response protocol of the web. **HTTPS** adds **TLS encryption** and server authentication, so others cannot read or tamper with the traffic.
===
**19. What is a database?**
---
An organized collection of data managed by a database system, which supports querying, updating, concurrent access and durability.
===
**20. What does SQL stand for, and what is it used for?**
---
**Structured Query Language**: it is used to query and change data in relational databases.

```sql
SELECT name FROM users WHERE age > 30;
```
===
**21. What is a primary key?**
---
A column (or set of columns) that **uniquely identifies each row** of a table. It cannot be NULL.
===
**22. What is Git?**
---
A **distributed version control system** that records the history of changes to files and lets many people work on the same project through branches and merges.
===
**23. What is a bug, and what is debugging?**
---
A **bug** is a defect that makes a program behave incorrectly. **Debugging** is finding and fixing it (with logs, breakpoints, tests).
===
**24. What is the difference between `=` and `==` in C-like languages?**
---
`=` **assigns** a value; `==` **compares** two values for equality.

```c
x = 5;      // assign
if (x == 5) // compare
```
===
**25. What is a hash table?**
---
A data structure that maps keys to values: a **hash function** turns the key into an index. Lookup, insert and delete are **O(1) on average**.
===
**26. What is an API?**
---
An **Application Programming Interface**: a defined contract (functions, endpoints, data formats) through which software components talk to each other.
===
**27. What is the difference between a syntax error, a runtime error and a logic error?**
---
- **Syntax error**: breaks the language’s grammar; caught before running.
- **Runtime error**: crashes while running (e.g. division by zero).
- **Logic error**: runs without crashing but gives the wrong result.
===
**28. What is object-oriented programming?**
---
A paradigm that organizes code into **objects** combining data and behavior. Its pillars: encapsulation, abstraction, inheritance, polymorphism.
===
**29. What is the fetch–decode–execute cycle?**
---
The basic loop of a CPU: **fetch** the next instruction from memory, **decode** what it means, **execute** it, and repeat.
===
**30. What do AND, OR and NOT do in Boolean logic?**
---
- **AND**: true only if both inputs are true
- **OR**: true if at least one input is true
- **NOT**: flips true and false
===
**31. What is open-source software?**
---
Software whose source code is available under a licence that allows anyone to use, study, modify and share it (e.g. Linux, Git).
===
**32. What is cloud computing?**
---
Using computing resources (servers, storage, databases) **on demand over the internet**, usually paying only for what you use, instead of running your own hardware.
===
**33. Name two simple O(n²) sorting algorithms and two O(n log n) ones.**
---
**O(n²)**: bubble sort, insertion sort, selection sort.

**O(n log n)**: merge sort, quicksort (on average), heapsort.
===
**34. What is the difference between ASCII and Unicode?**
---
**ASCII** encodes 128 characters in 7 bits (English letters, digits, symbols).

**Unicode** is a universal character set with over 140,000 characters; **UTF-8** encodes it in 1–4 bytes and is backward compatible with ASCII.
