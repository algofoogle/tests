@echo off
:: Build asalt.com, and run it if successful
nasm -o asalt.com asalt.s && asalt.com
