# UCI protocol: lets chess GUIs and tournament tools (Cute Chess, lichess-bot) talk to Jewel
# over stdin/stdout. Plumbing only; the engine itself is search.jl and eval.jl.
#
# Run it with:  julia --project=C:\Users\benne\jewel -e "using Jewel; Jewel.uci_loop()"
# (jewel_uci.bat in the project root does exactly that.)

const UCI_START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

function uci_out(s)
    println(stdout, s)
    flush(stdout)
end

function uci_find_move(board, text)
    for m in generate_legal_moves(board)
        if move_to_string(m) == text
            return m
        end
    end
    return nothing
end

# "position startpos [moves ...]"  or  "position fen <6 fields> [moves ...]"
function uci_position(tokens)
    n = length(tokens)
    moves_at = findfirst(==("moves"), tokens)
    last_fen_token = moves_at === nothing ? n : moves_at - 1
    if n >= 2 && tokens[2] == "startpos"
        board = parse_fen(UCI_START_FEN)
    elseif n >= 3 && tokens[2] == "fen"
        board = parse_fen(join(tokens[3:last_fen_token], " "))
    else
        return parse_fen(UCI_START_FEN)
    end
    if moves_at !== nothing
        for text in tokens[moves_at+1:end]
            m = uci_find_move(board, String(text))
            if m === nothing
                break
            end
            board = make_move(board, m)
        end
    end
    return board
end

function uci_score(value)
    if abs(value) > 29000
        plies = 30000 - abs(value)
        n = (plies + 1) ÷ 2
        return "mate " * string(value > 0 ? n : -n)
    end
    return "cp " * string(value)
end

function uci_go(board, tokens)
    wtime = -1
    btime = -1
    winc = 0
    binc = 0
    movestogo = 30
    movetime = -1
    depth_limit = 64
    fixed_depth = false
    i = 2
    while i <= length(tokens)
        t = tokens[i]
        if t == "wtime" && i < length(tokens)
            wtime = parse(Int, tokens[i+1]); i += 2
        elseif t == "btime" && i < length(tokens)
            btime = parse(Int, tokens[i+1]); i += 2
        elseif t == "winc" && i < length(tokens)
            winc = parse(Int, tokens[i+1]); i += 2
        elseif t == "binc" && i < length(tokens)
            binc = parse(Int, tokens[i+1]); i += 2
        elseif t == "movestogo" && i < length(tokens)
            movestogo = max(1, parse(Int, tokens[i+1])); i += 2
        elseif t == "movetime" && i < length(tokens)
            movetime = parse(Int, tokens[i+1]); i += 2
        elseif t == "depth" && i < length(tokens)
            depth_limit = parse(Int, tokens[i+1]); fixed_depth = true; i += 2
        else
            i += 1
        end
    end

    # how long may this move take, in milliseconds
    if fixed_depth
        budget = 10^9
    elseif movetime > 0
        budget = max(10, movetime - 30)
    elseif wtime >= 0 || btime >= 0
        mine = board.white_to_move ? wtime : btime
        inc = board.white_to_move ? winc : binc
        mine = max(mine, 0)
        budget = mine ÷ movestogo + (inc * 3) ÷ 4
        budget = min(budget, mine ÷ 2)
        budget = max(budget, 20)
    else
        budget = 5000      # "go infinite" or a bare "go": think for 5 seconds
    end

    legal = generate_legal_moves(board)
    if isempty(legal)
        uci_out("bestmove 0000")
        return
    end
    if length(legal) == 1 && !fixed_depth
        uci_out("bestmove " * move_to_string(legal[1]))
        return
    end

    start = time_ns()
    best = legal[1]
    prev_ms = 0.0
    for depth in 1:depth_limit
        t0 = time_ns()
        move, value = search(board, depth)
        t1 = time_ns()
        best = move
        step_ms = (t1 - t0) / 1e6
        elapsed_ms = (t1 - start) / 1e6
        uci_out("info depth $depth score $(uci_score(value)) time $(round(Int, elapsed_ms)) pv $(move_to_string(move))")
        if abs(value) > 29000 && !fixed_depth
            break
        end
        # the next depth costs roughly 5x this one; don't start it if it would blow the budget
        if !fixed_depth && elapsed_ms + 5 * step_ms > budget
            break
        end
    end
    uci_out("bestmove " * move_to_string(best))
end

function uci_loop()
    board = parse_fen(UCI_START_FEN)
    warmed = false
    while !eof(stdin)
        line = strip(readline(stdin))
        if isempty(line)
            continue
        end
        tokens = split(line)
        cmd = tokens[1]
        if cmd == "uci"
            uci_out("id name Jewel")
            uci_out("id author Bennett Anderson")
            uci_out("uciok")
        elseif cmd == "isready"
            if !warmed
                search(parse_fen(UCI_START_FEN), 3)   # compile everything now, so the first real move isn't slow
                warmed = true
            end
            uci_out("readyok")
        elseif cmd == "ucinewgame"
            board = parse_fen(UCI_START_FEN)
        elseif cmd == "position"
            board = uci_position(tokens)
        elseif cmd == "go"
            uci_go(board, tokens)
        elseif cmd == "quit"
            break
        end
        # setoption, debug, stop, ponderhit and anything unknown are ignored
    end
end
