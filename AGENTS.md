# Model Checking of Formal Methods

## Project Overview

This project explores formal verification techniques for modeling and verifying system behavior. The project uses various formal methods tools to ensure correctness of system specifications through:

- **Structural modeling**: Defining system entities, relationships, and invariants
- **Behavioral modeling**: Specifying state transitions and temporal properties
- **Automated verification**: Using model checkers to find violations and prove correctness

Current implementations include temporal logic verification and state consistency checking using Alloy6.

## AI Agent Instructions

### General Formal Methods Competencies

When working with this project, AI agents should have expertise in:

1. **Formal Specification Languages**
   - First-order logic and predicate calculus
   - Set theory and relational algebra
   - Type systems and invariants

2. **Temporal Logic**
   - Linear Temporal Logic (LTL): `always`, `eventually`, `next`
   - Computation Tree Logic (CTL): branching time logic
   - State transition systems and traces
   - Safety and liveness properties

3. **Model Checking Techniques**
   - Bounded model checking
   - Satisfiability checking (SAT/SMT solvers)
   - Counterexample-guided refinement
   - State space exploration strategies

---

## Tool-Specific Instructions

### Alloy6

Alloy6 is a declarative specification language based on first-order relational logic with transitive closure. It includes built-in support for temporal logic operators and bounded model checking.

#### Alloy6 Specification Language

1. **Signature declarations**
   - `sig`, `abstract sig`, `one sig`, `var sig`
   - Field definitions with multiplicity (`set`, `one`, `lone`, `some`)
   - Relational operators (`.`, `^`, `*`, `~`, `->`, `&`, `+`, `-`)
   - Quantifiers (`all`, `some`, `no`, `lone`, `one`)

2. **Linear Temporal Logic (LTL) Operators**

**Core Temporal Operators**

| Operator | Symbol | Meaning | Example |
|----------|--------|---------|---------|
| `always` | □ | Globally - property holds at all future states | `always (stepIndex >= 0)` |
| `eventually` | ◇ | Finally - property eventually becomes true | `eventually (phase = Ready)` |
| `after` | ○ | Next - property holds in immediate next state | `after (stepIndex' = stepIndex + 1)` |
| `var'` | - | Prime notation - reference next state value | `stepIndex' = stepIndex + increment` |

**Fact vs Assertion vs Run vs Check**

| Concept | Purpose | Syntax | Verification |
|---------|---------|--------|--------------|
| **fact** | Define system constraints | `fact { ... }` | Filters valid state combinations |
| **assertion** | State expected properties | `assert { ... }` | Checked for counterexamples |
| **run** | Test satisfiability | `run { ... } for N` | SAT = consistent, UNSAT = over-constrained |
| **check** | Verify assertions | `check assertName for N` | UNSAT = holds, SAT = counterexample found |

**Verification Flow**

```
1. Define facts (system rules)
   ↓
2. Run satisfiability check
   ↓ (if SAT)
3. Define assertions (properties to verify)
   ↓
4. Check assertions
   ↓ (if UNSAT for all)
5. Model verified ✓
```

**Practical Examples from zero_based_counter/model.als**

**Fact (system constraint):**
```alloy
fact zeroBasedInit {
  all c: Cursor | c.position = 0
}
```
→ Filters: Only traces with zero-based cursor initialization are valid

**Assertion (property to verify):**
```alloy
assert positionAdvancesOnTick {
  always (tickEvent implies position' = position + 1)
}
```
→ Verifies: Each tick advances the cursor monotonically from the zero baseline

**Run (satisfiability check):**
```alloy
run zeroBasedScenario { #Cursor = 1 } for 8
```
→ Checks: Can we find at least one valid zero-based trace?

**Check (assertion verification):**
```alloy
check positionAdvancesOnTick for 8
```
→ Verifies: Does the advancement property hold in all valid traces?

#### Task Guidelines for Alloy6

**When Creating New Models**

1. **Always start with clear documentation**
   - Explain the domain being modeled
   - Define key concepts and terminology
   - Reference relevant materials or specifications

2. **Structure models using MECE principles**
   - Separate structural concerns from behavioral concerns
   - Use predicates and functions for reusability
   - Apply single responsibility to signatures and facts

3. **For Structural Models**
   - Define signatures representing entities
   - Specify fields representing relationships
   - Use facts to encode invariants and constraints
   - Write assertions to verify derived properties

4. **For Behavioral Models**
   - Mark variable elements with `var` keyword
   - Define initial state in `fact init`
   - Create action predicates with:
     - Guards (preconditions)
     - Effects (state changes using primed variables)
     - Frame conditions (unchanged elements)
   - Use `always` in transitions fact to specify allowed state changes
   - Include `stutter` predicate for non-deterministic idling

5. **Verification Approach**
   - **Step 1: Check satisfiability** - Run `run` command to verify model is consistent
     - SAT: Model constraints are satisfiable (valid combinations exist)
     - UNSAT: Model is over-constrained (no valid combinations)
   - **Step 2: Verify properties** - Run `check` commands to verify assertions
     - UNSAT: No counterexamples found (property holds)
     - SAT: Counterexample found (property violated)
   - Start with small scopes (e.g., `for 3`)
   - Incrementally increase scope to gain confidence
   - Always verify satisfiability before checking assertions

**Code Quality Standards**

1. **Documentation**
   - Write comprehensive block comments explaining concepts
   - Document each signature, field, fact, predicate, and function
   - Provide alternative implementations as comments when applicable
   - Reference authoritative sources (e.g., practicalalloy.github.io)

2. **Naming Conventions**
   - Use descriptive names for signatures (PascalCase)
   - Use descriptive names for fields and predicates (camelCase)
   - Use clear names for facts that describe what they enforce

