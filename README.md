# IQFeed-julia
 This Julia code is a very simple example of downloading real-time data from your IQFeed client.<br>
 The code does not implement Threads, Reactive code, or any of that good stuff.
 
 ### My Developemnt Environment
 
 Windows 11 Pro, version 22H2</br>
 Julia 1.8.5</br>
 Visual Studio Code 1.77.3
 IQFeed version 6.2.0.25.
 
 ### Running iqfeed.jl
 
 1. Load the iqfeed.jl source code into your version of Visual Studio Code and run it during market hours.</br>
    You should also be able to run code file in the Julia REPL.</br>
 2. The code starts the IQFeed Client, if it is not already running.<br>
    But first you will have to edit your account number and password.</br>
 3. A single symbol is defined to be "AAPL".<br>
    After the symbol is sent, the script downloads data until twenty Q-records for APPL are displayed.</br>
    The program then exits.

### Comments
This is my first Julia program, and I have huge training wheels on.</br>
Any comments or suggestions will be greatly appreciated.</br>

Charles
 
 
 

