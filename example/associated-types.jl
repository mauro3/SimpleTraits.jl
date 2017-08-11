using SimpleTraits

# This is a trait of one type `Ar` with two associated types `T,N`:
@traitdef LikeArray{T,N}(Ar)
# NOTE: the syntax change: before the types in question where in the curly
# brackets and there where no associated types.  Now the type in question is `(Ar)`.

# Sure all Arrays are like arrays:
@traitimpl LikeArray{T,N}(Array{T,N}) where {T,N}
# Note that the trait has the T,N parameters just like Array.

abstract type MAbs end
struct MyType{O,U,N,T} <: MAbs
    o::O
    u::U
    ar::Array{T,N}
end
# Implement array interface...

# add it to trait:
@traitimpl LikeArray{T,N}(MyType{O,U,N,T}) where {O,U,N,T}
# Note how the MyType parameters get mapped onto the associated types

# use it
import Base: eltype, ndims
@traitfn ndims{T,N}(::::LikeArray{T,N}) = (println("Hi"); N)
ndims(MyType(4,5,[3])) # => "Hi" 1
ndims(MyType(4,5,rand(1,1))) # => "Hi" 2
ndims([1]) # => 1 (this does not go via the trait function as normal dispatch
           #       takes presendce)

@traitfn eltype{T}(::::LikeArray{T}) = T
eltype(MyType(4,5,[3])) # => Int
eltype(MyType(4,5,rand(1,1))) # => Float64
eltype([1]) # => Int

@traitfn two_dim_only{T}(::::LikeArray{T,2}) = "I have ndim==2"
@traitfn two_dim_only{T}(::::(!LikeArray{T,2})) = "I have ndim!=2"

two_dim_only(rand(2,2)) # => "I have ndim==2"
# this sadly doesn't work, needs some more thoughs:
two_dim_only(MyType(4,5,[3])) # => error

## Buggy: fix
# # of course you can use it without the parameters:
# @traitfn dont_care_about_parameters(::::LikeArray) = 1
# dont_care_about_parameters([1]) # => 1