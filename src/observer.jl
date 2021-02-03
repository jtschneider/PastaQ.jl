"""
Observer is an implementation of an
observer object (<:AbstractObserver) which
implements custom measurements to perform
at each layer of the circuit evolution.
"""
struct Observer <: AbstractObserver
  measurements::Dict{String, Pair{<:Union{Nothing,Function, String, Tuple},<:Any}}
end

Observer() = Observer(Dict{String, Pair{<:Union{Nothing,Function, String, Tuple},<:Any}}())

measurement(observer::Observer, observable::String) = first(observer.measurements[observable])
results(observer::Observer, observable::String) = last(observer.measurements[observable])

"""
    CircuitObserver(observables::Dict{String, <:Any})

Generate an observer given a list of measurements passed as a dictionary. 
"""
function Observer(observables::Dict{String, <:Any})
  measurements = Dict{String, Pair{<:Union{Nothing,Function, String, Tuple},<:Any}}()
  for observable in keys(observables)
    measurements[observable] = observables[observable] => []
  end
  return Observer(measurements)
end

Observer(measurement::Pair{String,<:Any}) = 
  Observer([measurement])

Observer(measurements::Vector{<:Pair{String,<:Any}}) =  
  Observer(Dict(measurements))

function Observer(observables::Vector{<:Any})
  measurements = Dict{String, Pair{<:Union{Nothing,Function, String, Tuple},<:Any}}()
  for observable in observables
    name = measurement_name(observable)
    measurements[name] = (observable isa Pair{<:String, Any} ? last(observable) : observable) => []
  end
  return Observer(measurements)
end

Observer(measurement::Union{String,Tuple,Function}) = 
  Observer([measurement])

function Base.push!(observer::Observer, observable::Pair{String, <:Any})
  observer.measurements[first(observable)] = last(observable) => []
  return observer
end

function Base.push!(observer::Observer, observable::Union{String,Tuple,<:Function})
  name = measurement_name(observable)
  observer.measurements[name] = (observable isa Pair{String, <:Any} ? last(observable) : observable) => []
  return observer
end


measurement_name(measurement::String) = 
  measurement

measurement_name(measurement::Tuple) = 
  prod(ntuple(n -> measurement[n] isa AbstractString ? measurement[n] : "("*string(measurement[n])*")", length(measurement)))

measurement_name(measurement::Pair{String, <:Any}) = 
  first(measurement)

measurement_name(measurement::Function) = 
  string(measurement)

measurement_name(measurement::Pair{<:Function,<:Union{Any,Tuple{<:Any}}}) = 
  string(first(measurement))  

has_customfunctions(observer::Observer) = 
  any(x -> isa(x,Function), values(observer.measurements))


#function measure!(observer::Observer, M::Union{MPS,MPO}, ref_indices::Vector{<:Index})
function measure!(observer::Observer, L::LPDO, ref_indices::Vector{<:Index})
  
  M = (L.purifier_tag == ts"" ? L.X : L)
  
  for measurement in keys(observer.measurements)
    observable = first(observer.measurements[measurement])
    if observable isa Function
      res = first(observer.measurements[measurement])(M)
    elseif !isnothing(observable)
      res = measure(M, first(observer.measurements[measurement]), ref_indices)
    end
    if !isnothing(observable)
      push!(observer.measurements[measurement][2], res)
    end
  end
end

measure!(observer::Observer, ψ::MPS, args...) = 
  measure!(observer, LPDO(ψ), args...)

measure!(observer::Observer, L::LPDO) = #::Union{MPS,MPO,LPDO}) = 
  measure!(observer, L, hilbertspace(L))

Base.copy(observer::Observer) = Observer(copy(observer.measurements)) 

###function save(observer::Observer, output_path::String)
###  h5rewrite(output_path) do file
###    write(file,"results", observer.results["parameters"])
###  end
###end
###
###
###
