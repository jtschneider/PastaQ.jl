using PastaQ
using ITensors
using Test
using Random
using Printf
using Zygote: Zygote


#function isingmodel(N::Int)
#  # generate the hamiltonian MPO
#  sites = siteinds("Qubit",N)
#  ampo = AutoMPO()
#  
#  # loop over the pauli operators
#  for j in 1:N-1
#    ampo .+= -1.0,"Z",j,"Z",j+1 
#    ampo .+= -1.0,"X",j
#  end
#  ampo .+= -1.0,"X",N
#  H = MPO(ampo,sites)
#  
#  # find ground state with DMRG
#  mps = randomMPS(sites)
#  sweeps = Sweeps(10)
#  maxdim!(sweeps, 10,20,30,50,100)
#  cutoff!(sweeps, 1E-10)
#  E0, mps = dmrg(H, mps, sweeps, outputlevel = 0);
#  return H,mps  
#end

@testset "Control field gradients" begin
 
  f(p, t) = p[1] * cos(p[2] * t) + p[3] * sin(p[4] * t);
  x = [1.2,0.1,2.0,0.3];
  T = 0.01

  gs = Zygote.gradient(Zygote.Params([x])) do
    f(x, T)
  end
  
  alg_grads = gs[x]
  ϵ = 1e-5
  for i in 1:4
    x[i] += ϵ
    fp = f(x,T)
    x[i] -= 2*ϵ
    fm = f(x,T)
    x[i] += ϵ
    numgrad = (fp-fm)/(2*ϵ)
    @test numgrad ≈ alg_grads[i] atol = 1e-8
  end
end



@testset "OCC-parameters gradients: single state, single drive on single mode" begin
  Random.seed!(1234)
  N = 3
  sites = qubits(N) 
  
  B = 0.5
  H = OpSum()
  # loop over the pauli operators
  for j in 1:N-1
    H += -1.0,"ZZ",(j,j+1)
    H += -B,"X",j
  end 
  H += -B,"X",N
  
  T   = 1.0
  δt  = 0.1 

  f(t, θ) = θ[1] * cos(t) + θ[2] * cos(2.0 * t)
  θ₀ = [1.011,1.155]

  ts = 0.0:δt:T
  drive = [f,θ₀] => ("Z",2)
  Hts = [PastaQ._drivinghamiltonian(H, drive, t) for t in ts] 
  circuit = trottercircuit(Hts; ts =  ts) 
  
  ψ = productstate(sites)
  ϕ = normalize!(randomstate(sites))

  cmap = PastaQ.circuitmap(circuit)
  F, ∇alg = PastaQ.gradients(ψ, ϕ, circuit, drive, collect(ts), cmap)

  ψT = runcircuit(ψ, circuit)
  @test F ≈ fidelity(ψT, ϕ) atol = 1e-5

  ϵ = 1e-5
  for k in 1:length(θ₀)
    θ₀[k] += ϵ
    drive = [f,θ₀] => ("Z",2)
    Hts = [PastaQ._drivinghamiltonian(H, drive, t) for t in ts]
    circuit = trottercircuit(Hts; ts =  ts)
    ψT = runcircuit(ψ, circuit)
    F₊ = fidelity(ψT, ϕ)

    θ₀[k] -= 2 * ϵ
    drive = [f,θ₀] => ("Z",2)
    Hts = [PastaQ._drivinghamiltonian(H, drive, t) for t in ts]
    circuit = trottercircuit(Hts; ts =  ts)
    ψT = runcircuit(ψ, circuit)
    F₋ = fidelity(ψT, ϕ)

    θ₀[k] += ϵ
    ∇num = (F₊ - F₋) / (2*ϵ)
    @test ∇num ≈ ∇alg[1][k]
  end
end



@testset "OCC-parameters gradients: single state, single drive on many modes" begin
  Random.seed!(1234)
  N = 3
  sites = qubits(N) 
  
  B = 0.5
  H = OpSum()
  # loop over the pauli operators
  for j in 1:N-1
    H += -1.0,"ZZ",(j,j+1)
    H += -B,"X",j
  end 
  H += -B,"X",N
  
  T   = 1.0
  δt  = 0.1 

  f(t, θ) = θ[1] * cos(t) + θ[2] * cos(2.0 * t)
  θ₀ = [1.011,1.155]

  ts = 0.0:δt:T
  drives = [f,θ₀] => [("Z",j) for j in 1:N]
  Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts] 
  circuit = trottercircuit(Hts; ts =  ts) 
  
  ψ = productstate(sites)
  ϕ = normalize!(randomstate(sites))

  cmap = PastaQ.circuitmap(circuit)
  F, ∇alg = PastaQ.gradients(ψ, ϕ, circuit, drives, collect(ts), cmap)

  ψT = runcircuit(ψ, circuit)
  @test F ≈ fidelity(ψT, ϕ) atol = 1e-5

  ϵ = 1e-5
  for k in 1:length(θ₀)
    θ₀[k] += ϵ
    drives = [f,θ₀] => [("Z",j) for j in 1:N]
    Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
    circuit = trottercircuit(Hts; ts =  ts)
    ψT = runcircuit(ψ, circuit)
    F₊ = fidelity(ψT, ϕ)

    θ₀[k] -= 2 * ϵ
    drives = [f,θ₀] => [("Z",j) for j in 1:N]
    Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
    circuit = trottercircuit(Hts; ts =  ts)
    ψT = runcircuit(ψ, circuit)
    F₋ = fidelity(ψT, ϕ)

    θ₀[k] += ϵ
    ∇num = (F₊ - F₋) / (2*ϵ)
    @test ∇num ≈ ∇alg[1][k]
  end
