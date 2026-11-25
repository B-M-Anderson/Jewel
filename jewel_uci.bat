@echo off
julia --project="%~dp0." --startup-file=no -e "using Jewel; Jewel.uci_loop()"
