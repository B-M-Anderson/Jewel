#piece type constants
const PAWN = 1
const KNIGHT = 2
const BISHOP = 3
const ROOK = 4
const QUEEN = 5
const KING = 6

#flag constants
const QUIET = 0
const DOUBLE_PUSH = 1
const KING_CASTLE = 2
const QUEEN_CASTLE = 3
const CAPTURE = 4
const EN_PASSANT = 5
const PROMO_KNIGHT = 8
const PROMO_BISHOP = 9
const PROMO_ROOK = 10
const PROMO_QUEEN = 11
const PROMO_KNIGHT_CAPTURE = 12
const PROMO_BISHOP_CAPTURE = 13
const PROMO_ROOK_CAPTURE = 14
const PROMO_QUEEN_CAPTURE = 15

function encode_move(from_sq,to_sq,flag)
    return UInt16(from_sq) | (UInt16(to_sq) << 6) | (UInt16(flag) << 12)
end

function make_move!(board::Board, move::UInt16)
    # Decode the move
    from_sq = Int(move & 0x3F)
    to_sq = Int((move >> 6) & 0x3F)
    flag = Int((move >> 12) & 0xF)

    from_bit = UInt64(1) << from_sq
    to_bit = UInt64(1) << to_sq

    # Determine piece moving
    piece_type = 0
    if (board.pawns & from_bit) != 0
        piece_type = PAWN
    elseif (board.knights & from_bit) != 0
        piece_type = KNIGHT
    elseif (board.bishops & from_bit) != 0
        piece_type = BISHOP 
    elseif (board.rooks & from_bit) != 0
        piece_type = ROOK
    elseif (board.queens & from_bit) != 0
        piece_type = QUEEN
    elseif (board.kings & from_bit) != 0
        piece_type = KING
    else
        throw(ArgumentError("No piece found on the from square"))
    end

    # remove captured piece
    if flag == CAPTURE
        if board.white_to_move
            board.black &= ~to_bit
        else 
            board.white &= ~to_bit
        end
        if (board.pawns & to_bit) != 0
            board.pawns &= ~to_bit
        elseif (board.knights & to_bit) != 0
            board.knights &= ~to_bit
        elseif (board.bishops & to_bit) != 0
            board.bishops &= ~to_bit
        elseif (board.rooks & to_bit) != 0
            board.rooks &= ~to_bit
        elseif (board.queens & to_bit) != 0
            board.queens &= ~to_bit
        elseif (board.kings & to_bit) != 0
            board.kings &= ~to_bit
        end
    end

    #update color boards
    if board.white_to_move
        board.white &= ~from_bit
        board.white |= to_bit
    else
        board.black &= ~from_bit
        board.black |= to_bit
    end 

    #update piece bitboards
    if piece_type == PAWN
        board.pawns &= ~from_bit
        board.pawns |= to_bit
    elseif piece_type == KNIGHT
        board.knights &= ~from_bit
        board.knights |= to_bit
    elseif piece_type == BISHOP
        board.bishops &= ~from_bit
        board.bishops |= to_bit
    elseif piece_type == ROOK
        board.rooks &= ~from_bit
        board.rooks |= to_bit
    elseif piece_type == QUEEN
        board.queens &= ~from_bit
        board.queens |= to_bit
    elseif piece_type == KING
        board.kings &= ~from_bit
        board.kings |= to_bit
    end
    
    #flip turn
    board.white_to_move = !board.white_to_move
end