end


@testset "OCC-parameters gradients: single state, many drives on many modes" begin

  Random.seed!(1234)
  N = 3
  sites = qubits(N) 
  
  B = 0.5
  H = OpSum()
  # loop over the pauli operators
  for j in 1:N-1
    H += -1.0,"ZZ",(j,j+1)
    H += -B,"X",j
  end 
  H += -B,"X",N
  
  T   = 1.0
  δt  = 0.1 

  f1(t, θ) = θ[1] * cos(t)   + θ[2] * cos(2.0 * t)
  f2(t, θ) = θ[1] * cos(t/2) + θ[2] * cos(3.0 * t)
  f3(t, θ) = θ[1] * cos(t/3) + θ[2] * cos(4.0 * t)

  θ1 = [1.011,1.155]
  θ2 = [1.22,0.98]
  θ3 = [0.88,1.3]
  θ = [θ1,θ2,θ3]
  

  ts = 0.0:δt:T
  drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
  
  Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts] 
  circuit = trottercircuit(Hts; ts =  ts) 
  
  ψ = productstate(sites)
  ϕ = normalize!(randomstate(sites))

  cmap = PastaQ.circuitmap(circuit)
  F, ∇alg = PastaQ.gradients(ψ, ϕ, circuit, drives, collect(ts), cmap)

  ψT = runcircuit(ψ, circuit)
  @test F ≈ fidelity(ψT, ϕ) atol = 1e-5

  ϵ = 1e-5
  for i in 1:length(drives)
    for k in 1:length(θ[i])
      θ[i][k] += ϵ
      drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
      Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
      circuit = trottercircuit(Hts; ts =  ts)
      ψT = runcircuit(ψ, circuit)
      F₊ = fidelity(ψT, ϕ)

      θ[i][k] -= 2 * ϵ
      drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
      Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
      circuit = trottercircuit(Hts; ts =  ts)
      ψT = runcircuit(ψ, circuit)
      F₋ = fidelity(ψT, ϕ)

      θ[i][k] += ϵ
      ∇num = (F₊ - F₋) / (2*ϵ)
      @test ∇num ≈ ∇alg[i][k]
    end
  end
end



@testset "OCC-parameters gradients: many states, many drives on many modes" begin

  Random.seed!(1234)
  N = 3
  sites = qubits(N) 
  
  B = 0.5
  H = OpSum()
  # loop over the pauli operators
  for j in 1:N-1
    H += -1.0,"ZZ",(j,j+1)
    H += -B,"X",j
  end 
  H += -B,"X",N
  
  T   = 1.0
  δt  = 0.1 

  f1(t, θ) = θ[1] * cos(t)   + θ[2] * cos(2.0 * t)
  f2(t, θ) = θ[1] * cos(t/2) + θ[2] * cos(3.0 * t)
  f3(t, θ) = θ[1] * cos(t/3) + θ[2] * cos(4.0 * t)

  θ1 = [1.011,1.155]
  θ2 = [1.22,0.98]
  θ3 = [0.88,1.3]
  θ = [θ1,θ2,θ3]
  

  ts = 0.0:δt:T
  drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
  
  Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts] 
  circuit = trottercircuit(Hts; ts =  ts) 
  
  
  ψs      = [productstate(sites)]
  push!(ψs, runcircuit(ψs[1], ("X",1)))
  push!(ψs, runcircuit(ψs[1], ("X",2)))
  push!(ψs, runcircuit(ψs[1], ("X",3)))
  ϕs = [normalize!(randomstate(sites)) for j in 1:length(ψs)]

  cmap = PastaQ.circuitmap(circuit)

  F, ∇alg = PastaQ.gradients(ψs, ϕs, circuit, drives, collect(ts), cmap)


  function _cost(ψs, ϕs, circuit)
    O = 0.0
    for j in 1:length(ψs)
      ψ = runcircuit(ψs[j], circuit)
      O += inner(ψ, ϕs[j]) / length(ψs)
    end
    return O * conj(O)
  end
  @test F ≈ _cost(ψs, ϕs, circuit)

  ϵ = 1e-5
  for i in 1:length(drives)
    for k in 1:length(θ[i])
      θ[i][k] += ϵ
      drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
      Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
      circuit = trottercircuit(Hts; ts =  ts)
      F₊ = _cost(ψs, ϕs, circuit)

      θ[i][k] -= 2 * ϵ
      drives = [[f1,θ[1]] => ("Z",1), [f2,θ[2]] => ("Z",2), [f3,θ[3]] => ("Z",3)]
      Hts = [PastaQ._drivinghamiltonian(H, drives, t) for t in ts]
      circuit = trottercircuit(Hts; ts =  ts)
      F₋ = _cost(ψs, ϕs, circuit)

      θ[i][k] += ϵ
      ∇num = (F₊ - F₋) / (2*ϵ)
      @test ∇num ≈ ∇alg[i][k] atol = 1e-5
    end
  end
end

