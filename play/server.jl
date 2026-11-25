# Local web server so you can play Jewel in your browser.
# Run from the jewel folder:   julia --project play/server.jl
# Then open http://localhost:8080
#
# Every finished game is appended to play/data/training.tsv (one line per position:
# FEN <tab> result from White's point of view: 1.0 white won, 0.5 draw, 0.0 black won)
# and to play/data/games.txt (one line per game, moves in UCI).

using Jewel
using Sockets
using Dates

const PORT = 8080
const DATA_DIR = joinpath(@__DIR__, "data")
const START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const RANDOM_ENGINE_PLIES = 2   # Jewel's first N moves are random, so games don't all repeat

# ---------------------------------------------------------------- Board -> FEN

function piece_char(b, sq::Int)
    bit = UInt64(1) << sq
    c = ' '
    if (b.pawns & bit) != 0
        c = 'p'
    elseif (b.knights & bit) != 0
        c = 'n'
    elseif (b.bishops & bit) != 0
        c = 'b'
    elseif (b.rooks & bit) != 0
        c = 'r'
    elseif (b.queens & bit) != 0
        c = 'q'
    elseif (b.kings & bit) != 0
        c = 'k'
    end
    if c != ' ' && (b.white & bit) != 0
        c = uppercase(c)
    end
    return c
end

function board_to_fen(b)
    rows = String[]
    for rank in 7:-1:0
        row = ""
        empty = 0
        for file in 0:7
            c = piece_char(b, rank * 8 + file)
            if c == ' '
                empty += 1
            else
                if empty > 0
                    row *= string(empty)
                    empty = 0
                end
                row *= string(c)
            end
        end
        if empty > 0
            row *= string(empty)
        end
        push!(rows, row)
    end
    side = b.white_to_move ? "w" : "b"
    castle = ""
    b.white_castle_kingside && (castle *= "K")
    b.white_castle_queenside && (castle *= "Q")
    b.black_castle_kingside && (castle *= "k")
    b.black_castle_queenside && (castle *= "q")
    castle == "" && (castle = "-")
    ep_sq = Int(b.en_passant)
    ep = ep_sq == 64 ? "-" : string('a' + (ep_sq % 8), 1 + (ep_sq ÷ 8))
    return join(rows, "/") * " " * side * " " * castle * " " * ep * " " *
           string(Int(b.halfmove_clock)) * " " * string(Int(b.fullmove_number))
end

position_key(fen) = join(split(fen)[1:4], " ")

# ---------------------------------------------------------------- Game state

mutable struct Game
    board::Jewel.Board
    human_white::Bool
    moves::Vector{String}
    fens::Vector{String}
    keys::Dict{String,Int}
    over::Bool
    result::String
    reason::String
    last::String
    info::String
    think_ms::Int
    engine_moves::Int
    saved::Bool
    static_evals::Vector{Int}      # Jewel's static evaluation after each ply, White's point of view
    search_evals::Vector{Any}      # Jewel's search score after each ply it played (else nothing), White's view
    think_log::Vector{String}      # per-depth search records for Jewel's latest move (JSON objects)
end

const GAME = Ref{Union{Nothing,Game}}(nothing)

function new_game(human_white::Bool, think_ms::Int)
    b = Jewel.parse_fen(START_FEN)
    fen = board_to_fen(b)
    keys = Dict{String,Int}(position_key(fen) => 1)
    return Game(b, human_white, String[], [fen], keys, false, "*", "", "", "", think_ms, 0, false,
                [0], Any[nothing], String[])
end

function insufficient_material(b)
    return (b.pawns | b.rooks | b.queens) == 0 && count_ones(b.knights | b.bishops) <= 1
end

function save_game(g::Game)
    if g.saved
        return
    end
    g.saved = true
    mkpath(DATA_DIR)
    white_score = g.result == "1-0" ? "1.0" : (g.result == "0-1" ? "0.0" : "0.5")
    open(joinpath(DATA_DIR, "training.tsv"), "a") do io
        for fen in g.fens[2:end]          # every position after a move; the start position is skipped
            println(io, fen, "\t", white_score)
        end
    end
    open(joinpath(DATA_DIR, "games.txt"), "a") do io
        stamp = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
        println(io, stamp, "\thuman=", g.human_white ? "white" : "black", "\tresult=", g.result,
                "\treason=", g.reason, "\tplies=", length(g.moves), "\t", join(g.moves, " "))
    end
    println("saved game: ", g.result, " (", g.reason, "), ", length(g.fens) - 1, " positions logged")
end

function finish!(g::Game, result::String, reason::String)
    g.over = true
    g.result = result
    g.reason = reason
    save_game(g)
end

