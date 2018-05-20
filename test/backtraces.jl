###### BEGIN: LINE NUMBER SENSITIVITY ##########
@traitdef BacktraceTr{X}

@traitimpl BacktraceTr{Integer}

@traitfn foo(A::X) where {X;  BacktraceTr{X}} = backtrace()
@traitfn foo(A::X) where {X; !BacktraceTr{X}} = backtrace()
###### END:   LINE NUMBER SENSITIVITY ##########
# (the tests below depend on the particular line numbers in the code above)

function hasline(bt, n)
    for b in bt
        lkup = StackTraces.lookup(b)
        if length(lkup) >= 2
            l1, l2 = lkup[1], lkup[2]
            if (occursin("backtraces.jl", string(l1.file)) &&
                l1.func == :foo &&
                l1.line == n &&
                contains(string(l2.file), "SimpleTraits.jl"))
                return true
            end
        end
    end
    false
end

@test_broken hasline(foo(1), 6)
@test_broken hasline(foo(1.0), 7)

nothing