3. **Readability**
   - Prefer keyword operators (`and`, `or`, `not`, `implies`, `iff`) over symbols
   - Use proper indentation and spacing
   - Break complex expressions into named predicates or functions
   - Add intermediate `let` bindings for clarity

**Best Practices**

1. **Incremental Development**
   - Build models incrementally, starting simple
   - Add one fact or predicate at a time
   - Verify each addition with run/check commands
   - Refine based on counterexamples

2. **Testing Strategy**
   - Generate diverse instances using `run` with varied scopes
   - Check all critical assertions
   - Examine counterexamples carefully
   - Use Alloy Analyzer's visualization tools

3. **Performance Optimization**
   - Start with minimal scopes
   - Use `but` and `exactly` to fine-tune scope
   - Optimize fact ordering for SAT solver efficiency
   - Consider symmetry breaking when appropriate

**Communication Style**

- Explain concepts using domain-driven language
- Provide mathematical foundations when relevant (category theory, relational algebra)
- Reference existing examples in `samples/` directory
- Use functional and declarative reasoning
- Compress information using MECE framework
- Prioritize implementation correctness over documentation verbosity

**Error Handling**

When encountering issues:

1. Parse errors → Check syntax against Alloy6 specification
2. Unsatisfiable core → Review fact consistency
3. No instances found → Relax constraints or increase scope
4. Assertion fails → Analyze counterexample to identify missing constraints

#### Verification with Alloy6 CLI

After modifying models, always verify changes using the Alloy6 CLI to ensure correctness before committing:

**1. List available commands**
```bash
alloy6 commands <model-file>.als
```

This displays all `run` and `check` commands defined in the model with their index numbers.

**2. Execute specific run/check command**
```bash
# By command name
alloy6 exec -c <command-name> -r <count> -o - -t <format> <model-file>.als

# By command index (from commands list)
alloy6 exec -c <index> -r <count> -o - -t <format> <model-file>.als
```

**3. CLI options**
- **`-c <name|index>`**: Command to execute (name string or numeric index)
- **`-r <n>`**: Number of solutions to find
  - `1`: Find first solution (fastest, for quick verification)
  - `0`: Find all solutions (exhaustive search)
  - `n`: Find up to n solutions
- **`-o <path|->`**: Output destination
  - `-`: Console output (for immediate feedback)
  - `<directory>`: Save to directory (creates files per solution)
- **`-t <format>`**: Output format
  - `text`: Human-readable text format
  - `json`: JSON format (for programmatic processing)
  - `xml`: XML format
  - `table`: Tabular format

**4. Verification workflow**

**Step 1: Syntax check**
```bash
# List commands (this also validates syntax)
alloy6 commands <model>.als
```

**Step 2: Test simple scenarios first**
```bash
# Execute the simplest run command
alloy6 exec -c 0 -r 1 -o - -t text <model>.als
```

**Step 3: Test complex scenarios**
```bash
# Execute behavioral scenarios
alloy6 exec -c <scenario-name> -r 1 -o - -t text <model>.als
```

**Step 4: Verify assertions**
```bash
# Check all assertions
alloy6 exec -c <assertion-name> -r 1 -o - -t text <model>.als
```

**Step 5: Generate multiple instances (if needed)**
```bash
# Find multiple solutions for exploration
alloy6 exec -c <command> -r 5 -o - -t text <model>.als
```

**5. Interpreting output**

**Success indicators:**
- Trace output showing state transitions (for temporal models)
- Instance output showing satisfying assignments (for structural models)
- No error messages

**Failure indicators:**
- No output (command produced no results)
- "No instance found" message (constraints are unsatisfiable)
- "Predicate may be inconsistent" (conflicting constraints)

**Parse/runtime errors:**
- Syntax error messages with file path and line numbers
- Type errors indicating incompatible expressions
- Scope errors when model exceeds specified bounds

**6. Best practices**

**Incremental verification:**
1. Start with minimal scopes and simple scenarios
2. Gradually increase complexity and scope
3. Test each modification immediately after changes
4. Keep a working baseline command for regression testing

**Structured testing approach:**
- **Positive tests**: `run` commands that should find instances
- **Negative tests**: `check` commands that should find no counterexamples
- **Boundary tests**: Commands testing edge cases and limits

**Debugging strategy:**
- If no instance found, relax constraints incrementally
- If too many instances, add constraints to narrow scope
- Use `text` format for debugging, `json` for automation
- Compare different scopes to understand model behavior

**Performance optimization:**
- Use `-r 1` for fast feedback during development
- Increase scope gradually to avoid SAT solver timeout
- For temporal models, limit Time steps appropriately
- Profile with different solvers if available

**7. Integration with development workflow**

**Before committing changes:**
```bash
# Quick sanity check
alloy6 commands <model>.als && \
alloy6 exec -c 0 -r 1 -o - -t text <model>.als
```

**Continuous verification script example:**
```bash
#!/bin/bash
MODEL="model.als"

# List all commands
echo "=== Available Commands ==="
alloy6 commands $MODEL

# Run all tests
for i in {0..5}; do
  echo "=== Executing command $i ==="
  alloy6 exec -c $i -r 1 -o - -t text $MODEL || echo "Command $i failed"
done
```

**Documentation of verification:**
- Record which commands pass/fail in commit messages
- Include CLI commands in model comments for reproducibility
- Maintain a test suite of essential verification commands

#### References

- [Alloy6 Language Reference](https://alloytools.org/)
- [Alloy6 CLI Documentation](https://github.com/AlloyTools/org.alloytools.alloy)
- [Practical Alloy](https://practicalalloy.github.io/index.html)
- [Property Specification Patterns (LTL)](https://matthewbdwyer.github.io/psp/patterns/ltl.html)
