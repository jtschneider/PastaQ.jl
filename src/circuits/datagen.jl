
"""
    randombases(N::Int,nshots::Int;
                localbasis::Array=["X","Y","Z"],
                n_distinctbases=nothing)

Generate `nshots` measurement bases. By default, each
local basis is randomly selected between `["X","Y","Z"]`, with
`"Z"` being the default basis where the quantum state is written.
If `numbases` is provided, the output consist of `n_distinctbases`
different measurement basis, each being repeated `nshots÷n_distinctbases`
times.
"""
function randombases(N::Int,numshots::Int;
                     localbasis::Array=["X","Y","Z"],
                     n_distinctbases=nothing)
  # One shot per basis
  if isnothing(n_distinctbases)
    bases = rand(localbasis,numshots,N)
  # Some number of shots per basis
  else
    @assert(numshots%n_distinctbases ==0)
    shotsperbasis = numshots÷n_distinctbases
    bases = repeat(rand(localbasis,1,N),shotsperbasis)
    for n in 1:n_distinctbases-1
      newbases = repeat(rand(localbasis,1,N),shotsperbasis)
      bases = vcat(bases,newbases)
    end
  end
  return bases
end


"""
    measurementgates(basis::Array)

Given as input a measurement basis, returns the corresponding
gate data structure. If the basis is `"Z"`, no action is required.
If not, a quantum gate corresponding to the given basis rotation
is added to the list.

Example:
  basis = ["X","Z","Z","Y"]
  -> gate_list = [("measX", 1),
                  ("measY", 4)]
"""
function measurementgates(basis::Array)
  gate_list = Tuple[]
  for j in 1:length(basis)
    if (basis[j]!= "Z")
      push!(gate_list,("meas$(basis[j])", j))
    end
  end
  return gate_list
end


"""
    randompreparations(N::Int,nshots::Int;
                       states::Array=["X+","X-","Y+","Y-","Z+","Z-"],
                       n_distinctstates=nothing)

Generate `nshots` input states to a quantum circuit. By default, each
single-qubit state is randomly selected between the 6 eigenstates of
the Pauli matrices, `["X+","X-","Y+","Y-","Z+","Z-"]`.
If `n_distinctstates` is provided, the output consist of `numprep`
different input states, each being repeated `nshots÷n_distinctstates`
times.
"""
function randompreparations(N::Int,nshots::Int;
                            inputstates::Array=["X+","X-","Y+","Y-","Z+","Z-"],
                            n_distinctstates=nothing)
  # One shot per basis
  if isnothing(n_distinctstates)
    preparations = rand(inputstates,nshots,N)
  else
    @assert(nshots%n_distinctstates == 0 )
    shotsperstate = nshots÷n_distinctstates
    preparations = repeat(rand(inputstates,1,N),shotsperstate)
    for n in 1:n_distinctstates-1
      newstates = repeat(rand(inputstates,1,N),shotsperstate)
      preparations = vcat(preparations,newstates)
    end
  end
  return preparations
end


"""
    preparationgates(prep::Array)

Given as input a prepared input state, returns the corresponding
gate data structure. If the state is `"Z+"`, no action is required.
If not, a quantum gate for state preparation is added to the list.

Example:
prep = ["X+","Z+","Z+","Y+"]
-> gate_list = [("prepX+", 1),
                ("prepY+", 4)]
"""
function preparationgates(prep::Array)
  gate_list = Tuple[]
  for j in 1:length(prep)
    if (prep[j]!= "Z+")
      gatename = "prep$(prep[j])"
      push!(gate_list, (gatename, j))
    end
  end
  return gate_list
end


"""
    getsamples!(M::Union{MPS,MPO},nshots::Int)

Perform a projective measurement of a wavefunction 
`|ψ⟩` or density operator `ρ`. The measurement consist of
a binary vector `σ = (σ₁,σ₂,…)`, drawn from the probabilty
distribution:
- P(σ) = |⟨σ|ψ⟩|² : if `M = ψ is MPS`
- P(σ) = ⟨σ|ρ|σ⟩  : if `M = ρ is MPO`
"""
function getsamples!(M::Union{MPS,MPO};kwargs...)
  p1given0 = get(kwargs,:p1given0,nothing) 
  p0given1 = get(kwargs,:p0given1,nothing) 
  orthogonalize!(M,1)
  measurement = sample(M)
  measurement .-= 1
  if !isnothing(p1given0) | !isnothing(p0given1)
    p1given0 = (isnothing(p1given0) ? 0.0 : p1given0)
    p0given1 = (isnothing(p0given1) ? 0.0 : p0given1)
    readouterror!(measurement,p1given0,p0given1)
  end
  return measurement
end

"""
    getsamples!(M::Union{MPS,MPO},nshots::Int)

Perform `nshots` projective measurements on a wavefunction 
`|ψ⟩` or density operator `ρ`. 
"""
function getsamples!(M::Union{MPS,MPO},nshots::Int; kwargs...)
  measurements = Matrix{Int64}(undef, nshots, length(M))
  for n in 1:nshots
    measurements[n,:] = getsamples!(M;kwargs...)
  end
  return measurements
