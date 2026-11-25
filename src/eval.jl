const WEIGHTS = [100, 300, 300, 500, 900]

function material_features(board::Board)
    features = zeros(Int, 5)
    features[1] = count_ones(board.pawns & board.white) - count_ones(board.pawns & board.black)
    features[2] = count_ones(board.knights & board.white) - count_ones(board.knights & board.black)
    features[3] = count_ones(board.bishops & board.white) - count_ones(board.bishops & board.black)
    features[4] = count_ones(board.rooks & board.white) - count_ones(board.rooks & board.black)
    features[5] = count_ones(board.queens & board.white) - count_ones(board.queens & board.black)
    return features
end

function evaluate(board::Board)
    features = material_features(board)
    if board.white_to_move
        return sum(WEIGHTS[i] * features[i] for i in 1:5)
    else
        return -sum(WEIGHTS[i] * features[i] for i in 1:5)
    end
end


