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

function make_move(board::Board, move::UInt16)
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

    pawns = board.pawns
    knights = board.knights
    bishops = board.bishops
    rooks = board.rooks
    queens = board.queens
    kings = board.kings

    white = board.white
    black = board.black

   is_capture = (flag == CAPTURE) || (12 <= flag <= 15)

    # remove captured piece
    if is_capture
        if board.white_to_move
            black &= ~to_bit
        else 
            white &= ~to_bit
        end
        if (pawns & to_bit) != 0
            pawns &= ~to_bit
        elseif (knights & to_bit) != 0
            knights &= ~to_bit
        elseif (bishops & to_bit) != 0
            bishops &= ~to_bit
        elseif (rooks & to_bit) != 0
            rooks &= ~to_bit
        elseif (queens & to_bit) != 0
            queens &= ~to_bit
        elseif (kings & to_bit) != 0
            kings &= ~to_bit
        end
    elseif flag == EN_PASSANT
        if board.white_to_move
            cap_bit = UInt64(1) << (to_sq - 8)
            black &= ~cap_bit
        else
            cap_bit = UInt64(1) << (to_sq + 8)
            white &= ~cap_bit
        end
        pawns &= ~cap_bit
    end

    #update color boards
    if board.white_to_move
        white &= ~from_bit
        white |= to_bit
    else
        black &= ~from_bit
        black |= to_bit
    end 

    #update piece bitboards
    if piece_type == PAWN
        pawns &= ~from_bit
        if flag == PROMO_KNIGHT || flag == PROMO_KNIGHT_CAPTURE
            knights |= to_bit
        elseif flag == PROMO_BISHOP || flag == PROMO_BISHOP_CAPTURE
            bishops |= to_bit
        elseif flag == PROMO_ROOK || flag == PROMO_ROOK_CAPTURE
            rooks |= to_bit
        elseif flag == PROMO_QUEEN || flag == PROMO_QUEEN_CAPTURE
            queens |= to_bit
        else
            pawns |= to_bit
        end
    elseif piece_type == KNIGHT
        knights &= ~from_bit
        knights |= to_bit
    elseif piece_type == BISHOP
        bishops &= ~from_bit
        bishops |= to_bit
    elseif piece_type == ROOK
        rooks &= ~from_bit
        rooks |= to_bit
    elseif piece_type == QUEEN
        queens &= ~from_bit
        queens |= to_bit
    elseif piece_type == KING
        kings &= ~from_bit
        kings |= to_bit
    end

    #castling rook move
    if flag == KING_CASTLE
        if board.white_to_move
            # h1 (7) -> f1 (5)
            rook_mask = (UInt64(1) << 7) | (UInt64(1) << 5)
            rooks ⊻= rook_mask
            white ⊻= rook_mask
        else
            # h8 (63) -> f8 (61)
            rook_mask = (UInt64(1) << 63) | (UInt64(1) << 61)
            rooks ⊻= rook_mask
            black ⊻= rook_mask
        end
    elseif flag == QUEEN_CASTLE
        if board.white_to_move
            # a1 (0) -> d1 (3)
            rook_mask = (UInt64(1) << 0) | (UInt64(1) << 3)
            rooks ⊻= rook_mask
            white ⊻= rook_mask
        else
            # a8 (56) -> d8 (59)
            rook_mask = (UInt64(1) << 56) | (UInt64(1) << 59)
            rooks ⊻= rook_mask
            black ⊻= rook_mask
        end
    end

    #update castling rights
    wc_k = board.white_castle_kingside
    wc_q = board.white_castle_queenside
    bc_k = board.black_castle_kingside
    bc_q = board.black_castle_queenside

    if from_sq == 4
        wc_k = false
        wc_q = false
    elseif from_sq == 60
        bc_k = false
        bc_q = false
    end

    if from_sq == 7 || to_sq == 7
        wc_k = false
    end
    if from_sq == 0 || to_sq == 0
        wc_q = false
    end
    if from_sq == 63 || to_sq == 63
        bc_k = false
    end
    if from_sq == 56 || to_sq == 56
        bc_q = false
    end

    #update en passant square
    new_en_passant = UInt8(64)
    if flag == DOUBLE_PUSH
        new_en_passant = UInt8((from_sq + to_sq) ÷ 2)
    end

    new_halfmove = (piece_type == PAWN || is_capture || flag == EN_PASSANT) ? UInt8(0) : board.halfmove_clock + UInt8(1)
    new_fullmove = board.white_to_move ? board.fullmove_number : board.fullmove_number + UInt16(1)
    
    return Board(pawns, knights, bishops, rooks, queens, kings, black, white, wc_k, wc_q, bc_k, bc_q, !board.white_to_move, new_en_passant, new_halfmove, new_fullmove)
