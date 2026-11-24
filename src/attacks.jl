function make_attack_tables()
 knight_attacks = zeros(UInt64, 64)
 king_attacks = zeros(UInt64, 64)
 white_pawn_attacks = zeros(UInt64, 64)
 black_pawn_attacks = zeros(UInt64, 64)

 for sq in 0:63
     file = sq % 8
     rank = div(sq,8)
     knight_moves = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
     king_moves = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
     pawn_moves_white = [(-1, 1), (1, 1)]
     pawn_moves_black = [(-1, -1), (1, -1)]

     for (df, dr) in knight_moves
         new_file = file + df
         new_rank = rank + dr
         if new_file >= 0 && new_file < 8 && new_rank >= 0 && new_rank < 8
             target_sq = new_rank * 8 + new_file
             knight_attacks[sq + 1] |= UInt64(1) << target_sq
         end
     end

    for (df, dr) in king_moves
            new_file = file + df
            new_rank = rank + dr
            if new_file >= 0 && new_file < 8 && new_rank >= 0 && new_rank < 8
                target_sq = new_rank * 8 + new_file
                king_attacks[sq + 1] |= UInt64(1) << target_sq
            end
    end
    for (df, dr) in pawn_moves_white
        new_file = file + df
        new_rank = rank + dr
        if new_file >= 0 && new_file < 8 && new_rank >= 0 && new_rank < 8
            target_sq = new_rank * 8 + new_file
            white_pawn_attacks[sq + 1] |= UInt64(1) << target_sq
        end
    end 
    for (df, dr) in pawn_moves_black
        new_file = file + df
        new_rank = rank + dr
        if new_file >= 0 && new_file < 8 && new_rank >= 0 && new_rank < 8
            target_sq = new_rank * 8 + new_file
            black_pawn_attacks[sq + 1] |= UInt64(1) << target_sq
        end
    end
 end
    return knight_attacks, king_attacks, white_pawn_attacks, black_pawn_attacks
end

const KNIGHT_ATTACKS, KING_ATTACKS, WHITE_PAWN_ATTACKS, BLACK_PAWN_ATTACKS = make_attack_tables()
const ROOK_DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]
const BISHOP_DIRS = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

function sliding_attacks(sq, occupied, dirs)
    attacks = UInt64(0)
    file = sq % 8
    rank = div(sq, 8)

    for (df, dr) in dirs
        new_file = file + df
        new_rank = rank + dr
        while new_file >= 0 && new_file < 8 && new_rank >= 0 && new_rank < 8
            target_sq = new_rank * 8 + new_file
            attacks |= UInt64(1) << target_sq
            if (occupied & (UInt64(1) << target_sq)) != 0
                break
            end
            new_file += df
            new_rank += dr
        end
    end

    return attacks
end

function is_square_attacked(board::Board, sq::Int, by_white::Bool)::Bool
    attacker = by_white ? board.white : board.black
    occupied = board.white | board.black

    # 1. Pawns (reverse direction!)
    pawn_mask = by_white ? BLACK_PAWN_ATTACKS[sq + 1] : WHITE_PAWN_ATTACKS[sq + 1]
    if (pawn_mask & board.pawns & attacker) != 0
        return true
    end

    # 2. Knights
    if (KNIGHT_ATTACKS[sq + 1] & board.knights & attacker) != 0
        return true
    end

    # 3. Kings
    if (KING_ATTACKS[sq + 1] & board.kings & attacker) != 0
        return true
    end

    # 4. Rooks and Queens (orthogonal rays)
    if (sliding_attacks(sq, occupied, ROOK_DIRS) & (board.rooks | board.queens) & attacker) != 0
        return true
    end

    # 5. Bishops and Queens (diagonal rays)
    if (sliding_attacks(sq, occupied, BISHOP_DIRS) & (board.bishops | board.queens) & attacker) != 0
        return true
    end

    return false
end