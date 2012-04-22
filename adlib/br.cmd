@echo off
:: Build asalt.com, and run it if successful
nasm -o asalt.com asalt.asm && asalt.com
