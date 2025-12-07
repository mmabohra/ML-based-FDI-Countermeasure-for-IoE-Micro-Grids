```
# TODO

Why 33bus for microgrid?
https://ieeexplore.ieee.org/document/9939755
https://ieeexplore.ieee.org/document/9686196
https://www.emergentmind.com/topics/ieee-33-bus-distribution-system
several researchers use 33bus for microgrid simulations.

## 📋 Future Enhancements

### High Priority

4. **Advanced Attack Scenarios** ✅ COMPLETED
   - ✅ Look for microgrid-specific attack scenarios (See ATTACK_SCENARIOS.md)
   - ✅ Implement coordinated attacks on multiple buses (Type 4 attack)
   - ✅ Test attacks targeting DER control signals (Type 1, 6 attacks)
   - ✅ Investigate timing-based attacks during mode transitions (Type 5 attack)
   - 📁 Files: MicrogridAttackScenarios.m, SimulateGrid_AdvancedAttacks.m, ATTACK_SCENARIOS.md

5. **Multiple Operating Conditions**
   - High solar generation (daytime peak)
   - Low generation (nighttime with battery discharge)
   - Peak load vs. off-peak load
   - Seasonal variations (summer vs. winter)
   - Emergency conditions (DER failure scenarios)

### Medium Priority

6. **Model Optimization**
   - Improve computational benchmarks
   - Create lightweight model for edge deployment
   - Experiment with different architectures (GRU, Transformer)
   - Implement model quantization for embedded systems

7. **Visualization & Monitoring**
   - Real-time detection dashboard
   - Interactive power flow visualization
   - Attack pattern analysis tools
   - Time-series anomaly plots

### Low Priority

8. **Extended Features**
   - Multi-attack type classification (not just binary detection)
   - Adaptive threshold tuning
   - Integration with SCADA systems
   - Hardware-in-the-loop (HIL) testing

## 🔬 Research Directions

9. **Novel Contributions**
   - Compare FDIA signatures in grid-connected vs islanded modes
   - Investigate vulnerability differences between operating modes
   - Develop mode-specific detection strategies
   - Publish comparative study

10. **Benchmarking**
    - Test against other ML methods (Random Forest, SVM, Autoencoders)
    - Compare with traditional bad data detection (BDD)
    - Evaluate computational overhead
    - Measure detection latency

---
