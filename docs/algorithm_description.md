# CORAL algorithm description

## Name

**CORAL — Coral reef Optimization for Adaptive Layouts**

CORAL is a topology-aware, coral-reef-inspired optimization framework for mixed-integer process superstructure optimization.

## Candidate representation

Each candidate solution is represented as:

`C_i = (y_i, x_i, f_i, V_i)`

where:

- `y_i` contains discrete topology variables;
- `x_i` contains continuous design and operating variables;
- `f_i` is the objective-function value;
- `V_i` is the total constraint violation.

## Main algorithmic components

### 1. Reef initialization

A fixed-size reef is partially populated with candidate solutions. Binary and continuous variables are initialized within their feasible domains.

### 2. Broadcast spawning

Two parent corals generate offspring through:

- topology-aware crossover of discrete variables;
- blending of continuous variables;
- small continuous perturbations.

### 3. Brooding

A single coral generates a locally perturbed offspring. Continuous variables are mutated more strongly than topology variables.

### 4. Topology mutation

One or more discrete topology variables are explicitly changed, followed by a smaller perturbation of the continuous variables.

### 5. Differential variation

A differential-evolution-style operator is applied to the continuous variables, optionally combined with a topology change.

### 6. Feasibility-first settlement

Larvae attempt to occupy reef cells.

Competition follows the rule:

1. feasible solutions dominate infeasible solutions;
2. between infeasible solutions, lower total constraint violation is preferred;
3. between feasible solutions, lower objective value is preferred.

### 7. Structural niches

Topology similarity is measured using Hamming distance between binary topology vectors.

Structurally different candidate solutions can be retained to prevent premature domination of the reef by a single process configuration.

### 8. Budding

Elite corals generate locally perturbed copies to intensify search around promising regions.

### 9. Depredation

Poorly performing corals can be removed, creating vacant reef space for new candidate solutions.

### 10. Bleaching and recolonization

If topology diversity falls below a threshold, a bleaching event removes part of the reef population.

Vacant cells are recolonized with new candidate solutions to restore structural diversity.

### 11. Adaptive operator probabilities

The probabilities of reproductive operators can be updated according to recent settlement success.

Operators that generate successful larvae gain influence, while minimum probabilities prevent complete loss of alternative search strategies.

### 12. Local nonlinear-programming refinement

For selected promising solutions, the topology is fixed and the continuous variables are refined using local nonlinear programming.

In the current MATLAB implementation this is performed with `fmincon`.

This creates a hybrid search architecture:

```text
CORAL
global structural exploration
        |
        v
promising process topology
        |
        v
local NLP refinement
continuous design optimization
```

## Generic workflow

```text
Initialize reef
      |
      v
Evaluate candidates
      |
      v
Generate larvae
      |
      +--> broadcast spawning
      +--> brooding
      +--> topology mutation
      +--> differential variation
      |
      v
Optional local NLP refinement
      |
      v
Larval settlement and competition
      |
      v
Budding and depredation
      |
      v
Check topology diversity
      |
      +--> bleaching / recolonization if needed
      |
      v
Adapt operator probabilities
      |
      v
Repeat until stopping criterion
```

## Process-synthesis interpretation

The key distinction in CORAL is between:

- **structural decisions**, such as reactor type, separator type, recycle structure, or process connectivity;
- **continuous decisions**, such as temperature, pressure, flow rate, equipment size, or split fraction.

CORAL therefore uses the reef primarily to explore **which process structure should be selected**, while local nonlinear optimization can determine **how that process should operate**.

## Current status

The present implementation is a research prototype.

The initial reactor-separator-recycle case study is intended as a transparent validation problem. Future development will focus on larger and established chemical-process synthesis benchmarks, connectivity-aware topology operators, and comparison with other stochastic and deterministic optimization methods.