function check_end!(g::Game)
    b = g.board
    legal = Jewel.generate_legal_moves(b)
    if isempty(legal)
        ours = b.white_to_move ? b.white : b.black
        if Jewel.is_square_attacked(b, trailing_zeros(b.kings & ours), !b.white_to_move)
            finish!(g, b.white_to_move ? "0-1" : "1-0", "checkmate")
        else
            finish!(g, "1/2-1/2", "stalemate")
        end
    elseif b.halfmove_clock >= 100
        finish!(g, "1/2-1/2", "fifty-move rule")
    elseif g.keys[position_key(g.fens[end])] >= 3
        finish!(g, "1/2-1/2", "threefold repetition")
    elseif insufficient_material(b)
        finish!(g, "1/2-1/2", "insufficient material")
    end
end

function apply_move!(g::Game, move)
    push!(g.moves, Jewel.move_to_string(move))
    g.last = g.moves[end]
    g.board = Jewel.make_move(g.board, move)
    fen = board_to_fen(g.board)
    push!(g.fens, fen)
    k = position_key(fen)
    g.keys[k] = get(g.keys, k, 0) + 1
    e = Jewel.evaluate(g.board)                       # relative to the side to move
    push!(g.static_evals, g.board.white_to_move ? e : -e)
    push!(g.search_evals, nothing)
    check_end!(g)
end

function find_move(board, uci)
    for m in Jewel.generate_legal_moves(board)
        if Jewel.move_to_string(m) == uci
            return m
        end
    end
    return nothing
end

function engine_move!(g::Game)
    legal = Jewel.generate_legal_moves(g.board)
    empty!(g.think_log)
    score = nothing
    if g.engine_moves < RANDOM_ENGINE_PLIES
        move = rand(legal)
        g.info = "random opening move"
    else
        start = time_ns()
        move = UInt16(0)
        value = 0
        for depth in 1:12
            t0 = time_ns()
            move, value = Jewel.search(g.board, depth)
            t1 = time_ns()
            step_ms = (t1 - t0) / 1e6
            cum_ms = (t1 - start) / 1e6
            push!(g.think_log, "{\"d\":" * string(depth) * ",\"m\":" * js(Jewel.move_to_string(move)) *
                               ",\"s\":" * string(value) * ",\"ms\":" * string(round(step_ms, digits = 2)) *
                               ",\"cum\":" * string(round(cum_ms, digits = 1)) * "}")
            if cum_ms > g.think_ms / 2 || abs(value) > 29000
                break
            end
        end
        score = value
        g.info = "searched to depth $(length(g.think_log)), score $value (Jewel's view, centipawns)"
    end
    white_was_to_move = g.board.white_to_move
    g.engine_moves += 1
    apply_move!(g, move)
    if score !== nothing
        g.search_evals[end] = white_was_to_move ? score : -score
    end
end

# ---------------------------------------------------------------- JSON by hand

js(s::AbstractString) = "\"" * s * "\""
err(msg) = "{\"error\":" * js(msg) * "}"

const BB_NAMES = (:pawns, :knights, :bishops, :rooks, :queens, :kings, :white, :black)

function move_kind(m)
    f = Int(m >> 12)
    if f == 5
        return "en passant"
    elseif f >= 12
        return "promotion capture"
    elseif f == 4
        return "capture"
    elseif f >= 8
        return "promotion"
    elseif f == 2 || f == 3
        return "castle"
    elseif f == 1
        return "double push"
    end
    return "quiet"
end

nullable(x) = x === nothing ? "null" : string(x)

function state_json(g::Game)
    b = g.board
    moves = Jewel.generate_legal_moves(b)
    legal = [Jewel.move_to_string(m) for m in moves]
    ordered = copy(moves)
    sort!(ordered, by = m -> Jewel.score_move(b, m), rev = true)
    order_items = [ "{\"m\":" * js(Jewel.move_to_string(m)) * ",\"s\":" * string(Jewel.score_move(b, m)) *
                    ",\"k\":" * js(move_kind(m)) * "}" for m in ordered ]
    last_search = nothing
    for x in g.search_evals
        if x !== nothing
            last_search = x
        end
    end
    bb_items = [ "\"" * string(n) * "\":" * js(string(getfield(b, n), base = 16, pad = 16)) for n in BB_NAMES ]
    att = join([ string((Jewel.is_square_attacked(b, sq, true) ? 1 : 0) + (Jewel.is_square_attacked(b, sq, false) ? 2 : 0)) for sq in 0:63 ])
    parts = String[]
    push!(parts, "\"fen\":" * js(g.fens[end]))
    push!(parts, "\"legal\":[" * join(js.(legal), ",") * "]")
    push!(parts, "\"order\":[" * join(order_items, ",") * "]")
    push!(parts, "\"moves\":[" * join(js.(g.moves), ",") * "]")
    push!(parts, "\"last\":" * js(g.last))
    push!(parts, "\"over\":" * string(g.over))
    push!(parts, "\"result\":" * js(g.result))
    push!(parts, "\"reason\":" * js(g.reason))
    push!(parts, "\"human\":" * js(g.human_white ? "w" : "b"))
    push!(parts, "\"turn\":" * js(b.white_to_move ? "w" : "b"))
    push!(parts, "\"info\":" * js(g.info))
    push!(parts, "\"static_cp\":" * string(g.static_evals[end]))
    push!(parts, "\"search_cp\":" * nullable(last_search))
    push!(parts, "\"static_series\":[" * join(string.(g.static_evals), ",") * "]")
    push!(parts, "\"search_series\":[" * join(nullable.(g.search_evals), ",") * "]")
    push!(parts, "\"features\":[" * join(string.(Jewel.material_features(b)), ",") * "]")
    push!(parts, "\"weights\":[" * join(string.(Jewel.WEIGHTS), ",") * "]")
    push!(parts, "\"bb\":{" * join(bb_items, ",") * "}")
    push!(parts, "\"att\":" * js(att))
    push!(parts, "\"think\":[" * join(g.think_log, ",") * "]")
    return "{" * join(parts, ",") * "}"
