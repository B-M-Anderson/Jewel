function print_board(board::Board)
    for rank in 7:-1:0
        for file in 0:7
            square = rank * 8 + file
            bit = UInt64(1) << square

            if (board.pawns & bit) != 0
                if (board.white & bit) != 0
                    print("P ")
                else
                    print("p ")
                end
            elseif (board.knights & bit) != 0
                if (board.white & bit) != 0
                    print("N ")
                else
                    print("n ")
                end
            elseif (board.bishops & bit) != 0
                if (board.white & bit) != 0
                    print("B ")
                else
                    print("b ")
                end
            elseif (board.rooks & bit) != 0
                if (board.white & bit) != 0
                    print("R ")
                else
                    print("r ")
                end
            elseif (board.queens & bit) != 0
                if (board.white & bit) != 0
                    print("Q ")
                else
                    print("q ")
                end
            elseif (board.kings & bit) != 0
                if (board.white & bit) != 0
                    print("K ")
                else
                    print("k ")
                end
            else
                print(". ")
            end
        end
        println()
    end
end