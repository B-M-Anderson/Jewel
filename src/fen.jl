function parse_fen(fen::AbstractString)

rank = 7
file = 0

pawns = UInt64(0)
knights = UInt64(0)
queens = UInt64(0)
bishops = UInt64(0)
rooks = UInt64(0)
kings = UInt64(0)

white = UInt64(0)
black = UInt64(0)

    parts = split(fen, ' ')
    if length(parts) != 6
        throw(ArgumentError("Invalid FEN string: $fen"))
    end

    for c in parts[1]
        if c == '/'
            rank -= 1
            file = 0
        elseif isdigit(c)
            file += parse(Int,c) 
        else
            square = rank * 8 + file
            bit = UInt64(1) << square

            if c == 'P'
                pawns |= bit
                white |= bit
            elseif c == 'p'
                pawns |= bit
                black |= bit
            elseif c == 'N'
                knights |= bit
                white |= bit
            elseif c == 'n'
                knights |= bit
                black |= bit
            elseif c == 'B'
                bishops |= bit
                white |= bit
            elseif c == 'b'
                bishops |= bit
                black |= bit
            elseif c == 'R'
                rooks |= bit
                white |= bit
            elseif c == 'r'
                rooks |= bit
                black |= bit
            elseif c == 'Q'
                queens |= bit
                white |= bit
            elseif c == 'q'
                queens |= bit
                black |= bit
            elseif c == 'K'
                kings |= bit
                white |= bit
            elseif c == 'k'
                kings |= bit
                black |= bit
            else
                throw(ArgumentError("Invalid FEN string: $fen"))
            end

            file += 1
        end
    end
    
    white_to_move = parts[2] == "w"

    white_castle_kingside = occursin("K", parts[3])
    white_castle_queenside = occursin("Q", parts[3])
    black_castle_kingside = occursin("k", parts[3])
    black_castle_queenside = occursin("q", parts[3])

    if parts[4] == "-"
        en_passant = UInt8(64)
    else
        ep_file = Int(parts[4][1]) - Int('a')
        ep_rank = parse(Int, parts[4][2]) - 1
        en_passant = UInt8(ep_rank * 8 + ep_file)
    end

    halfmove_clock = parse(UInt8, parts[5])
    fullmove_number = parse(UInt16, parts[6])

    return Board(pawns, knights, queens, bishops, rooks, kings,
                 black, white,
                 white_castle_kingside, white_castle_queenside,
                 black_castle_kingside, black_castle_queenside,
                 white_to_move, en_passant,
                 halfmove_clock, fullmove_number)
end