end

# Scores every legal move for the side to move with a full-window search to `depth`.
# (Slower than the real search because nothing is shared between root moves, so keep depth <= 4.)
function analyze_json(g::Game, depth::Int)
    b = g.board
    res = Tuple{String,Int}[]
    for m in Jewel.generate_legal_moves(b)
        nb = Jewel.make_move(b, m)
        v = -Jewel.negamax(nb, depth - 1, 1, -100000, 100000)
        push!(res, (Jewel.move_to_string(m), v))
    end
    sort!(res, by = r -> r[2], rev = true)
    items = [ "{\"m\":" * js(r[1]) * ",\"s\":" * string(r[2]) * "}" for r in res ]
    return "{\"depth\":" * string(depth) * ",\"moves\":[" * join(items, ",") * "]}"
end

# ---------------------------------------------------------------- API routes

function api(path, params)
    if path == "/api/new"
        human_white = get(params, "color", "w") == "w"
        think_ms = parse(Int, get(params, "ms", "1000"))
        g = new_game(human_white, think_ms)
        GAME[] = g
        return state_json(g)
    end

    g = GAME[]
    if g === nothing
        return err("no game yet")
    end

    if path == "/api/move"
        if g.over
            return err("the game is over")
        end
        if g.board.white_to_move != g.human_white
            return err("not your turn")
        end
        m = find_move(g.board, get(params, "uci", ""))
        if m === nothing
            return err("illegal move")
        end
        apply_move!(g, m)
    elseif path == "/api/engine"
        if g.over || g.board.white_to_move == g.human_white
            return err("not Jewel's turn")
        end
        engine_move!(g)
    elseif path == "/api/resign"
        if !g.over
            finish!(g, g.human_white ? "0-1" : "1-0", "resignation")
        end
    elseif path == "/api/analyze"
        if g.over
            return err("the game is over")
        end
        depth = clamp(parse(Int, get(params, "depth", "3")), 1, 4)
        return analyze_json(g, depth)
    elseif path != "/api/state"
        return err("unknown request")
    end
    return state_json(g)
end

# ---------------------------------------------------------------- tiny HTTP server

function parse_query(qs)
    d = Dict{String,String}()
    for kv in split(qs, '&'; keepempty = false)
        p = split(kv, '='; limit = 2)
        d[String(p[1])] = length(p) == 2 ? String(p[2]) : ""
    end
    return d
end

function respond(sock, status, ctype, body)
    head = "HTTP/1.1 $status\r\nContent-Type: $ctype\r\nContent-Length: $(sizeof(body))\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
    write(sock, head)
    write(sock, body)
end

function handle(sock)
    try
        line = readline(sock)
        while true                      # skip the headers
            h = readline(sock)
            if isempty(strip(h))
                break
            end
        end
        if isempty(strip(line))
            return                      # browsers sometimes open empty connections
        end
        parts = split(line, ' ')
        target = length(parts) >= 2 ? String(parts[2]) : "/"
        pq = split(target, '?'; limit = 2)
        path = String(pq[1])
        qs = length(pq) == 2 ? String(pq[2]) : ""
        if path == "/" || path == "/index.html"
            respond(sock, "200 OK", "text/html; charset=utf-8", read(joinpath(@__DIR__, "index.html"), String))
        elseif startswith(path, "/api/")
            respond(sock, "200 OK", "application/json", api(path, parse_query(qs)))
        else
            respond(sock, "404 Not Found", "text/plain", "not found")
        end
    catch e
        @warn "request failed" exception = (e, catch_backtrace())
        try
            respond(sock, "500 Internal Server Error", "application/json", err(sprint(showerror, e)))
        catch
        end
    finally
        close(sock)
    end
end

server = listen(Sockets.localhost, PORT)
println("Jewel is ready: open http://localhost:$PORT in your browser (Ctrl+C here to stop)")
while true
    sock = accept(server)
    @async handle(sock)
end