end


"""
    readouterror!(measurement::Array;probs::Array=[0.0,0.0])

Add readout error to a single measurement

# Arguments:
  - `measurement`: bit string of projective measurement outcome
  - `p1given0`: readout error probability 0 -> 1
  - `p0given1`: readout error probability 1 -> 0
"""
function readouterror!(measurement::Array,p1given0::Float64,p0given1::Float64)
  for j in 1:size(measurement)[1]
    if measurement[j] == 0
      measurement[j] = StatsBase.sample([0,1],Weights([1-p1given0,p1given0]))
    else
      measurement[j] = StatsBase.sample([0,1],Weights([p0given1,1-p0given1]))
    end
  end
  return measurement
end


"""
MEASUREMENT IN MULTIPLE BASES
"""

"""
    getsamples(M::Union{MPS,MPO},bases::Array)
Generate a dataset of `nshots` measurements acccording to a set
of input `bases`. For a single measurement, tf `Û` is the depth-1 
local circuit rotating each qubit, the  data-point `σ = (σ₁,σ₂,…)
is drawn from the probability distribution:
- P(σ) = |⟨σ|Û|ψ⟩|²   : if M = ψ is MPS
- P(σ) = <σ|Û ρ Û†|σ⟩ : if M = ρ is MPO   
"""
function getsamples(M0::Union{MPS,MPO},bases::Array; kwargs...)
  @assert length(M0) == size(bases)[2]
  data = Matrix{String}(undef, size(bases)[1],length(M0))
  for n in 1:size(bases)[1]
    meas_gates = measurementgates(bases[n,:])
    M = runcircuit(M0,meas_gates)
    measurement = getsamples!(M;kwargs...)
    data[n,:] = convertdatapoint(measurement,bases[n,:])
  end
  return data 
end


"""
QUANTUM PROCESS TOMOGRAPHY
"""

""" 
    getsamples(M0::Union{MPS,MPO},
                 gate_tensors::Vector{<:ITensor},
                 prep::Array,basis::Array;
                 cutoff::Float64=1e-15,maxdim::Int64=10000,
                 kwargs...)

Generate a single data-point for quantum process tomography, 
consisting of an input state (a product state of single-qubit
Pauli eigenstates) and an output state measured after a given
basis rotation is performed at the output of a quantum channel.

# Arguments:
 - `M0`: reference input state (to avoid re-compiling the circuit)
 - `gate_tensors`: tensors for the channel (unitary or noisy)
 - `prep`: a prepared input state (e.g. `["X+","Z-","Y+","X-"]`)
 - `basis`: a measuremement basis (e.g. `["Z","Z","Y","X"])
"""
# Generate a single data point for process tomography
function getsamples(M0::Union{MPS,MPO},
                      gate_tensors::Vector{<:ITensor},
                      prep::Array,basis::Array;
                      cutoff::Float64=1e-15,maxdim::Int64=10000,
                      kwargs...)
  # Generate preparation/measurement gates
  prep_gates = preparationgates(prep)
  meas_gates = measurementgates(basis)
  # Prepare quantum state
  M_in  = runcircuit(M0,prep_gates)
  # Apply the quantum channel
  M_out = runcircuit(M_in,gate_tensors,
                     cutoff=cutoff,maxdim=maxdim) 
  # Apply basis rotation
  M_meas = runcircuit(M_out,meas_gates)
  # Measure
  measurement = getsamples!(M_meas;kwargs...)
  
  return convertdatapoint(measurement,basis)
end


"""
    projectchoi(Λ0::Choi{MPO},prep::Array)

Project the Choi matrix (MPO only for now) input indices into a state `prep` 
made out of single-qubit Pauli eigenstates (e.g. `|ϕ⟩ =|+⟩⊗|0⟩⊗|r⟩⊗…).
The resulting MPO describes the quantum state obtained by applying
the quantum channel underlying the Choi matrix to `|ϕ⟩`.
"""
function projectchoi(Λ0::Choi{MPO},prep::Array)
  Λ = copy(Λ0)
  choi = Λ.M
  state = "state" .* copy(prep) 
  s = firstsiteinds(choi,tags="Input")
  
  for j in 1:length(choi)
    # No conjugate on the gate (transpose input!)
    choi[j] = choi[j] * dag(gate(state[j],s[j]))
    choi[j] = choi[j] * prime(gate(state[j],s[j]))
  end
  return choi
end


"""
    projectunitary(U0::MPO,prep::Array)

Project the unitary circuit (MPO) into a state `prep` 
made out of single-qubit Pauli eigenstates (e.g. `|ϕ⟩ =|+⟩⊗|0⟩⊗|r⟩⊗…).
The resulting MPS describes the quantum state obtained by applying
the quantum circuit to `|ϕ⟩`.
"""
function projectunitary(U::MPO,prep::Array)
  state = "state" .* copy(prep) 
  M = ITensor[]
  s = firstsiteinds(U)
  for j in 1:length(U)
    push!(M,U[j] * gate(state[j],s[j]))
  end
  return noprime!(MPS(M))
end


