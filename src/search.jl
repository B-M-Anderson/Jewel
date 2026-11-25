function negamax_plain(board, depth, ply)
    if depth == 0
        return evaluate(board)
    end
    
    moves = generate_legal_moves(board)
    if isempty(moves)
        if board.white_to_move
            ours = board.white
        else
            ours = board.black
        end

        if is_square_attacked(board, trailing_zeros(board.kings & ours), !board.white_to_move)
            return -30000 + ply
        else
            return 0
        end
    end

    best_value = -100000
    for move in moves
        next_board = make_move(board, move)
        value = -negamax_plain(next_board, depth - 1, ply + 1)
        best_value = max(best_value, value)
    end

    return best_value
end

function piece_on(board, sqrt)
    bit = UInt64(1) << sqrt
    if (board.pawns & bit) != 0
        return 1
    elseif (board.knights & bit) != 0
        return 2
    elseif (board.bishops & bit) != 0
        return 3
    elseif (board.rooks & bit) != 0
        return 4
    elseif (board.queens & bit) != 0
        return 5
    elseif (board.kings & bit) != 0
        return 6
    else
        return 0
    end
end

function score_move(board, move)
    from_sq = Int(move & 0x3F)
    to_sq = Int((move >>6) & 0x3F)
    victim = piece_on(board, to_sq)
    if victim == 0
        return 0
    end

    attacker = piece_on(board, from_sq)

    return 1000 + 10 * victim - attacker
end

function qsearch(board, alpha, beta)
    stand_pat = evaluate(board)
    if stand_pat >= beta
        return stand_pat
    end
    if alpha < stand_pat
        alpha = stand_pat
    end

    moves = generate_legal_moves(board)
    sort!(moves, by = m -> score_move(board, m), rev = true)

    for move in moves
        flag = Int(move >> 12)
        if !(flag == 4 || flag == 5 || flag >= 12)  
            continue
        end
        next_board = make_move(board, move)
        value = -qsearch(next_board, -beta, -alpha)
        if value > alpha
            alpha = value
        end
        if alpha >= beta
            break
        end
    end

    return alpha
end

function negamax(board, depth, ply, alpha, beta)
    if depth == 0
        return qsearch(board, alpha, beta)
    end
    
    moves = generate_legal_moves(board)
    sort!(moves, by = m -> score_move(board, m), rev = true)
    if isempty(moves)
        if board.white_to_move
            ours = board.white
        else
            ours = board.black
        end

        if is_square_attacked(board, trailing_zeros(board.kings & ours), !board.white_to_move)
            return -30000 + ply
        else
            return 0
        end
    end

    best_value = -100000
    for move in moves
        next_board = make_move(board, move)
        value = -negamax(next_board, depth - 1, ply + 1, -beta, -alpha)
        best_value = max(best_value, value)
        if value > alpha
            alpha = value
        end
        if alpha >= beta
            break
        end
    end

    return best_value
end

function search(board, depth)
    moves = generate_legal_moves(board)
    sort!(moves, by = m -> score_move(board, m), rev = true)
    best_move = UInt16(0)
    best_value = -100000

    for move in moves
        next_board = make_move(board, move)
        value = -negamax(next_board, depth - 1, 1, -100000, -best_value)
        if value > best_value
            best_value = value
            best_move = move
        end
    end

    return best_move, best_value
end

function iterative_search(board, max_depth, time_limit_ms)
    start = time_ns()
    best_move = UInt16(0)
    best_value = 0

    for depth in 1:max_depth
        move, value = search(board, depth)
        best_move = move
        best_value = value
        elapsed_ms = (time_ns() - start) / 1e6
        println("depth ", depth, "  score ", value, "  move ", move_to_string(move), "  ", round(elapsed_ms, digits = 1), " ms")
        #if abs(value) >= 29000
        #    break
        #end
        if elapsed_ms > time_limit_ms / 2
            break
        end
    end

    return best_move, best_value
end