# SimpleTraits

[![Build Status](https://travis-ci.org/mauro3/SimpleTraits.jl.svg?branch=master)](https://travis-ci.org/mauro3/SimpleTraits.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/mauro3/SimpleTraits.jl?branch=master&svg=true)](https://ci.appveyor.com/project/mauro3/simpletraits-jl/branch/master)
[NEWS](NEWS.md)

[![SimpleTraits](http://pkg.julialang.org/badges/SimpleTraits_0.6.svg)](http://pkg.julialang.org/?pkg=SimpleTraits)
[![SimpleTraits](http://pkg.julialang.org/badges/SimpleTraits_0.7.svg)](http://pkg.julialang.org/detail/SimpleTraits)

This package provides a macro-based implementation of traits, using
[Tim Holy's trait trick](https://github.com/JuliaLang/julia/issues/2345#issuecomment-54537633).
The main idea behind traits is to group types outside the
type-hierarchy and to make dispatch work with that grouping.  The
difference to Union-types is that types can be added to a trait after
the creation of the trait, whereas Union types are fixed after
creation.  The cool thing about Tim's trick is that there is no
performance impact compared to using ordinary dispatch.  For a bit of
background and a quick introduction to traits watch my 10min
[JuliaCon 2015](https://youtu.be/j9w8oHfG1Ic) talk.

One good example of the use of traits is the
[abstract array interface](https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-array-1)
in Julia-Base.  An abstract array either belongs to the
`Base.IndexLinear` or `Base.IndexCartesian` trait, depending on how its
internal indexing works.  The advantage to use a trait there is that
one is free to create a type hierarchy independent of this particular
"trait" of the array(s).

Tim Holy
[endorses](https://github.com/mauro3/SimpleTraits.jl/pull/6#issuecomment-236886253)
SimpleTraits, a bit: "I'd say that compared to manually writing out
the trait-dispatch, the "win" is not enormous, but it is a little
nicer."  I suspect that — if you don't write Holy-traits before
breakfast — your "win" should be greater ;-)

# Manual

**Note for Julia-0.6:**  Below examples for `@traitfn` (using `where`-function
  syntax) only work on Julia-0.7 or higher, for Julia-0.6 this syntax cannot be
  not supported.
  For Julia-0.6, see the README of the
  SimpleTraits version
  [v0.6.0](https://github.com/mauro3/SimpleTraits.jl/tree/v0.6.0) instead.

Traits are defined with `@traitdef`:
```julia
using SimpleTraits
@traitdef IsNice{X}
@traitdef BelongTogether{X,Y} # traits can have several parameters
```
All traits have one or more (type-)parameters to specify the type to
which the trait is applied.  For instance `IsNice{Int}` signifies that
`Int` is a member of `IsNice` (although whether that is true needs to be
checked with the `istrait` function).  Most traits will be
one-parameter traits, however, several parameters are useful when
there is a "contract" between several types.

As a *style convention*, I suggest to use trait names which start with
a verb, as above two traits.  This makes distinguishing between traits
and types easier as type names are usually nouns.

Add types to a trait-group with `@traitimpl`:
```julia
@traitimpl IsNice{Int}
@traitimpl BelongTogether{Int,String}
```
If there is a function which tests whether a trait is fulfilled then
it can be used like so:
```julia
@traitimpl IsNice{X} <- isnice(X)
isnice(X) = false # set default
```

i.e. any type `X` for which `isnice(X)==true` belongs to `IsNice`.
Notes:

- overhead-less  (static) dispatch
  is only possible if `isnice` is *pure*: "[A pure method]
  promises that the result will always be the same constant regardless
  of when the method is called [for the same input arguments]."
  ([ref](https://github.com/mauro3/SimpleTraits.jl/pull/39#issuecomment-293629338)).
- Last note that in above example the `@traitimpl
  IsNice{Int}` "wins" over the `@traitimpl IsNice{X} <- isnice(X)`, thus
  this can be used to define exceptions to a rule.

It can be checked whether a type belongs to a trait with `istrait`:
```julia
using Test
@test istrait(IsNice{Int})
@test !istrait(BelongTogether{Int,Int}) # only BelongTogether{Int,String} was added above
```

Functions which dispatch on traits are constructed like:
```julia
@traitfn f(x::X) where {X; IsNice{X}} = "Very nice!"
@traitfn f(x::X) where {X; !IsNice{X}} = "Not so nice!"
```
This means that a type `X` which is part of the trait `IsNice` will
dispatch to the method returning `"Very nice!"`, otherwise to the one
returning `"Not so nice!"`:
```julia
@test f(5)=="Very nice!"
@test f(5.)=="Not so nice!"
```
Note that calling a trait-function is just like calling any other
function.  Thus there is no extra mental gymnastics required for a
"user" of a trait-based package.

Similarly for `BelongTogether` which has two parameters:
```julia
@traitfn f(x::X,y::Y) where {X,Y; BelongTogether{X,Y}} = "$x and $y forever!"
@test f(5, "b")=="5 and b forever!"
@test_throws MethodError f(5, 5)

@traitfn f(x::X,y::Y) where {X,Y; !BelongTogether{X,Y}} = "$x and $y cannot stand each other!"
@test f(5, 5)=="5 and 5 cannot stand each other!"
```

## [Traitor.jl](https://github.com/andyferris/Traitor.jl)-like syntax

At JuliaCon 2016 folks suggested an alternate, more compact syntax for
trait-functions.  However, it only works for single parameter traits.
SimpleTraits now supports this.  Above function `f` can be written as:

```julia
@traitfn ft(x::::IsNice) = "Very nice!"
@traitfn ft(x::::(!IsNice)) = "Not so nice!"
```
Note that the parenthesis are needed with negated traits, otherwise a
parser error is thrown.

## Vararg, default argument and keyword argument trait functions

Vararg, default argument and keyword argument trait functions work.
However, with keyword arguments the trait function and negated trait
function need both have the same keywords (however different values
are allowed). Example:

```julia
@traitfn kwfn(x::::Tr1, y...; kw=1) = x+y[1]+kw
@traitfn kwfn(x::::(!Tr1), y...; kw=2) = x+y[1]+kw
```

For default arguments the rule is slightly different: with default
arguments the trait function and negated trait function need both have
the same default-argument with the *same values*.

```julia
@traitfn deff(x::::Tr1, y=1) = x+y
@traitfn deff(x::::(!Tr1), y=1) = x+y
```

## Method overwritten warnings

Warnings are issued when methods are overwritten.  Due
to Tim's trick the `@traitfn` needs to create two functions the first
time it is used for a particular method (see next section for an
explanation).  But when defining the opposite trait, then better only
one method is created or else the warning appears.  Some heuristics to
avoid the warnings are in-place to check whether a method is defined
yet or not but they fail at times (see issue
[#7](https://github.com/mauro3/SimpleTraits.jl/issues/7)).  Long story
short: define the two methods of a trait and its negation using the
same argument names and no warning should be issued.  Although note
that the warnings are harmless.

# Details of method dispatch

Defining a trait function adds: one new method (or overwrites one) to
the generic function, which contains the logic; and one helper
method to do the dispatch (Tim's trick), if it has not been defined
before.

When calling a generic function which has some *trait-methods*,
dispatch will first work on the types as normal.  If the selected
method is a trait-method then trait dispatch will kick in too.
Example:
```julia
@traitdef Tr{X}

fn(x::Integer) = 1 # a normal method
@traitfn fn(x::X) where {X<:AbstractFloat;  Tr{X}} = 2
@traitfn fn(x::X) where {X<:AbstractFloat; !Tr{X}} = 3

@traitimpl Tr{Float32}
@traitimpl Tr{Int} # this does not impact dispatch of `fn`

fn(5) # -> 1; dispatch only happens on the type
fn(Float32(5)) # -> 2; dispatch through traits
fn(Float64(5)) # -> 3; dispatch through traits
```

Further note that for a particular trait-method dispatch only works on
one trait.  Continuing above example, this *does not work* as one may
expect:
```julia
@traitdef Tr2{X}
@traitfn fn(x::X) where {X<:AbstractFloat; Tr2{X}} = 4

@traitimpl Tr2{Float16}
fn(Float16(5)) # -> 4; dispatch through traits
fn(Float32(5)) # -> MethodError; method defined in previous example
               #    was overwritten above
```
This last definition of `fn` just overwrites the definition `@traitfn
f(x::X) where {X; Tr{X}} = 2` from above.

If you need to dispatch on several traits in a single trait-method,
then you're out of luck.  But please voice your grievance over in pull
request [#2](https://github.com/mauro3/SimpleTraits.jl/pull/2).

### Performance

There is no performance impact compared to normal functions thanks to
Julia's clever design. Continuing the example from above and looking
at the native code
```julia
julia> @code_native fn(5)
        .text
Filename: REPL[3]
        pushq   %rbp
        movq    %rsp, %rbp
Source line: 1
        movl    $1, %eax
        popq    %rbp
        retq
        nopl    (%rax,%rax)

julia> @code_native fn(Float16(5))
        .text
Filename: SimpleTraits.jl
        pushq   %rbp
        movq    %rsp, %rbp
Source line: 185
        movl    $4, %eax
        popq    %rbp
        retq
        nopl    (%rax,%rax)
```
shows that the normal method and the trait-method compile down to the
same machine instructions.

However, if the trait-grouping function is not constant or a generated
function then dispatch may be dynamic.  This can be checked with
`@check_fast_traitdispatch`, which checks whether the number of lines
of LLVM code is the same for a trait function than a normal one:
```julia
# julia 0.6
checkfn(x) = rand()>0.5 ? true : false # a bit crazy!
@traitdef TestTr{X}
@traitimpl TestTr{X} <- checkfn(X)
# this tests a trait-function with TestTr{Int}:
@check_fast_traitdispatch TestTr
# this tests a trait-function with TestTr{String} and will
# also prints number of LLCM-IR lines of trait vs normal function:
@check_fast_traitdispatch TestTr String true

# Now this is fast:
@traitimpl TestTr{String}
@check_fast_traitdispatch TestTr String true
```


## Advanced features

The macros of the previous section are the official API of the package
and should be reasonably stable.  What follows in this section is
"under the hood" and may well be updated (but still signalled with
minor version changes).

Instead of using `@traitimpl` to add types to traits, it can be
programmed.  Running `@traitimpl IsNice{Int}` essentially expands to
```julia
SimpleTraits.trait(::Type{IsNice{X1}}) where {X1 <: Int} = IsNice{X1}
```
I.e. `trait` is the identity function for a fulfilled trait and
returns `Not{TraitInQuestion{...}}` otherwise (this is the fall-back
for `<:Any`).  So instead of using `@traitimpl` this can be coded
directly.  Note that anything but a constant function will probably
not be inlined away by the JIT and will lead to slower dynamic
dispatch (see `@check_fast_traitdispatch` for a helper to check).

Example leading to static dispatch (since Julia 0.6):
```julia
@traitdef IsBits{X}
SimpleTraits.trait(::Type{IsBits{X1}}) where {X1} = isbits(X1) ? IsBits{X1} : Not{IsBits{X1}}
istrait(IsBits{Int}) # true
istrait(IsBits{Array{Int,1}}) # false
struct A
    a::Int
end
istrait(IsBits{A}) # true
```

Dynamic dispatch can be avoided using a generated
function or *pure* functions (sometimes they need to be
annotated with `Base.@pure`):
```julia
@traitdef IsBits{X}
@generated function SimpleTraits.trait(::Type{IsBits{X1}}) where X1
    isbits(X1) ? :(IsBits{X1}) : :(Not{IsBits{X1}})
end
```
What is allowed in generated functions is heavily restricted, see
[Julia manual](https://docs.julialang.org/en/latest/manual/metaprogramming.html#Generated-functions-1).
In particular (in Julia 0.6), no methods which are defined after the
generated function are allowed to be called inside the generated
function, otherwise
[this](https://github.com/JuliaLang/julia/issues/21356) issue is
encountered.  Generally, try pure functions first and only in a pinch
generated functions.

Note that these programmed-traits can be combined with `@traitimpl IsBits{XYZ}`,
i.e. program the general case and add exceptions with `@traitimpl IsBits{XYZ}`.

Trait-inheritance can also be hand-coded with above trick.  For
instance, the trait given by (in pseudo syntax) `BeautyAndBeast{X,Y} <: IsNice{X},
!IsNice{Y}, BelongTogether{X,Y}`:
```julia
@traitdef BeautyAndBeast{X,Y}
function SimpleTraits.trait(::Type{BeautyAndBeast{X,Y}}) where {X,Y}
    if istrait(IsNice{X}) && !istrait(IsNice{Y}) && BelongTogether{X,Y}
        BeautyAndBeast{X,Y}
    else
        Not{BeautyAndBeast{X,Y}}
    end
end
```
Note that this will lead to slower, dynamic dispatch, as
the function is not pure (it depends on the global state of
which types belong to the traits `IsNice` and `BelongTogether`).  (In
Julia 0.5 one could use a generated function but not anymore in Julia 0.6.)


Note also that trait functions can be generated functions:
```julia
@traitfn @generated fg(x::X) where {X; IsNice{X}} = (println(x); :x)
```

# Innards

The function `macroexpand` shows the syntax transformations a macro
does. Here the edited output of running it for the macros of this package:
```julia
julia> macroexpand(:(@traitdef Tr{X}))

struct Tr{X} <: SimpleTraits.Trait
end

julia> macroexpand(:(@traitimpl Tr{Int}))

# this function does the grouping of types into traits:
SimpleTraits.trait(::Type{Tr{X1}}) where X1 <: Int = Tr{X1}
SimpleTraits.istrait(::Type{Tr{X1}}) where X1 <: Int = true # for convenience, really

julia> macroexpand(:(@traitfn g(x::X) where {X; Tr{X}}= x+1))

@inline g(x::X) where {X} = g(trait(Tr{X}), x) # this is Tim's trick, using above grouping-function
g(::Type{Tr{X}},x::X) where {X} = x + 1 # this is the logic

julia> macroexpand(:(@traitfn g(x::X) where {X; !Tr{X}}= x+1000))

# the trait dispatch helper function needn't be defined twice,
# only the logic:
g(::Type{ Not{Tr{X}} }, x::X) where {X} = x + 1000
```

For a detailed explanation of how Tim's trick works, see
[Traits.jl: Dispatch on traits](https://github.com/mauro3/Traits.jl#dispatch-on-traits).
The difference here is I make the methods containing the logic part of
the same generic function (there it's in `_f`).

# Base Traits

I started putting some Julia-Base traits together which can be loaded
with `using SimpleTraits.BaseTraits`, see the source for all
definitions.

Example, dispatch on whether an argument is immutable or not:

```julia
@traitfn f(x::X) where {X; IsImmutable{X}} = X(x.fld+1) # make a new instance
@traitfn f(x::X) where {X; !IsImmutable{X}} = (x.fld += 1; x) # update in-place

# use
mutable struct A; fld end
struct B; fld end
a=A(1)
f(a) # in-place
@assert a.fld == A(2).fld

b=B(1) # out of place
b2 = f(b)
@assert b==B(1)
@assert b2==B(2)
```

# Background

This package grew out of an attempt to reduce the complexity of
[Traits.jl](https://github.com/mauro3/Traits.jl), but at the same time
staying compatible (but which it isn't).  Compared to Traits.jl, it
drops support for:

- Trait definition in terms of methods and constraints.  Instead the
  user needs to assign types to traits manually.  This removes the
  most complex part of Traits.jl: the checking whether a type
  satisfies a trait definition.
- trait functions which dispatch on more than one trait.  This allows
  to remove the need for generated functions, as well as removing the
  rules for trait-dispatch.

The reason for splitting this away from Traits.jl are:

- creating a more reliable and easier to maintain package than
  Traits.jl
- exploring inclusion in Base (see
  [#13222](https://github.com/JuliaLang/julia/pull/13222)).

My [*JuliaCon 2015*](https://youtu.be/j9w8oHfG1Ic) talk gives a 10
minute introduction to Traits.jl and SimpleTraits.jl.

# The Future

The future of traits in Julia-Base: According to Stefan Karpinski's
JuliaCon 2016 talk, [Julia 1.0](https://youtu.be/5gXMpbY1kJY), traits
are scheduled to land after Julia 1.0.  Although, if someone gets
cracking, they may well happen pre-1.0.  My crystal ball tells me that
all or most of the functionality of this package will be supported in
the future trait system (multiparameter-traits may not be). Thus I
expect the transition will be mostly a matter of a syntax update and
less of a semantic update.  Also, an advantage to using this package
versus hand-coding Holy-traits will be that all occurrences of trait
usage are clearly marked and thus easier to update.

The future of this package: I see it as light-weight package focusing
on letting functions use dispatch based on traits.  This dispatch is
currently fairly limited, see section "Gotcha" above, but may be
expanded in the future: either through something like in PR
[m3/multitraits](https://github.com/mauro3/SimpleTraits.jl/pull/2) or
through a more general generated-function approach (definitely not
valid anymore in Julia 0.6).

In the unlikely event that I find myself with too much time on my
hands, I may try to develop a companion package to allow the
specification of a trait in terms of interfaces.  The combination of
the two packages would then have similar functionality to my
experimental package [Traits.jl](https://github.com/mauro3/Traits.jl).
If anyone fancies a go at writing this companion package, I would be
very happy to help and contribute.  After the
[type-system overhaul](https://github.com/JuliaLang/julia/pull/18457)
lands, this should be much less hackish than what's in Traits.jl.

# References

- [Traits.jl](https://github.com/mauro3/Traits.jl) and its references.
  In particular
  [here](https://github.com/mauro3/Traits.jl#dispatch-on-traits) is an
  in-depth discussion on limitations of Holy-Traits, which this
  package implements.

# To ponder

- There is a big update sitting in the branch
  [m3/multitraits](https://github.com/mauro3/SimpleTraits.jl/pull/2);
  but I never quite finished it.  It would also address the next point:
- Could type inheritance be used for sub-traits
  ([Jutho's idea](https://github.com/JuliaLang/julia/issues/10889#issuecomment-94317470))?
  In particular could it be used in such a way that it is compatible
  with the multiple inheritance used in Traits.jl?
