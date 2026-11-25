# Fits the five material weights to the games you've played against Jewel.
# Run from the jewel folder:   julia --project play/train_from_games.jl
# It only PRINTS the learned weights. It does not change the engine.

using Jewel

path = joinpath(@__DIR__, "data", "training.tsv")
if !isfile(path)
    error("No games saved yet. Finish at least one game first (expected file: $path)")
end

boards = Jewel.Board[]
targets = Float64[]
for line in eachline(path)
    fen, res = split(line, '\t')
    push!(boards, Jewel.parse_fen(String(fen)))
    push!(targets, parse(Float64, res))     # 1.0 White won, 0.5 draw, 0.0 Black won
end
println(length(boards), " positions from your games")

X = Jewel.build_features(boards)
w0 = Float64.(Jewel.WEIGHTS) ./ 100          # current weights, in pawn units
println("loss with current weights: ", Jewel.loss(X, targets, w0))
w = Jewel.train(X, targets, w0, 20.0, 3000)
println("loss after training:       ", Jewel.loss(X, targets, w))
println("learned weights (centipawns): ", round.(Int, 100 .* w))
println("current WEIGHTS:              ", Jewel.WEIGHTS)
println("Only the ratios mean much: game results are blunter targets than Stockfish evals, so the overall scale can drift.")
