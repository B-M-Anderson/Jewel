function negamax(board, depth, ply)
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
        value = -negamax(next_board, depth - 1, ply + 1)
        best_value = max(best_value, value)
    end

    return best_value
end

function search(board, depth)
    moves = generate_legal_moves(board)
    best_move = UInt16(0)
    best_value = -100000

    for move in moves
        next_board = make_move(board, move)
        value = -negamax(next_board, depth - 1, 1)
        if value > best_value
            best_value = value
            best_move = move
        end
    end

    return best_move, best_value
end