# ML-based FDI Countermeasure for IoE Micro-Grids

## Overview

This system implements an artificial intelligence-powered detection mechanism for False Data Injection Attacks (FDIA) in smart grid and microgrid environments. It uses deep learning techniques, specifically Long Short-Term Memory (LSTM) neural networks, to identify malicious data tampering in power system measurements.

### What are False Data Injection Attacks?

False Data Injection Attacks are cyber-attacks where adversaries manipulate measurement data in power systems to mislead operators and potentially cause system instability. These attacks can:

- Hide power theft or unauthorized consumption
- Manipulate electricity market prices
- Trigger unnecessary control actions
- Mask equipment failures or outages
- Destabilize grid operations

### System Capabilities

The system can detect FDIAs in two distinct microgrid operating modes:

1. **Grid-Connected Mode**: Microgrid operates while connected to the main utility grid through a Point of Common Coupling (PCC)
2. **Islanded Mode**: Microgrid operates autonomously without external grid connection

## Architecture and Workflow

### Complete Pipeline

The detection system follows a five-stage pipeline:

**Stage 1: Data Preprocessing**
Raw household power consumption data is split and formatted to represent loads across multiple buses in the microgrid.

**Stage 2: Power System Simulation**
MATLAB/MATPOWER simulates realistic power flows for a 33-bus microgrid test case, generating both normal and attacked measurement vectors.

**Stage 3: Model Training**
LSTM neural networks learn patterns from clean (untampered) measurement data to establish baseline behavior.

**Stage 4: Attack Detection**
Trained models predict expected measurements and flag anomalies by calculating Mean Squared Error (MSE) between predictions and actual measurements.

**Stage 5: Performance Analysis**
Comprehensive evaluation metrics and visualizations compare detection accuracy across operating modes.

## System Components

### Microgrid Test Case (case33mg.m)

A modified IEEE 33-bus distribution system configured as a microgrid with:

- 33 buses at 12.66 kV base voltage
- 5 MVA base power
- 4 generators:
  - Bus 1: Main slack generator (1.5 MW max)
  - Bus 6: Solar PV/DER 1 (0.6 MW max)
  - Bus 18: Solar PV/DER 2 (0.6 MW max)
  - Bus 25: Solar PV with storage (0.8 MW max)
- Bus 34: External grid connection point (grid-connected mode only)
- 11 load buses (buses 2-12) with time-varying consumption
- Radial network topology with 33 branches

### Power Flow Simulation

**SimulateGrid.m (Grid-Connected Mode)**

Simulates 20,000 timesteps of microgrid operation while connected to the external grid.

Key features:
- PCC branch (bus 1 to bus 34) remains closed
- Time-varying DER generation based on solar profiles
- DC power flow analysis for computational efficiency
- 20% of measurements after timestep 2000 are deliberately falsified
- Generates measurement vectors containing bus power injections and branch power flows

**SimulateIsland.m (Islanded Mode)**

Simulates autonomous microgrid operation without grid connection.

Key differences from grid-connected:
- PCC branch and external grid bus are removed
- Bus 1 configured as controllable slack generator
- DER generation scaled to match total load demand
- Maintains power balance through local generation only
- Results in 64-dimensional measurement vectors (33 buses + 31 branches)

Both simulators generate three output files:
- untamperedVectorData.csv: Clean measurements without attacks
- tamperedVectorData.csv: Measurements with injected false data
- labelData.csv: Binary labels (0=clean, 1=attacked)

### Attack Mechanism

The FDIA implementation uses a Jacobian-based approach:

1. Compute the Jacobian matrix H of the power system
2. Generate random attack vector c
3. Create falsified measurement: z_a = z + H*c + error

This method creates stealthy attacks that can bypass traditional bad data detection based on residual analysis.

### LSTM Detection Model

**Architecture**

Three-layer LSTM network with:
- Input layer: Time-windowed measurement sequences
- LSTM Layer 1: 64 units with tanh activation
- Dense Layer 1: 64 units with linear activation
- LSTM Layer 2: 64 units with tanh activation
- Dense Layer 2: 64 units with linear activation
- LSTM Layer 3: 64 units with tanh activation
- Dense Layer 3: 64 units with linear activation
- Output layer: N units (25 for grid-connected, 64 for islanded)

**Training Configuration**

- Loss function: Mean Squared Error
- Optimizer: Adam with 0.01 learning rate
- Training epochs: 20 (with early stopping)
- Early stopping patience: 2 epochs
- Batch size: 32
- Input window: 5 timesteps (changed from 3 in training to 5 in evaluation)
- Data split: 70% training, 20% validation, 10% testing

**Detection Logic**

