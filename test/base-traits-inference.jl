# Tests that trait dispatch for the BaseTraits does not incur a
# overhead.

function llvm_lines(fn, args)
    io = IOBuffer()
    Base.code_llvm(io, fn, args)
    #Base.code_native(io, fn, args)
    count(c->c=='\n', String(io))
end

# Dict with base-traits to check using value[1] as type and value[2]
# as number of lines allowed in llvm code
cutoff = 6
basetrs = [:IsLeafType=>(:Int,cutoff),
           :IsBits=>(:Int, cutoff),
           :IsImmutable=>(:Int, cutoff),
           :IsContiguous=>(:(SubArray{Int64,1,Array{Int64,1},Tuple{Array{Int64,1}},false}), cutoff),
           :IsIndexLinear=>(:(Vector{Int}), cutoff),
           :IsAnything=>(:Int, cutoff),
           :IsNothing=>(:Int, cutoff), # this errors
           :IsCallable=>(:(typeof(sin)), cutoff),
           :IsIterator=>(:(Dict{Int,Int}), cutoff)]

for (bt, (tp,cutoff)) in basetrs
    fn = gensym()
    @eval @traitfn $fn(x::::$bt) = 1
    @eval @traitfn $fn(x::::(!$bt)) = 2
    @eval @test llvm_lines($fn, ($tp,)) < $cutoff
end
