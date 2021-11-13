function partial_contraction(ψ::MPS, ϕ::MPS)
  T = ITensor(1)
  for n in 1:length(ψ)
    T = T * ψ[n] * ϕ[n]
  end
  return T
end

function inner_circuit(ϕ::ITensor, U::Vector{ITensor}, ψ::ITensor)
  Uψ = ψ
  for u in U
    s = commoninds(u, Uψ)
    s′ = s'
    Uψ = replaceinds(u * Uψ, s′ => s)
  end
  return (dag(ϕ) * Uψ)[]
end

function inner_circuit(ϕ::MPS, U::Vector{ITensor}, ψ::MPS; kwargs...)
  Uψ = runcircuit(ψ, U; kwargs...)
  return inner(ϕ, Uψ)
end

inner_circuit(ϕ::MPS, U::Vector{ITensor}, ψ::MPS, cmap::Vector; kwargs...) = 
  inner_circuit(ϕ, U, ψ; kwargs...)


function rrule(::typeof(inner_circuit), ϕ::MPS, U::Vector{ITensor}, ψ::MPS; kwargs...)
  Udag = reverse([dag(swapprime(u, 0=>1)) for u in U])
  ξl = runcircuit(ϕ, Udag; kwargs...) 
  y = inner(ξl, ψ)
  function inner_circuit_pullback(ȳ)
    ∇⃗ = ITensor[]
    ξr = copy(ψ)
    for u in U
      ξl = apply(u, ξl; move_sites_back = true, kwargs...)   
      ξl = prime(ξl, inds(u, plev = 0))
      ∇⃗ = vcat(∇⃗, partial_contraction(ξl, dag(ξr)))
      noprime!(ξl)
      ξr = apply(u, ξr; move_sites_back = true, kwargs...)
    end
    return (NoTangent(), NoTangent(), ȳ .* ∇⃗, NoTangent())
  end
  return y, inner_circuit_pullback
end


function rrule(::typeof(inner_circuit), ϕ::MPS, U::Vector{ITensor}, ψ::MPS, cmap::Vector; kwargs...)
  Udag = reverse([dag(swapprime(u, 0=>1)) for u in U])
  ξl = runcircuit(ϕ, Udag; kwargs...) 
  y = inner(ξl, ψ)
  function inner_circuit_pullback(ȳ)
    ∇⃗ = ITensor[]
    ξr = copy(ψ)
    gcnt = 1
    for gloc in cmap
      zero_tensors = [ITensors.itensor(zeros(size(U[k])),inds(U[k])) for k in gcnt:gloc-1]
      ∇⃗ = vcat(∇⃗, zero_tensors)
      ξl = apply(U[gcnt:gloc], ξl; move_sites_back = true, kwargs...) 
      ξl = prime(ξl, inds(U[gloc], plev = 0))
      if gcnt == 1
        ξr = apply(U[gcnt:gloc-1], ξr; move_sites_back = true, kwargs...)
      else
        ξr = apply(U[gcnt-1:gloc-1], ξr; move_sites_back = true, kwargs...)
      end
      ∇⃗ = vcat(∇⃗, partial_contraction(ξl, dag(ξr)))
      noprime!(ξl)
      gcnt = gloc+1
    end
    ∇⃗ = vcat(∇⃗, U[gcnt:end])
    return (NoTangent(), NoTangent(), ȳ .* ∇⃗, NoTangent(), NoTangent())
  end
  return y, inner_circuit_pullback
end




# XXX: For some reason Zygote needs these definitions?
Base.reverse(z::ZeroTangent) = z
Base.adjoint(::Tuple{Nothing}) = nothing
Base.adjoint(::Tuple{Nothing,Nothing}) = nothing
(::ProjectTo{NoTangent})(::Nothing) = nothing

# XXX Zygote: Delete once OpSum rules are better defined
Base.:+(::Base.RefValue{Any}, g::NamedTuple{(:data,), Tuple{Vector{NamedTuple{(:coef, :ops), Tuple{ComplexF64, Nothing}}}}}) = g



#function rrule(::typeof(inner_circuit), ϕ::MPS, U::Vector{ITensor}, ψ::MPS; kwargs...)
#  y = inner_circuit(ϕ, U, ψ) 
#  function inner_circuit_pullback(ȳ)
#    # build the environments
#    ξr = Vector{MPS}(undef, length(U))
#    ξr[1] = copy(ψ)
#    for i in 1:length(U)-1
#      u = U[i]
#      ξ = apply(u, ξr[i]; move_sites_back = true, kwargs...)
#      ξr[i+1] = ξ
#    end
#
#    ξl = Vector{MPS}(undef, length(U))
#    ξl[end] = copy(ϕ)
#    for i in reverse(1:length(U)-1)
#      udag = dag(swapprime(U[i+1], 0=>1))
#      ξl[i] = apply(udag, ξl[i+1]; move_sites_back = true, kwargs...)
#    end
#    #∇⃗ = [prod(ξl[1])' * prod(ξr[1])]
#    ∇⃗ = ITensor[]
#    for i in 1:length(U)
#      x  = inds(U[i], plev = 0)
#      ξl[i] = prime(ξl[i],x)
#      ∇ = ITensor(1)
#      for n in 1:length(ψ)
#        # TODO: figure out the dag
#        ∇ = ∇ * ξl[i][n] * dag(ξr[i][n])
#        #∇ = ∇ * dag(ξl[i][n]) * ξr[i][n]
#      end
#      ∇⃗ = vcat(∇⃗, ∇)
#    end
#    return (NoTangent(), NoTangent(), ȳ .* ∇⃗, NoTangent())
#  end
#  return y, inner_circuit_pullback
#end
#

