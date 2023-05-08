include("Market.jl")
using .Market
include("IQFeed.jl")
using .IQFeed

using Sockets
using REPL.Terminals

function parse_record(text::String)
    # The default format of the Q trade record looks like:
    #   Sym,     Last, Size,            Time, Total Volume,       Bid, Bid Size,      Ask, Ask Size,     Open,     High,     Low,     Close
    #   ----  --------  ----  ---------------  ------------   --------  --------  -------- ---------  --------  --------  -------- ---------
    # Q,AAPL, 167.2750,  100, 13:51:11.621788,   5,30547653,  167.2700,      100, 167.2800,      500, 165.1900, 167.4600, 165.1900, 163.7600,C,01,
    # Note: The "C" at then end means "Last Qualified Trade"
    fields = split(text, ',')
    symbol = fields[2]
    last   = parse(Float64, fields[3])
    shares = parse(Int64, fields[4])
    time   = fields[5]
    println("symbol: $(symbol): shares: $(shares), price: $(last), time: $(time)")
end

function read_stream()
    println("read_stream is calling init_socket.")
    ok, socket = IQFeed.init_socket()
    if !ok
        println("Client is not running, let's launch the IQFeed client, and try the connect again.")
        IQFeed.launch_iqconnect()
        ok, socket = IQFeed.init_socket()
        if !ok
            println("Could not launch IQFeed, aborting.")
            return
        end
    end
    println("IQFeed client is now running.")
    peername = getpeername(socket)
    println("socket: ip $(peername[1]), port $(peername[2])")

    println("Send the protocol request.");
    IQFeed.send_request("S,SET PROTOCOL,6.2\r\n",
                        "S,CURRENT PROTOCOL,6.2")

    println("Send a request to start real-time feed on AAPL.");
    global symbol = "AAPL"
    try
        write(socket, "w$(symbol)\r\n")
    catch err
        @error "write error on socket: $err"
        return
    end
    println("Sent $(symbol)");
    n_Q_records = 0

    while n_Q_records < 20
        # println("Calling: get_data_from_iq_client");
        text = ""
        try
            text = IQFeed.get_data_from_iq_client()
        catch err
            @error "Error: read error from the socket: $err"
            break
        end
        if isempty(text) || text == "error"
            break
        end
        fields = split(text, ',')
        if length(fields) > 0
            code = fields[1][1]
            # println("code: $(code)")
            if code == 'E'
                println("text: $(text)")
                continue
            end
            if code == 'S' || code == 'F'
                continue
            end
            if code == 'Q'
                # println("text: $(text)")
                n_Q_records = n_Q_records + 1
                if length(fields) > 12
                    parse_record(text)
                    continue
                end
            end
        end
    end
end

read_stream()