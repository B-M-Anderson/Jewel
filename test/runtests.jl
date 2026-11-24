using Test
using Jewel

# Perft node counts from the Chess Programming Wiki "Perft Results" page.
# These were typed from memory: if one fails, check the wiki before debugging.
const PERFT_CASES = [
    ("startpos", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        [20, 400, 8902, 197281]),
    ("kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        [48, 2039, 97862, 4085603]),
    ("position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        [14, 191, 2812, 43238]),
    ("position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        [6, 264, 9467, 422333]),
    ("position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        [44, 1486, 62379, 2103487]),
    ("position 6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
        [46, 2079, 89890, 3894594]),
]

@testset "Jewel" begin
    @testset "fen" begin
        b = parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        @test b.pawns == 0x00ff00000000ff00
        @test b.white == 0x000000000000ffff
        @test b.black == 0xffff000000000000
        @test b.en_passant == 64
    end

    @testset "attack tables" begin
        @test Jewel.KNIGHT_ATTACKS[1] == 0x0000000000020400   # knight a1
        @test Jewel.KNIGHT_ATTACKS[28] == 0x0000142200221400  # knight d4
        @test Jewel.KING_ATTACKS[1] == 0x0000000000000302     # king a1
        @test Jewel.WHITE_PAWN_ATTACKS[1] == 0x0000000000000200  # white pawn a1
        @test Jewel.sliding_attacks(0, UInt64(0), Jewel.ROOK_DIRS) == 0x01010101010101fe
        @test Jewel.sliding_attacks(0, UInt64(1) << 24, Jewel.ROOK_DIRS) == 0x00000000010101fe
    end

    @testset "perft" begin
        for (name, fen, counts) in PERFT_CASES
            @testset "$name" begin
                board = parse_fen(fen)
                for (depth, expected) in enumerate(counts)
                    @test Jewel.perft(board, depth) == expected
                end
            end
        end
    end
end
