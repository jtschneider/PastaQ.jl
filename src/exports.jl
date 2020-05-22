export 
# quantumgates.jl
  # Methods
  #gate_I,
  #gate_X,
  #gate_Y,
  #gate_Z,
  #gate_H,
  #gate_S,
  #gate_T,
  #gate_Kp,
  #gate_Km,
  #gate_Rx,
  #gate_Ry,
  #gate_Rz,
  #gate_Rn,
  #gate_Sw,
  #gate_Cx,
  #gate_Cy,
  #gate_Cz,
  quantumgates,
  quantumgate,

# circuitops.jl
  # Methods
  getsitenumber,
  applygate!,
  makegate,

# quantumcircuit.jl
  QuantumCircuit,
  # Methods
  qubits,
  reset!,
  addgates!,
  compilecircuit,
  compilecircuit!,
  runcircuit,
  runcircuit!,
  makemeasurementgates,
  #hadamardlayer!,
  #rand1Qrotationlayer!,
  #Cxlayer!,
  #generatemeasurementcircuit,

# qst,jl
  QST,
  # Methods
  normalization,
  normalize!,
  lognormalization,
  lognormalize!,
  projectpsi,
  nll,
  gradlogZ,
  gradnll,
  makemeasurementcircuit,
  statetomography,

# optimizer.jl
  Optimizer,
  # Methods
  updateSGD,

# utils.jl
  # Methods
  fullvector,
  fullmatrix
