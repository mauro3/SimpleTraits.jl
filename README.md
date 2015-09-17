# SimpleTraits

[![Build Status](https://travis-ci.org/mauro3/SimpleTraits.jl.svg?branch=master)](https://travis-ci.org/mauro3/SimpleTraits.jl)

Note that Julia 0.3 is only supported up to tag
[v0.0.1](https://github.com/mauro3/SimpleTraits.jl/tree/v0.0.1).

This attempts to reduce the complexity of
[Traits.jl](https://github.com/mauro3/Traits.jl), but at the same time
staying compatible.  On the upside, it also works for Julia-0.3.  It
drops support for:

- Trait definition in terms of methods and constraints.  Instead the
  user needs to assign types to traits manually.  This removes the
  most complex part of Traits.jl, the checking whether a type
  satisfies a trait definition.
- trait functions which dispatch on more than one trait.  This allows
  to remove the need for generated functions, as well as removing the
  rules for trait-dispatch.

The reason for splitting this away from Traits.jl are:

- creating a more reliable and easier to maintain package than
  Traits.jl
- exploring inclusion in Base

My [*JuliaCon 2015*](https://youtu.be/j9w8oHfG1Ic) talk gives a 10
minute introduction to Traits.jl and SimpleTraits.jl.

# Manual

Traits are defined with:
```julia
@traitdef Tr1{X}
@traitdef Tr2{X,Y}
```
then add types to the traits with
```julia
@traitimpl Tr1{Int}
@traitimpl Tr2{Int,String}
```

Functions which dispatch on traits are constructed like:
```julia
@traitfn f{X; Tr1{X}}(x::X) = 1 
@traitfn f{X; !Tr1{X}}(x::X) = 2
```
This means that a type `X` which is part of the trait `Tr1` will
dispatch to the method returning `1`, otherwise 2.
```julia
@test f(5)==1
@test f(5.)==2
```

Similarly for `Tr2`:
```julia
@traitfn f{X,Y; Tr2{X,Y}}(x::X,y::Y,z) = 1
@test f(5, "b", "a")==1
@test_throws MethodError f(5,5, "a")==2
@traitfn f{X,Y; !Tr2{X,Y}}(x::X,y::Y,z) = 2
@test f(5, 5, "a")==2
```

Note that for one generic function, dispatch on traits can only work
on one trait for a given signature.  Continuing above example, this
does not work as one may expect:
```julia
@traitfn f{X; !Tr2{X,X}}(x::X) = 10
```
as this definition will just overwrite the definition `@traitfn f{X;
Tr1{X}}(x::X) = 1` from above.  If you need to dispatch on several
traits, then you need Traits.jl.

## Advanced features

Instead of using `@traitimpl` to add types to traits, it can be
programmed.  Running `@traitimpl Tr1{Int}` essentially expands to
```julia
SimpleTraits.trait{X1 <: Int}(::Type{Tr1{X1}}) = Tr1{X1}
```
i.e. it is just the identity function.  So instead of using `@traitimpl` this
can be coded directly.  Note that anything but a constant function
will probably not be inlined away by the JIT and will lead to slower
dynamic dispatch.

Example leading to dynamic dispatch:
```julia
@traitdef IsBits{X}
SimpleTraits.trait{X1}(::Type{IsBits{X1}}) = isbits(X1) ? IsBits{X1} : Not{IsBits{X1}}
istrait(IsBits{Int}) # true
istrait(IsBits{Array{Int,1}}) # false
immutable A
    a::Int
end
istrait(IsBits{A}) # true
```

In Julia-0.4 dynamic dispatch can be avoided using a generated
function:
```julia
@traitdef IsBits{X}
@generated function SimpleTraits.trait{X1}(::Type{IsBits{X1}})
    isbits(X1) ? :(IsBits{X1}) : :(Not{IsBits{X1}})
end
```

Note that this programmed-traits can be combined with `@traitimpl`.

# Base Traits

I started putting some Julia-Base traits together which can be loaded
with `using SimpleTraits.BaseTraits`, see the source for all
definitions.

Example, dispatch on whether an argument is immutable or not:

```julia
@traitfn f{X; IsImmutable{X}}(x::X) = X(x.fld+1) # make a new instance
@traitfn f{X; !IsImmutable{X}}(x::X) = (x.fld += 1; x) # update in-place

# use
type A; fld end
immutable B; fld end
a=A(1)
f(a) # in-place
@assert a.fld == A(2).fld

b=B(1) # out of place
b2 = f(b)
@assert b==B(1)
@assert b2==B(2)
```


# References

- [Traits.jl](https://github.com/mauro3/Traits.jl) and its references.
  In particular
  [here](https://github.com/mauro3/Traits.jl#dispatch-on-traits) is an
  in-depth discussion on limitations of Holy-Traits, which this
  package is essentially a wrapper around.

# To ponder

- Could type inheritance be used for sub-traits
  ([Jutho's idea](https://github.com/JuliaLang/julia/issues/10889#issuecomment-94317470))?
  In particular could it be used in such a way that it is compatible
  with the multiple inheritance used in Traits.jl?
- the current `@traitfn` cannot be used with `@generated`
