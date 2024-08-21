include("../header.jl")
include("group_utils.jl")

using ManifoldsBase: VeeOrthogonalBasis

Random.seed!(10)

using Manifolds:
    LeftForwardAction, LeftBackwardAction, RightForwardAction, RightBackwardAction

@testset "Special Euclidean group" begin
    @test repr(SpecialEuclidean(3; vectors=HybridTangentRepresentation())) ==
          "SpecialEuclidean(3; vectors=HybridTangentRepresentation())"
    for (se_parameter, se_vectors) in [
        (:field, LeftInvariantRepresentation()),
        (:type, LeftInvariantRepresentation()),
        (:field, HybridTangentRepresentation()),
    ]
        @testset "SpecialEuclidean($n; parameter=$se_parameter, vectors=$se_vectors)" for n in
                                                                                          (
            2,
            3,
            4,
        )
            G = SpecialEuclidean(n; parameter=se_parameter, vectors=se_vectors)
            if se_parameter === :field
                @test isa(G, SpecialEuclidean{Tuple{Int}})
            else
                @test isa(G, SpecialEuclidean{TypeParameter{Tuple{n}}})
            end

            if se_parameter === :field && se_vectors === LeftInvariantRepresentation()
                @test repr(G) == "SpecialEuclidean($n; parameter=:field)"
            elseif se_parameter === :type && se_vectors === LeftInvariantRepresentation()
                @test repr(G) == "SpecialEuclidean($n)"
            elseif se_parameter === :field && se_vectors === HybridTangentRepresentation()
                @test repr(G) ==
                      "SpecialEuclidean($n; parameter=:field, vectors=HybridTangentRepresentation())"
            end
            M = base_manifold(G)
            @test M ===
                  TranslationGroup(n; parameter=se_parameter) ×
                  SpecialOrthogonal(n; parameter=se_parameter)
            @test submanifold(G, 1) === TranslationGroup(n; parameter=se_parameter)
            @test submanifold(G, 2) === SpecialOrthogonal(n; parameter=se_parameter)
            Rn = Rotations(n)
            p = Matrix(I, n, n)

            if n == 2
                t = Vector{Float64}.([1:2, 2:3, 3:4])
                ω = [[1.0], [2.0], [1.0]]
                tuple_pts = [(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)]
                tuple_X =
                    [([-1.0, 2.0], hat(Rn, p, [1.0])), ([1.0, -2.0], hat(Rn, p, [0.5]))]
            elseif n == 3
                t = Vector{Float64}.([1:3, 2:4, 4:6])
                ω = [[1.0, 2.0, 3.0], [3.0, 2.0, 1.0], [1.0, 3.0, 2.0]]
                tuple_pts = [(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)]
                tuple_X = [
                    ([-1.0, 2.0, 1.0], hat(Rn, p, [1.0, 0.5, -0.5])),
                    ([-2.0, 1.0, 0.5], hat(Rn, p, [-1.0, -0.5, 1.1])),
                ]
            else # n == 4
                t = Vector{Float64}.([1:4, 2:5, 3:6])
                ω = [
                    [1.0, 2.0, 3.0, 1.0, 2.0, 3.0],
                    [3.0, 2.0, 1.0, 1.0, 2.0, 3.0],
                    [1.0, 3.0, 2.0, 1.0, 2.0, 3.0],
                ]
                tuple_pts = [(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)]
                tuple_X = [
                    ([-1.0, 2.0, 1.0, 3.0], hat(Rn, p, [1.0, 0.5, -0.5, 0.0, 2.0, 1.0])),
                    ([-2.0, 1.5, -1.0, 2.0], hat(Rn, p, [1.0, -0.5, 0.5, 1.0, 0.0, 1.0])),
                ]
            end

            basis_types = (DefaultOrthonormalBasis(),)

            @testset "isapprox with identity" begin
                @test isapprox(G, Identity(G), identity_element(G))
                @test isapprox(G, identity_element(G), Identity(G))
            end

            pts = [ArrayPartition(tp...) for tp in tuple_pts]
            X_pts = [ArrayPartition(tX...) for tX in tuple_X]

            @testset "setindex! and getindex" begin
                p1 = pts[1]
                p2 = allocate(p1)
                @test p1[G, 1] === p1[M, 1]
                p2[G, 1] = p1[M, 1]
                @test p2[G, 1] == p1[M, 1]
            end

            g1, g2 = pts[1:2]
            t1, R1 = submanifold_components(g1)
            t2, R2 = submanifold_components(g2)
            g1g2 = ArrayPartition(R1 * t2 + t1, R1 * R2)
            @test isapprox(G, compose(G, g1, g2), g1g2)
            g1g2mat = affine_matrix(G, g1g2)
            @test g1g2mat ≈ affine_matrix(G, g1) * affine_matrix(G, g2)
            @test affine_matrix(G, g1g2mat) === g1g2mat
            if se_parameter === :type
                @test affine_matrix(G, Identity(G)) isa SDiagonal{n,Float64}
            end
            @test affine_matrix(G, Identity(G)) == SDiagonal{n,Float64}(I)

            w = translate_diff(G, pts[1], Identity(G), X_pts[1])
            if se_vectors isa Manifolds.LeftInvariantRepresentation
                w2mat = screw_matrix(G, w)
                @test w2mat ≈ screw_matrix(G, X_pts[1])
                @test screw_matrix(G, w2mat) === w2mat
            end

            @test is_vector(G, Identity(G), rand(G; vector_at=Identity(G)))

            test_group(
                G,
                pts,
                X_pts,
                X_pts;
                test_diff=true,
                test_lie_bracket=true,
                test_adjoint_action=true,
                test_exp_from_identity=true,
                test_log_from_identity=true,
                test_vee_hat_from_identity=true,
                diff_convs=[(), (LeftForwardAction(),), (RightBackwardAction(),)],
            )
            test_manifold(
                G,
                pts;
                basis_types_vecs=basis_types,
                basis_types_to_from=basis_types,
                is_mutating=true,
                is_tangent_atol_multiplier=1,
                #test_inplace=true,
                test_vee_hat=true,
                exp_log_atol_multiplier=50,
            )

            for CS in [CartanSchoutenMinus(), CartanSchoutenPlus(), CartanSchoutenZero()]
                @testset "$CS" begin
                    G_TR = ConnectionManifold(G, CS)

                    test_group(
                        G_TR,
                        pts,
                        X_pts,
                        X_pts;
                        test_diff=true,
                        test_lie_bracket=true,
                        test_adjoint_action=true,
                        diff_convs=[(), (LeftForwardAction(),), (RightBackwardAction(),)],
                    )

                    test_manifold(
                        G_TR,
                        pts;
                        is_mutating=true,
                        exp_log_atol_multiplier=50,
                        is_tangent_atol_multiplier=1,
                        test_inner=false,
                        test_norm=false,
                    )
                end
            end
            for MM in [LeftInvariantMetric()]
                @testset "$MM" begin
                    G_TR = MetricManifold(G, MM)
                    @test base_group(G_TR) === G

                    test_group(
                        G_TR,
                        pts,
                        X_pts,
                        X_pts;
                        test_diff=true,
                        test_lie_bracket=true,
                        test_adjoint_action=true,
                        diff_convs=[(), (LeftForwardAction(),), (RightBackwardAction(),)],
                    )

                    test_manifold(
                        G_TR,
                        pts;
                        basis_types_vecs=basis_types,
                        basis_types_to_from=basis_types,
                        is_mutating=true,
                        exp_log_atol_multiplier=50,
                        is_tangent_atol_multiplier=1,
                    )
                end
            end

            @testset "affine matrix" begin
                pts = [affine_matrix(G, ArrayPartition(tp...)) for tp in tuple_pts]
                X_pts = [screw_matrix(G, ArrayPartition(tX...)) for tX in tuple_X]

                @testset "setindex! and getindex" begin
                    p1 = pts[1]
                    p2 = allocate(p1)
                    @test p1[G, 1] === p1[M, 1]
                    p2[G, 1] = p1[M, 1]
                    @test p2[G, 1] == p1[M, 1]
                end

                test_group(
                    G,
                    pts,
                    X_pts,
                    X_pts;
                    test_diff=true, # fails sometimes
                    test_lie_bracket=true,
                    diff_convs=[(), (LeftForwardAction(),), (RightBackwardAction(),)],
                    atol=1e-9,
                )
                test_manifold(
                    G,
                    pts;
                    is_mutating=true,
                    #test_inplace=true,
                    test_vee_hat=true,
                    test_is_tangent=true, # fails
                    exp_log_atol_multiplier=50,
                )
                # specific affine tests
                p = copy(G, pts[1])
                X = copy(G, p, X_pts[1])
                X[n + 1, n + 1] = 0.1
                @test_throws DomainError is_vector(G, p, X; error=:error)
                X2 = zeros(n + 2, n + 2)
                # nearly correct just too large (and the error from before)
                X2[1:n, 1:n] .= X[1:n, 1:n]
                X2[1:n, end] .= X[1:n, end]
                X2[end, end] = X[end, end]
                @test_throws DomainError is_vector(G, p, X2; error=:error)
                p[n + 1, n + 1] = 0.1
                @test_throws DomainError is_point(G, p; error=:error)
                p2 = zeros(n + 2, n + 2)
                # nearly correct just too large (and the error from before)
                p2[1:n, 1:n] .= p[1:n, 1:n]
                p2[1:n, end] .= p[1:n, end]
                p2[end, end] = p[end, end]
                @test_throws DomainError is_point(G, p2; error=:error)
                # exp/log_lie for ProductGroup on arrays
                X = copy(G, p, X_pts[1])
                p3 = exp_lie(G, X)
                X3 = log_lie(G, p3)
                isapprox(G, Identity(G), X, X3)
            end

            @testset "hat/vee" begin
                p = ArrayPartition(tuple_pts[1]...)
                X = ArrayPartition(tuple_X[1]...)
                Xexp = [
                    submanifold_component(X, 1)
                    vee(Rn, submanifold_component(p, 2), submanifold_component(X, 2))
                ]
                Xc = vee(G, p, X)
                @test Xc ≈ Xexp
                @test isapprox(G, p, hat(G, p, Xc), X)

                Xc = vee(G, affine_matrix(G, p), screw_matrix(G, X))
                @test Xc ≈ Xexp
                @test hat(G, affine_matrix(G, p), Xc) ≈ screw_matrix(G, X)

                e = Identity(G)
                Xe = log_lie(G, p)
                Xc = vee(G, e, Xe)
                @test_throws ErrorException vee(M, e, Xe)
                w = similar(Xc)
                vee!(G, w, e, Xe)
                @test isapprox(Xc, w)
                @test_throws ErrorException vee!(M, w, e, Xe)

                w = similar(Xc)
                vee!(G, w, identity_element(G), Xe)
                @test isapprox(Xc, w)

                Ye = hat(G, e, Xc)
                @test_throws ErrorException hat(M, e, Xc)
                isapprox(G, e, Xe, Ye)
                Ye2 = copy(G, p, X)
                hat!(G, Ye2, e, Xc)
                @test_throws ErrorException hat!(M, Ye, e, Xc)
                @test isapprox(G, e, Ye, Ye2)

                Ye2 = copy(G, p, X)
                hat!(G, Ye2, identity_element(G), Xc)
                @test isapprox(G, e, Ye, Ye2)
            end

            G = SpecialEuclidean(11)
            @test affine_matrix(G, Identity(G)) isa Diagonal{Float64,Vector{Float64}}
            @test affine_matrix(G, Identity(G)) == Diagonal(ones(11))
        end
    end

    for se_vectors in [LeftInvariantRepresentation(), HybridTangentRepresentation()]
        @testset "Explicit embedding in GL(n+1)" begin
            G = SpecialEuclidean(3; vectors=se_vectors)
            t = Vector{Float64}.([1:3, 2:4, 4:6])
            ω = [[1.0, 2.0, 3.0], [3.0, 2.0, 1.0], [1.0, 3.0, 2.0]]
            p = Matrix(I, 3, 3)
            Rn = Rotations(3)
            pts = [ArrayPartition(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)]
            X = ArrayPartition([-1.0, 2.0, 1.0], hat(Rn, p, [1.0, 0.5, -0.5]))
            q = ArrayPartition([0.0, 0.0, 0.0], p)

            GL = GeneralLinear(4)
            SEGL = EmbeddedManifold(G, GL)
            @test Manifolds.SpecialEuclideanInGeneralLinear(3; se_vectors=se_vectors) ===
                  SEGL
            pts_gl = [embed(SEGL, pp) for pp in pts]
            q_gl = embed(SEGL, q)
            X_gl = embed(SEGL, pts_gl[1], X)

            q_gl2 = allocate(q_gl)
            embed!(SEGL, q_gl2, q)
            @test isapprox(SEGL, q_gl2, q_gl)

            q2 = allocate(q)
            project!(SEGL, q2, q_gl)
            @test isapprox(G, q, q2)

            @test isapprox(G, pts[1], project(SEGL, pts_gl[1]))
            @test isapprox(G, pts[1], X, project(SEGL, pts_gl[1], X_gl))

            X_gl2 = allocate(X_gl)
            embed!(SEGL, X_gl2, pts_gl[1], X)
            @test isapprox(SEGL, pts_gl[1], X_gl2, X_gl)

            X2 = allocate(X)
            project!(SEGL, X2, pts_gl[1], X_gl)
            @test isapprox(G, pts[1], X, X2)

            for conv in [LeftForwardAction(), RightBackwardAction()]
                tpgl = translate(GL, pts_gl[2], pts_gl[1], conv)
                tXgl = translate_diff(GL, pts_gl[2], pts_gl[1], X_gl, conv)
                tpse = translate(G, pts[2], pts[1], conv)
                tXse = translate_diff(G, pts[2], pts[1], X, conv)
                @test isapprox(G, tpse, project(SEGL, tpgl))
                @test isapprox(G, tpse, tXse, project(SEGL, tpgl, tXgl))

                @test isapprox(
                    G,
                    pts_gl[1],
                    X_gl,
                    translate_diff(G, Identity(G), pts_gl[1], X_gl, conv),
                )
            end
        end
    end

    @testset "Adjoint action on 𝔰𝔢(3)" begin
        G = SpecialEuclidean(3; parameter=:type, vectors=HybridTangentRepresentation())
        t = Vector{Float64}.([1:3, 2:4, 4:6])
        ω = [[1.0, 2.0, 3.0], [3.0, 2.0, 1.0], [1.0, 3.0, 2.0]]
        p = Matrix(I, 3, 3)
        Rn = Rotations(3)
        pts = [ArrayPartition(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)]
        X = ArrayPartition([-1.0, 2.0, 1.0], hat(Rn, p, [1.0, 0.5, -0.5]))
        q = ArrayPartition([0.0, 0.0, 0.0], p)

        # adjoint action of SE(3)
        fX = TFVector(vee(G, q, X), VeeOrthogonalBasis())
        fXp = adjoint_action(G, pts[1], fX)
        fXp2 = adjoint_action(G, pts[1], X)
        @test isapprox(G, pts[1], hat(G, pts[1], fXp.data), fXp2)
    end

    @testset "Invariant exp and log" begin
        G = SpecialEuclidean(3)
        p = ArrayPartition(
            [-0.3879800256554809, -1.480242310944754, 0.6859001130634623],
            [
                0.07740722383491305 0.37616397751531383 0.9233140222687134
                -0.8543895289705175 0.5023190688041862 -0.13301911855531234
                -0.513835240601215 -0.7785731918937062 0.36027368816045613
            ],
        )
        X = ArrayPartition(
            [-0.13357857168916804, -0.6285892085394564, -0.5876201702680527],
            [
                0.0 -0.9387500040623927 -0.02175499382616511
                0.9387500040623927 0.0 -0.31110293886623697
                0.02175499382616511 0.31110293886623697 0.0
            ],
        )
        q_ref = ArrayPartition(
            [-1.188881359581349, -1.7593716755284188, 0.7643154032226447],
            [
                0.4842416235264354 0.37906436972889457 0.788555802493722
                -0.13102724697252144 0.9225290425378667 -0.3630041683300185
                -0.8650675757391926 0.07245943193403166 0.49639472209977575
            ],
        )
        q = exp_inv(G, p, X)
        @test isapprox(G, q, q_ref)
        Y = log_inv(G, p, q)
        @test isapprox(G, p, X, Y)

        q2 = similar(q)
        exp_inv!(G, q2, p, X)
        @test isapprox(G, q, q2)

        Y2 = similar(Y)
        log_inv!(G, Y2, p, q)
        @test isapprox(G, p, Y, Y2)
    end

    @testset "performance of selected operations" begin
        for n in [2, 3]
            SEn = SpecialEuclidean(n; vectors=HybridTangentRepresentation())
            Rn = Rotations(n)

            p = SMatrix{n,n}(I)

            if n == 2
                t = SVector{2}.([1:2, 2:3, 3:4])
                ω = [[1.0], [2.0], [1.0]]
                pts = [
                    ArrayPartition(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)
                ]
                Xs = [
                    ArrayPartition(SA[-1.0, 2.0], hat(Rn, p, SA[1.0])),
                    ArrayPartition(SA[1.0, -2.0], hat(Rn, p, SA[0.5])),
                ]
            elseif n == 3
                t = SVector{3}.([1:3, 2:4, 4:6])
                ω = [SA[pi, 0.0, 0.0], SA[0.0, 0.0, 0.0], SA[1.0, 3.0, 2.0]]
                pts = [
                    ArrayPartition(ti, exp(Rn, p, hat(Rn, p, ωi))) for (ti, ωi) in zip(t, ω)
                ]
                Xs = [
                    ArrayPartition(SA[-1.0, 2.0, 1.0], hat(Rn, p, SA[1.0, 0.5, -0.5])),
                    ArrayPartition(SA[-2.0, 1.0, 0.5], hat(Rn, p, SA[-1.0, -0.5, 1.1])),
                ]
            end
            exp(SEn, pts[1], Xs[1])
            exp(base_manifold(SEn), pts[1], Xs[1])
            compose(SEn, pts[1], pts[2])
            log(SEn, pts[1], pts[2])
            log(SEn, pts[1], pts[3])
            @test isapprox(SEn, log(SEn, pts[1], pts[1]), 0 .* Xs[1]; atol=1e-16)
            @test isapprox(SEn, exp(SEn, pts[1], 0 .* Xs[1]), pts[1])
            vee(SEn, pts[1], Xs[2])
            get_coordinates(SEn, pts[1], Xs[2], DefaultOrthogonalBasis())
            csen = n == 2 ? SA[1.0, 2.0, 3.0] : SA[1.0, 0.0, 2.0, 2.0, -1.0, 1.0]
            hat(SEn, pts[1], csen)
            get_vector(SEn, pts[1], csen, DefaultOrthogonalBasis())
            # @btime shows 0 but `@allocations` is inaccurate
            @static if VERSION >= v"1.9-DEV"
                @test (@allocations exp(base_manifold(SEn), pts[1], Xs[1])) <= 4
                @test (@allocations compose(SEn, pts[1], pts[2])) <= 4
                if VERSION < v"1.11-DEV"
                    @test (@allocations log(SEn, pts[1], pts[2])) <= 28
                else
                    @test (@allocations log(SEn, pts[1], pts[2])) <= 42
                end
                @test (@allocations vee(SEn, pts[1], Xs[2])) <= 13
                @test (@allocations get_coordinates(
                    SEn,
                    pts[1],
                    Xs[2],
                    DefaultOrthogonalBasis(),
                )) <= 13
                @test (@allocations hat(SEn, pts[1], csen)) <= 13
                @test (@allocations get_vector(
                    SEn,
                    pts[1],
                    csen,
                    DefaultOrthogonalBasis(),
                )) <= 13
            end
        end
    end
end
