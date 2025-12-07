# ML-based FDI Countermeasure for IoE Micro-Grids

An AI-powered detection system for False Data Injection Attacks (FDIA) in smart grid and microgrid environments using deep learning techniques.

## 🎯 Overview

This project implements a machine learning-based approach to detect and counter False Data Injection (FDI) attacks in Internet of Energy (IoE) enabled microgrids. The system uses LSTM neural networks to identify anomalous patterns in power system measurements that may indicate cyber-attacks.

### Key Features

- **Dual Operating Modes**: Supports both grid-connected and islanded microgrid operations
- **Advanced Attack Detection**: Identifies various types of FDI attacks including coordinated attacks on multiple buses
- **Real-time Analysis**: LSTM-based model for time-series anomaly detection
- **Comprehensive Testing**: Evaluation across multiple attack scenarios and operating conditions
- **IEEE 33-Bus System**: Based on the widely-used IEEE 33-bus distribution system adapted for microgrid simulation

## 🏗️ Architecture

The project consists of two main components:

1. **MATLAB Simulation Engine**: Generates realistic power flow data for both normal operation and attack scenarios
2. **Python ML Pipeline**: Trains and evaluates LSTM models for attack detection

### Project Structure

```
.
├── SimulateGrid.m              # Grid-connected mode simulation
├── SimulateIsland.m            # Islanded mode simulation
├── case33mg.m                  # IEEE 33-bus microgrid configuration
├── DataPreprocessing.py        # Data preparation and normalization
├── WindowGenerator.py          # Time-series window creation
├── train_grid.py               # Training script for grid-connected mode
├── train_island.py             # Training script for islanded mode
├── eval_grid.py                # Evaluation for grid-connected mode
├── eval_island.py              # Evaluation for islanded mode
├── compare_models.py           # Model comparison and analysis
├── Model/                      # Trained model files
├── RawDataset/                 # Raw simulation data
├── RegroupedDataset/           # Preprocessed data
├── VectorDataset/              # Grid-connected training data
└── VectorDataset_Islanded/     # Islanded mode training data
```

## 🚀 Getting Started

### Prerequisites

**MATLAB Requirements:**
- MATLAB R2019b or later
- MATPOWER toolbox (for power flow analysis)

**Python Requirements:**
- Python 3.8+
- TensorFlow 2.x
- NumPy
- Pandas
- Matplotlib
- Scikit-learn

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/ML-based-FDI-Countermeasure-for-IoE-Micro-Grids.git
cd ML-based-FDI-Countermeasure-for-IoE-Micro-Grids
```

2. **Install Python dependencies:**
```bash
pip install tensorflow numpy pandas matplotlib scikit-learn
```

3. **Install MATPOWER:**
   - Download from: https://matpower.org/
   - Add to MATLAB path

### Usage

#### 1. Generate Simulation Data

**Grid-Connected Mode:**
```matlab
% In MATLAB
SimulateGrid
```

**Islanded Mode:**
```matlab
% In MATLAB
SimulateIsland
```

#### 2. Preprocess Data

```bash
python DataPreprocessing.py
```

#### 3. Train Models

**Grid-Connected Mode:**
```bash
python train_grid.py
```

**Islanded Mode:**
```bash
python train_island.py
```

#### 4. Evaluate Models

**Grid-Connected Mode:**
```bash
python eval_grid.py
```

**Islanded Mode:**
```bash
python eval_island.py
```

#### 5. Compare Performance

```bash
python compare_models.py
```

## 📊 Attack Scenarios

The system is tested against various FDI attack types:

1. **Type 1**: DER control signal manipulation
2. **Type 2**: Load measurement falsification
3. **Type 3**: Voltage magnitude attacks
4. **Type 4**: Coordinated multi-bus attacks
5. **Type 5**: Timing-based attacks during mode transitions
6. **Type 6**: Power injection attacks

For detailed attack scenario descriptions, see `ATTACK_SCENARIOS.md` (if available).

## 🔬 Research Background

### Why IEEE 33-Bus for Microgrids?

The IEEE 33-bus distribution system is widely adopted in microgrid research:
- Standard benchmark for distribution system studies
- Realistic representation of medium-voltage distribution networks
- Extensively validated in literature
- Suitable for DER integration studies

**References:**
- [IEEE Paper 1](https://ieeexplore.ieee.org/document/9939755)
- [IEEE Paper 2](https://ieeexplore.ieee.org/document/9686196)
- [Emergent Mind Topic](https://www.emergentmind.com/topics/ieee-33-bus-distribution-system)

## 📈 Results

The LSTM-based detection system achieves:
- High detection accuracy across multiple attack scenarios
- Low false positive rates
- Real-time detection capability
- Robust performance in both grid-connected and islanded modes

Detailed results and visualizations are generated in `comparison_analysis.png` and CSV files.

## 🛠️ Future Enhancements

See [TODO.md](TODO.md) for planned features and research directions, including:

- Advanced attack scenarios
- Multiple operating conditions
- Model optimization
- Real-time visualization dashboard
- Comparative studies between operating modes

## 📝 License

[Add your license here]

## 👥 Contributors

[Add contributors here]

## 📧 Contact

[Add contact information here]

## 🙏 Acknowledgments

- MATPOWER development team
- IEEE PES for test case standards
- Research community for microgrid security insights

---

**Note**: This project is for research and educational purposes. Always ensure proper cybersecurity measures in production power systems.
