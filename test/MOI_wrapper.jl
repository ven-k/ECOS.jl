module TestECOS

using Test
import ECOS
import MathOptInterface

const MOI = MathOptInterface

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_runtests()
    model = MOI.instantiate(ECOS.Optimizer, with_bridge_type = Float64)
    MOI.set(model, MOI.Silent(), true)
    exclude = String[
        # Expected test failures:
        #   Problem is a nonconvex QP (fixed in MOI 0.10.6)
        "test_basic_ScalarQuadraticFunction_EqualTo",
        "test_basic_ScalarQuadraticFunction_GreaterThan",
        "test_basic_ScalarQuadraticFunction_Interval",
        "test_basic_VectorQuadraticFunction_",
        "test_quadratic_SecondOrderCone_basic",
        "test_quadratic_nonconvex_",
        #   MathOptInterface.jl issue #1431
        "test_model_LowerBoundAlreadySet",
        "test_model_UpperBoundAlreadySet",
    ]
    if Sys.WORD_SIZE == 32
        # These tests fail on x86 Linux, returning ITERATION_LIMIT instead of
        # proving {primal,dual}_INFEASIBLE.
        push!(exclude, "test_conic_linear_INFEASIBLE")
        push!(exclude, "test_solve_TerminationStatus_DUAL_INFEASIBLE")
    end
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            atol = 1e-3,
            rtol = 1e-3,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.VariableBasisStatus,
                MOI.ObjectiveBound,
            ],
        ),
        exclude = exclude,
    )
    return
end

function test_RawOptimizerAttribute()
    model = ECOS.Optimizer()
    MOI.set(model, MOI.RawOptimizerAttribute("abstol"), 1e-5)
    @test MOI.get(model, MOI.RawOptimizerAttribute("abstol")) ≈ 1e-5
    MOI.set(model, MOI.RawOptimizerAttribute("abstol"), 2e-5)
    @test MOI.get(model, MOI.RawOptimizerAttribute("abstol")) == 2e-5
    return
end

function test_iteration_limit()
    v = [5.0, 3.0, 1.0]
    w = [2.0, 1.5, 0.3]
    solver = MOI.OptimizerWithAttributes(ECOS.Optimizer, MOI.Silent() => true)
    model = MOI.instantiate(solver, with_bridge_type = Float64)
    maxit = 1
    MOI.set(model, MOI.RawOptimizerAttribute("maxit"), maxit)
    MOI.set(model, MOI.Silent(), true)
    x = MOI.add_variables(model, 3)
    MOI.add_constraint.(model, x, MOI.Interval(0.0, 1.0))
    MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(w, x), 0.0),
        MOI.LessThan(3.0),
    )
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(v, x), 0.0),
    )
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.ITERATION_LIMIT
    @test MOI.get(model, MOI.BarrierIterations()) == maxit
    return
end

end  # module

TestECOS.runtests()
