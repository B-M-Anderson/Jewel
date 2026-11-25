# Loads training positions from data/positions.tsv.
# Each line: FEN <tab> centipawn eval from White's point of view (Stockfish, Lichess eval database).
# Returns the boards and targets squashed to (0,1) with sigmoid(cp / 400).
function load_positions(path::String, n::Int)
    boards = Board[]
    targets = Float64[]
    for line in eachline(path)
        if length(boards) >= n
            break
        end
        fen, cp = split(line, '\t')
        push!(boards, parse_fen(String(fen)))
        push!(targets, 1 / (1 + exp(-parse(Float64, cp) / 400)))
    end
    return boards, targets
end
