# Debug helpers for perft. Not used by the engine itself.

# Turns a packed move into text like "e2e4" (promotions get a letter: "e7e8q").
function move_to_string(move::UInt16)::String
    from_sq = Int(move & 0x3F)
    to_sq = Int((move >> 6) & 0x3F)
    flag = Int((move >> 12) & 0xF)

    files = "abcdefgh"
    s = string(files[from_sq % 8 + 1], div(from_sq, 8) + 1,
               files[to_sq % 8 + 1], div(to_sq, 8) + 1)

    if flag >= 8
        # low two bits of a promotion flag: 0 knight, 1 bishop, 2 rook, 3 queen
        s *= "nbrq"[(flag & 3) + 1]
    end
    return s
end

# Same output format as Stockfish's "go perft N": one line per root move.
function perft_divide(board::Board, depth::Int)::UInt64
    total = UInt64(0)
    for move in generate_legal_moves(board)
        n = perft(make_move(board, move), depth - 1)
        println(move_to_string(move), ": ", n)
        total += n
    end
    println("Total: ", total)
    return total
end