"""
    getsamples(N::Int64,gates::Vector{<:Tuple},nshots::Int64;     
                 noise=nothing,return_state::Bool=false,            
                 choi::Bool=false,process::Bool=false,              
                 localbasis::Array=["X","Y","Z"],                   
                 inputstates::Array=["X+","X-","Y+","Y-","Z+","Z-"],
                 n_distinctbases = nothing,n_distinctstates=nothing,
                 cutoff::Float64=1e-15,maxdim::Int64=10000,         
                 kwargs...)                                         

Generate `nshots` data-point for quantum process tomography for a 
quantum channel corresponding to a set of quantum `gates` and a `noise`
model. 

# Arguments:
  - `gates`: a set of quantum gates
  - `noise`: apply a noise model after each quantum gate in the circuit
  - `return_state`: if true, returns the ouput state `ψ = U|0,0,…,0⟩`
  - `choi`: if true, generate data using the Choi matrix
  - `process`: if true, generate data for process tomography  
  - `inputstates`: a set of input states (e.g. `["X+","X-","Y+","Y-","Z+","Z-"]`)   
  - `localasis`: set of basis used (e.g. `["X","Y","Z"])
"""
function getsamples(N::Int64,gates::Vector{<:Tuple},nshots::Int64;
                      noise=nothing,return_state::Bool=false,
                      build_process::Bool=true,process::Bool=false,
                      localbasis::Array=["X","Y","Z"],
                      inputstates::Array=["X+","X-","Y+","Y-","Z+","Z-"],
                      n_distinctbases = nothing,n_distinctstates=nothing,
                      cutoff::Float64=1e-15,maxdim::Int64=10000,
                      p1given0=nothing,p0given1=nothing,
                      kwargs...)
  
  data = Matrix{String}(undef, nshots,N)
  bases = randombases(N,nshots;localbasis=localbasis,n_distinctbases=n_distinctbases)
  
  if !process
    # Apply the quantum channel
    M = runcircuit(N,gates;process=false,noise=noise,
                   cutoff=cutoff,maxdim=maxdim,kwargs...)
    data = getsamples(M,bases;p1given0=p1given0,p0given1=p0given1)
    return (return_state ? (M,data) : data)
  else
    # Generate a set of prepared input state to the channel
    preps = randompreparations(N,nshots,inputstates=inputstates,
                               n_distinctstates = n_distinctstates)
    # Generate data using circuit MPO (noiseless) or Choi matrix (noisy)
    if build_process
      # Get unitary MPO / Choi matrix
      M = runcircuit(N,gates;process=true,noise=noise, cutoff=cutoff,maxdim=maxdim,kwargs...)
      for n in 1:nshots
        M′= (isnothing(noise) ? projectunitary(M,preps[n,:]) : projectchoi(M,preps[n,:]))
        meas_gates = measurementgates(bases[n,:])
        M_meas = runcircuit(M′,meas_gates)
        measurement = getsamples!(M_meas;p1given0=p1given0,p0given1=p0given1)
        data[n,:] =  convertdatapoint(measurement,bases[n,:])
      end
      return (return_state ? (M ,preps, data) : (preps,data))
    
    # Generate data with full state evolution
    else
      # Initialize state and indices
      ψ0 = qubits(N)
      # Pre-compile quantum channel
      gate_tensors = compilecircuit(ψ0,gates; noise=noise, kwargs...)
      for n in 1:nshots
        data[n,:] = getsamples(ψ0,gate_tensors,preps[n,:],bases[n,:];
                                noise=noise,choi=false,maxdim=maxdim,cutoff=cutoff, 
                                p1given0=p1given0,p0given1=p0given1,
                                kwargs...)
      end
      return (preps,data) 
    end
  end
end


"""
    convertdatapoint(datapoint::Array,basis::Array;state::Bool=false)

Convert a data point from (sample,basis) -> data
Ex: (0,1,0,0) (X,Z,Y,X) -> (X+,Z-,Y+,X+)
"""
function convertdatapoint(datapoint::Array,basis::Array;state::Bool=false)
  newdata = []
  for j in 1:length(datapoint)
    if basis[j] == "X"
      if datapoint[j] == 0
        dat = (state ? "stateX+" : "X+")
        push!(newdata,dat)
      else
        dat = (state ? "stateX-" : "X-")
        push!(newdata,dat)
      end
    elseif basis[j] == "Y"
      if datapoint[j] == 0
        dat = (state ? "stateY+" : "Y+")
        push!(newdata,dat)
      else
        dat = (state ? "stateY-" : "Y-")
        push!(newdata,dat)
      end
    elseif basis[j] == "Z"
      if datapoint[j] == 0
        dat = (state ? "stateZ+" : "Z+")
        push!(newdata,dat)
      else
        dat = (state ? "stateZ-" : "Z-")
        push!(newdata,dat)
      end
    end
  end
  return newdata
end

function convertdatapoints(datapoints::Array,bases::Array;state::Bool=false)
  newdata = Matrix{String}(undef, size(datapoints)[1],size(datapoints)[2]) 
  
  for n in 1:size(datapoints)[1]
    newdata[n,:] = convertdatapoint(datapoints[n,:],bases[n,:],state=state)
  end
  return newdata
end