The model predicts expected measurements based on historical patterns. Attacks are detected when:

MSE(predicted, actual) > threshold

Default threshold: MSE = 20

If MSE exceeds threshold, the measurement is flagged as potentially attacked.

## Installation and Prerequisites

### Software Requirements

**MATLAB Environment**
- MATLAB R2019b or later
- MATPOWER toolbox (version 7.0 or later)
- Statistics and Machine Learning Toolbox

**Python Environment**
- Python 3.7 or later
- TensorFlow 2.x
- Keras
- NumPy
- Pandas
- Matplotlib

### Installation Steps


## Usage Guide

### Complete Workflow Execution

**Phase 1: Data Preparation**

Run data preprocessing to format the raw power consumption data:

```
python DataPreprocessing.py
```

This creates RegroupedDataset/RegroupedData.csv with 22 columns (11 active power + 11 reactive power measurements).

**Phase 2: Grid-Connected Simulation**

Open MATLAB and run:

```
SimulateGrid
```

This generates VectorDataset/ directory containing:
- untamperedVectorData.csv (25 columns)
- tamperedVectorData.csv (25 columns)
- labelData.csv (binary labels)

Expected runtime: 30-60 minutes depending on hardware.

**Phase 3: Islanded Mode Simulation**

In MATLAB, run:

```
SimulateIsland
```

This generates VectorDataset_Islanded/ directory with the same file structure but 64 columns instead of 25.

**Phase 4: Model Training**

Train the grid-connected detection model:

```
python train_grid.py
```

Train the islanded mode detection model:

```
python train_island.py
```

Both models are saved to Model/ directory:
- model.h5 (grid-connected)
- model_islanded.h5 (islanded)

Training time: 10-30 minutes per model depending on GPU availability.

**Phase 5: Evaluation**

Evaluate grid-connected detection:

```
python eval_grid.py
```

Evaluate islanded detection:

```
python eval_island.py
```

Each evaluation outputs:
- Success rate percentage
- MSE values for each test sample
- Detection results (saved to mseList.csv or mseList_islanded.csv)

**Phase 6: Comparative Analysis**

Generate comprehensive comparison between operating modes:

```
python compare_models.py
```

This produces:
- Side-by-side performance metrics
- Visualization plots (comparison_analysis.png)
- Statistical analysis of detection accuracy

## Output Interpretation

### Evaluation Metrics

**Accuracy**: Percentage of correct classifications (both attack detection and normal operation)

**Precision**: Among flagged attacks, what percentage were actual attacks
Formula: True Positives / (True Positives + False Positives)

**Recall**: Among actual attacks, what percentage were detected
Formula: True Positives / (True Positives + False Negatives)

**F1 Score**: Harmonic mean of precision and recall
Formula: 2 * (Precision * Recall) / (Precision + Recall)

**Mean MSE**: Average reconstruction error across all samples

**Confusion Matrix Elements**:
- True Positives: Correctly identified attacks
- True Negatives: Correctly identified normal operation
- False Positives: Normal data incorrectly flagged as attack
- False Negatives: Attacks that went undetected

### Typical Performance

Grid-Connected Mode:
- Accuracy: 95-99%
- Precision: 90-95%
- Recall: 85-92%
- Mean MSE: 5-15 (normal), 50-200 (attacked)

Islanded Mode:
- Generally similar or slightly different due to different measurement dimensionality
- Performance depends on generation-load balance quality


## Technical Details

### Why 33-Bus System?



### DC Power Flow Simplification



### LSTM Architecture Rationale



### Adding New Features

To incorporate additional measurements:
1. Modify case33mg.m to include new buses or branches
2. Update measurement vector extraction in simulation scripts
3. Adjust column counts in training/evaluation scripts
4. Retrain models with new dimensionality

### Changing Model Architecture

In train_grid.py or train_island.py, modify the Sequential model:
- Add/remove LSTM layers
- Change number of units per layer
- Experiment with GRU layers instead of LSTM
- Adjust activation functions


## References and Further Reading

### Key Concepts

**State Estimation**: Process of determining system state (voltages, angles) from noisy measurements

**Bad Data Detection**: Traditional method using chi-square test on weighted residuals

**Jacobian Matrix**: Matrix of partial derivatives relating measurements to state variables

**DC Power Flow**: Linearized power flow model assuming small angles and constant voltages

### Related Work

Research utilizing IEEE 33-bus system for microgrid studies:
- Various papers in IEEE Transactions on Smart Grid
- Conference proceedings on microgrid security
- Studies on distributed energy resource integration

### IHEPCDS Dataset

Individual Household Electric Power Consumption Data Set from UCI Machine Learning Repository, containing real power consumption measurements from a single household over 47 months.
