# CORAL

**CORAL — Coral reef Optimization for Adaptive Layouts**

A topology-aware coral-reef-inspired metaheuristic for mixed-integer chemical process superstructure optimization.

## Overview

CORAL is a mixed-variable optimization framework designed for process systems engineering problems in which discrete flowsheet topology decisions must be optimized together with continuous design and operating variables.

The algorithm combines:

- topology-aware coral reproduction;
- feasibility-first larval settlement;
- structural diversity preservation using topology distance;
- adaptive search operators;
- bleaching and recolonization;
- optional local nonlinear-programming refinement.

A candidate solution is represented as

\[
C_i = (\mathbf{y}_i,\mathbf{x}_i,f_i,V_i)
\]

where:

- \(\mathbf{y}_i\) contains discrete process-topology decisions;
- \(\mathbf{x}_i\) contains continuous design and operating variables;
- \(f_i\) is the objective-function value;
- \(V_i\) is the total constraint violation.

## Illustrative superstructure

The current benchmark considers a small reactor-separator-recycle superstructure with:

- CSTR or PFR;
- Flash or Distillation;
- Recycle or no recycle.

The continuous variables are reactor temperature, reactor size, separator severity, and recycle fraction.

The exhaustive reference solution for this illustrative benchmark is:

**PFR + Flash + Recycle**

with

**TAC = 22,160.75**

## Repository structure

```text
CORAL/
├── src/
│   └── CORALSuperstructureOptimizer.m
├── examples/
│   ├── simple_process_superstructure.m
│   └── example_CORAL_superstructure.m
├── benchmarks/
│   ├── exhaustive_superstructure_reference_fixed.m
│   ├── benchmark_CORAL_superstructure_fixed.m
│   └── benchmark_CORAL_ablation_fixed.m
├── data/
│   ├── CORAL_ablation_summary_fixed.csv
│   ├── CORAL_benchmark_runs_fixed.csv
│   ├── CORAL_reference_topologies_fixed.csv
│   └── CORAL_topology_frequencies_fixed.csv
├── figures/
├── docs/
├── README.md
└── LICENSE
