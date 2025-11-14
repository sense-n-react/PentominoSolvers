# Pentomino Solvers in Various Programming Languages

Solve the **Pentomino puzzle** — a classic **tiling and combinatorial problem** — implemented in **20+ programming languages**, including Ruby, Python, C, C++, Go, Rust, JavaScript, and more.

This repository provides a collection of **Pentomino solver algorithms** written in different programming languages to demonstrate differences in syntax, performance, and algorithmic approach.  
It is ideal for learners who want to compare how the same logic is expressed across multiple languages, and for developers interested in puzzle-solving algorithms and optimization techniques.

> 🧩 The Pentomino puzzle consists of twelve unique pentomino pieces, each made of five connected squares.  
> The challenge is to fill a rectangular board using all pieces without overlap — a great problem for exploring recursion, backtracking, and constraint-solving algorithms.

---
## Table of Contents
- [How to Run Programs](#how-to-run-programs)
- [Languages Implemented](#languages-implemented)
- [Solver Algorithm](#solver-algorithm)
- [Processing Time](#processing-time)
- [License](#license)

---

## How to Run Programs

### Execute solver.xx
```bash
$ ruby solver.rb           # Ruby
$ python3 solver.py        # Python

$ gcc -o solver.c.out solver.c    # Compile C program
$ ./solver.c.out                  # Run the compiled executable
```


### Using run-solver script
```bash
$ ./run-solver rb py        # Specify one or more extensions
# or
$ ./run-solver ruby python  # Specify one or more languages
```

### Run all programs
```bash
$ ./run-solver --all
```

##  Languages Implemented

| | | | | |
| :---:      | :---:      | :---:  | :---:    | :---: |
| Ruby       | Python     | Lua    | Squirrel | Julia |
| JavaScript | TypeScript | Groovy | Perl     | AWK   |
| PHP        | C          | C++    | C#       | Java  |
| Kotlin     | Go         | Rust   | Swift    | LISP  |
| Crystal    | Elixir     | F#     | D        | Dart  |
| Zig        | Nim        | Pascal | Bash     |       |

> More languages may be added over time.

## Solver Algorithm

All solvers use the same core algorithmic strategy based on recursive backtracking to explore all possible board placements of the 12 pentomino pieces.

For a detailed explanation of the algorithm, implementation structure, and optimization ideas, see  
👉 [ALGORITHM.md](ALGORITHM.md)


## Processing Time

![Processing Time](https://github.com/sense-n-react/PentominoSolvers/blob/images/images/time-6x10.png)

## Learning Objectives
This project is designed to:
- Compare syntax and style differences across programming languages
- Explore recursion, constraint satisfaction, and backtracking algorithms
- Measure relative performance between compilers and interpreters
- Serve as a study reference for students learning algorithm design

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).


## About

**PentominoSolvers**  
A multi-language collection of Pentomino puzzle solvers for algorithm comparison and educational purposes.  
Created and maintained by [sense-n-react](https://github.com/sense-n-react).
