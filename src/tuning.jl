function build_features(boards)
    X = zeros(Float64, length(boards), 5)
    for i in eachindex(boards)
        X[i, :] = material_features(boards[i])
    end
    return X
end

function predict(X, w)
    return 1 ./ (1 .+ exp.(-(X * w) ./ 4))
end

function loss(X, targets, w)
    1 / length(targets) * sum((predict(X, w) - targets) .^ 2)
end

function gradient(X, targets, w)
    N  = length(targets)
    p = predict(X, w)
    return (2 / (4N)) * X' * ((p .- targets) .* p .* (1 .- p))
end

function train(X, targets, w0, lr, steps)
    w = copy(w0)
    for step in 1:steps
        g = gradient(X, targets, w)
        w = w - lr * g
        if step % 100 == 0
            println(step, "  loss ", loss(X, targets, w))
        end
    end
    return w
end