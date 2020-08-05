using PastaQ
using ITensors
using Test
using Random

@testset "circuits: hadamardlayer" begin
  N = 5
  gates = []
  hadamardlayer!(gates,N)
  @test length(gates) == N
  for j in 1:N
    @test gates[j] isa Tuple{String,Int64}
    @test gates[j][1] == "H"
    @test gates[j][2] == j
  end
end

@testset "circuits: rand1Qrotationlayer" begin
  N = 5
  gates = []
  rand1Qrotationlayer!(gates,N)
  @test length(gates) == N
  for j in 1:N
    @test typeof(gates[j]) == Tuple{String,Int64,NamedTuple{(:θ, :ϕ, :λ),
                                    Tuple{Float64,Float64,Float64}}}
    @test gates[j][1] == "Rn"
    @test gates[j][2] == j
    @test 0 ≤ gates[j][3].θ ≤ π
    @test 0 ≤ gates[j][3].ϕ ≤ 2π
    @test 0 ≤ gates[j][3].λ ≤ 2π
  end
  
  rng = MersenneTwister(1234)  
  gates = []
  rand1Qrotationlayer!(gates,N,rng=rng)
  @test length(gates) == N
  for j in 1:N
    @test typeof(gates[j]) == Tuple{String,Int64,NamedTuple{(:θ, :ϕ, :λ),
                                    Tuple{Float64,Float64,Float64}}}
    @test gates[j][1] == "Rn"
    @test gates[j][2] == j
    @test 0 ≤ gates[j][3].θ ≤ π
    @test 0 ≤ gates[j][3].ϕ ≤ 2π
    @test 0 ≤ gates[j][3].λ ≤ 2π
  end
end

@testset "circuits: CX layer" begin
  N = 8
  gates = []
  CXlayer!(gates,N,sequence="odd")
  @test length(gates) == N ÷ 2
  for j in 1:length(gates)
    @test typeof(gates[j]) == Tuple{String,Tuple{Int64,Int64}}
    @test gates[j][1] == "CX"
    @test gates[j][2] == (2*j-1,2*j) 
  end
  gates = []
  CXlayer!(gates,N,sequence="even")
  @test length(gates) == (N ÷ 2) - 1
  for j in 1:length(gates)
    @test typeof(gates[j]) == Tuple{String,Tuple{Int64,Int64}}
    @test gates[j][1] == "CX"
    @test gates[j][2] == (2*j,2*j+1) 
  end
  
  N = 9
  gates = []
  CXlayer!(gates,N,sequence="odd")
  @test length(gates) == N ÷ 2
  for j in 1:length(gates)
    @test typeof(gates[j]) == Tuple{String,Tuple{Int64,Int64}}
    @test gates[j][1] == "CX"
    @test gates[j][2] == (2*j-1,2*j) 
  end
  gates = []
  CXlayer!(gates,N,sequence="even")
  @test length(gates) == (N ÷ 2) 
  for j in 1:length(gates)
    @test typeof(gates[j]) == Tuple{String,Tuple{Int64,Int64}}
    @test gates[j][1] == "CX"
    @test gates[j][2] == (2*j,2*j+1) 
  end
end