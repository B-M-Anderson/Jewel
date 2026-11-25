play/  --  throwaway frontend for playing Jewel. Delete this whole folder any time; nothing else depends on it.

Run (from the jewel folder):
    julia --project play/server.jl
then open http://localhost:8080

Files:
    server.jl             local web server + game logic (uses Jewel's move generator and iterative_search)
    index.html            the board in your browser
    train_from_games.jl   fits the material weights to your saved games (prints only)
    data/training.tsv     created after your first finished game: FEN <tab> result (1.0 / 0.5 / 0.0, White's view)
    data/games.txt        created after your first finished game: one line per game, moves in UCI

Visualizations (all read from Jewel's own functions):
    eval bar            search score if Jewel has searched, else static material eval (White's view)
    attack map          squares Jewel's is_square_attacked says each side hits (toggle above the board)
    candidate arrows    full-window search of each of your legal moves at depth 2-4 (toggle above the board)
    search table        per-depth best move, score, time, and the cost growth between depths
    eval graph          static eval and search scores over the game
    features x weights  the material features, the weights from eval.jl, and each contribution
    move ordering       legal moves in the order alpha-beta searches them
    bitboards           the eight UInt64 boards drawn as 8x8 grids with their hex values
