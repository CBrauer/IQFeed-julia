# IQFeed-julia
 This Julia code is a very simple example of downloading real-time data from your IQFeed client.<br>
 The code does not implement Threads, Reactive code, or any of that good stuff.
 
 ### My Developemnt Environment
 
 Windows 11 Pro, version 22H2</br>
 Julia 1.8.5</br>
 Visual Studio Code 1.77.3
 
 ### Running iqfeed.jl
 
 1. First, start your copy of the IQFeed Client. I am currently running version 6.2.0.25.
 2. Load the iqfeed.jl source code into your version of Visual Studio Code and run it during market hours.</br>
    You should also be able to run code file in the Julia REPL.
 3. The script first connects to the IQFeed client.</br>
    A single symbol is defined to be "AAPL".<br>
    After the symbol is sent, the script downloads data until three Q-records for APPL are displayed.</br>
    The program then exits.

### Comments
This is my first Julia program, and I have huge training wheels on.</br>
Any comments or suggestions will be greatly appreciated.</br>

Charles
 
 
 