end

generate_pseudo_legal_moves(board::Board) = generate_pseudo_legal_moves(board, board.white_to_move)

function generate_pseudo_legal_moves(board::Board, white_to_move::Bool)::Vector{UInt16}
    moves = UInt16[]
    sizehint!(moves, 64)

    us = white_to_move ? board.white : board.black
    them = white_to_move ? board.black : board.white
    occupied = us | them

    # --- Knights ---
    knights = board.knights & us
    while knights != 0
        from_sq = trailing_zeros(knights)
        knights &= knights - 1

        attacks = KNIGHT_ATTACKS[from_sq + 1] & ~us
        while attacks != 0
            to_sq = trailing_zeros(attacks)
            attacks &= attacks - 1

            flag = ((them & (UInt64(1) << to_sq)) != 0) ? CAPTURE : QUIET
            push!(moves, encode_move(from_sq, to_sq, flag))
        end
    end

    # --- King (normal moves; castling comes later) ---
    king_bb = board.kings & us
    if king_bb != 0
        from_sq = trailing_zeros(king_bb)
        attacks = KING_ATTACKS[from_sq + 1] & ~us
        while attacks != 0
            to_sq = trailing_zeros(attacks)
            attacks &= attacks - 1

            flag = ((them & (UInt64(1) << to_sq)) != 0) ? CAPTURE : QUIET
            push!(moves, encode_move(from_sq, to_sq, flag))
        end
    end

# --- Diagonal Sliders (Bishops + Queens) ---
 diag_sliders = (board.bishops | board.queens) & us
 while diag_sliders != 0
     from_sq = trailing_zeros(diag_sliders)
     diag_sliders &= diag_sliders - 1

     attacks = sliding_attacks(from_sq, occupied, BISHOP_DIRS) & ~us
     while attacks != 0
         to_sq = trailing_zeros(attacks)
         attacks &= attacks - 1

         flag = ((them & (UInt64(1) << to_sq)) != 0) ? CAPTURE : QUIET
         push!(moves, encode_move(from_sq, to_sq, flag))
     end
 end

 # --- Orthogonal Sliders (Rooks + Queens) ---
 ortho_sliders = (board.rooks | board.queens) & us
 while ortho_sliders != 0
     from_sq = trailing_zeros(ortho_sliders)
     ortho_sliders &= ortho_sliders - 1

     attacks = sliding_attacks(from_sq, occupied, ROOK_DIRS) & ~us
     while attacks != 0
         to_sq = trailing_zeros(attacks)
         attacks &= attacks - 1

         flag = ((them & (UInt64(1) << to_sq)) != 0) ? CAPTURE : QUIET
         push!(moves, encode_move(from_sq, to_sq, flag))
     end
 end

