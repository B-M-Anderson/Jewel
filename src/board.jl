struct Board
    pawns::UInt64
    knights::UInt64
    bishops::UInt64
    rooks::UInt64
    queens::UInt64
    kings::UInt64

    black::UInt64
    white::UInt64

    white_castle_kingside::Bool
    white_castle_queenside::Bool
    black_castle_kingside::Bool
    black_castle_queenside::Bool

    white_to_move::Bool
    en_passant::UInt8
    halfmove_clock::UInt8
    fullmove_number::UInt16
end 