# --- Pawns ---
    pawns = board.pawns & us
    empty = ~occupied
    push_dir = white_to_move ? 8 : -8
    start_min = white_to_move ? 8 : 48
    start_max = white_to_move ? 15 : 55
    promo_min = white_to_move ? 56 : 0
    promo_max = white_to_move ? 63 : 7
    pawn_table = white_to_move ? WHITE_PAWN_ATTACKS : BLACK_PAWN_ATTACKS

    while pawns != 0
        from_sq = trailing_zeros(pawns)
        pawns &= pawns - 1

        # 1. Single push (+ double push & push promotions)
        to_sq = from_sq + push_dir
        if (empty & (UInt64(1) << to_sq)) != 0
            if promo_min <= to_sq <= promo_max
                push!(moves, encode_move(from_sq, to_sq, PROMO_QUEEN))
                push!(moves, encode_move(from_sq, to_sq, PROMO_ROOK))
                push!(moves, encode_move(from_sq, to_sq, PROMO_BISHOP))
                push!(moves, encode_move(from_sq, to_sq, PROMO_KNIGHT))
            else
                push!(moves, encode_move(from_sq, to_sq, QUIET))
                if start_min <= from_sq <= start_max
                    to_sq2 = to_sq + push_dir
                    if (empty & (UInt64(1) << to_sq2)) != 0
                        push!(moves, encode_move(from_sq, to_sq2, DOUBLE_PUSH))
                    end
                end
            end
        end

        # 2. Captures (+ capture promotions)
        attacks = pawn_table[from_sq + 1] & them
        while attacks != 0
            cap_sq = trailing_zeros(attacks)
            attacks &= attacks - 1

            if promo_min <= cap_sq <= promo_max
                push!(moves, encode_move(from_sq, cap_sq, PROMO_QUEEN_CAPTURE))
                push!(moves, encode_move(from_sq, cap_sq, PROMO_ROOK_CAPTURE))
                push!(moves, encode_move(from_sq, cap_sq, PROMO_BISHOP_CAPTURE))
                push!(moves, encode_move(from_sq, cap_sq, PROMO_KNIGHT_CAPTURE))
            else
                push!(moves, encode_move(from_sq, cap_sq, CAPTURE))
            end
        end

        # 3. En passant
        if board.en_passant < 64
            ep_bit = UInt64(1) << board.en_passant
            if (pawn_table[from_sq + 1] & ep_bit) != 0
                push!(moves, encode_move(from_sq, Int(board.en_passant), EN_PASSANT))
            end
        end
    end

# --- Castling ---
    if white_to_move
        if (board.white_castle_kingside || board.white_castle_queenside) && !is_square_attacked(board, 4, false)
            if board.white_castle_kingside &&
               (occupied & ((UInt64(1) << 5) | (UInt64(1) << 6))) == 0 &&
               !is_square_attacked(board, 5, false) &&
               !is_square_attacked(board, 6, false)
                push!(moves, encode_move(4, 6, KING_CASTLE))
            end
            if board.white_castle_queenside &&
               (occupied & ((UInt64(1) << 1) | (UInt64(1) << 2) | (UInt64(1) << 3))) == 0 &&
               !is_square_attacked(board, 3, false) &&
               !is_square_attacked(board, 2, false)
                push!(moves, encode_move(4, 2, QUEEN_CASTLE))
            end
        end
    else
        if (board.black_castle_kingside || board.black_castle_queenside) && !is_square_attacked(board, 60, true)
            if board.black_castle_kingside &&
               (occupied & ((UInt64(1) << 61) | (UInt64(1) << 62))) == 0 &&
               !is_square_attacked(board, 61, true) &&
               !is_square_attacked(board, 62, true)
                push!(moves, encode_move(60, 62, KING_CASTLE))
            end
            if board.black_castle_queenside &&
               (occupied & ((UInt64(1) << 57) | (UInt64(1) << 58) | (UInt64(1) << 59))) == 0 &&
               !is_square_attacked(board, 59, true) &&
               !is_square_attacked(board, 58, true)
                push!(moves, encode_move(60, 58, QUEEN_CASTLE))
            end
        end
    end

    

    return moves
end

function generate_legal_moves(board::Board)::Vector{UInt16}
    pseudo = generate_pseudo_legal_moves(board)
    legal = UInt16[]
    sizehint!(legal, length(pseudo))

    for move in pseudo
        next_board = make_move(board, move)
        us_bb = board.white_to_move ? next_board.white : next_board.black
        king_sq = trailing_zeros(next_board.kings & us_bb)

        if !is_square_attacked(next_board, king_sq, !board.white_to_move)
            push!(legal, move)
        end
    end

    return legal
end

function perft(board::Board, depth::Int)::UInt64
    if depth == 0
        return UInt64(1)
    end

    nodes = UInt64(0)
    for move in generate_legal_moves(board)
        nodes += perft(make_move(board, move), depth - 1)
    end
    return nodes
end