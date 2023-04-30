using Sockets
using Dates
using TimeZones
using REPL.Terminals
using InteractiveUtils

function display(text::String)
    # Log.WriteLog(text)
    # sub_text = text[1:min(length(text), 80)]
    # println(sub_text)
    
    println(text)
end

function is__market_open()
    # 1. Check to see if today is on the week-end
    day_of_week = Dates.dayofweek(today())
    if day_of_week == 6 || day_of_week == 7
        name_of_day = Dates.dayname(day_of_week)
        display("Today is $name_of_day.")
        return false
    end
    # 2. Check to see if today is a holiday.
    # This list should be in a Dataframe so that we do not need to edit this code.
    holidays = [Date(2023,5,2), Date(2023,6,19), Date(2023,7,4), Date(2023,9,4), Date(2023,11,23), Date(2023,12,25)]
    if Date(now()) in holidays
        display("Today is a holiday. Go back to bed.")
        return false
    end
    # 3. Now check the time in New York City to see if the markets are open.
    ny_time = now(tz"America/New_York")
    if (Dates.hour(ny_time) > 9 || (Dates.hour(ny_time) == 9 && Dates.minute(ny_time) >= 30)) &&
       (Dates.hour(ny_time) < 16)
        display("market is open.")
        return true
    else
        display("market is closed.")
        return false
    end
end

function socket_init()
    display("At socket_init.")
    try
        # Connect to the server and display socket and peer details
        inet_addr = Sockets.InetAddr(IPv4("127.0.0.1"), 5009)
        global socket = Sockets.connect(inet_addr)
        sockname = getsockname(socket)
        peername = getpeername(socket)
        display("ip $(sockname[1]), port $(sockname[2])")
        display("ip $(peername[1]), port $(peername[2])")
        display("socket has been initialized.")
        return true
    catch err
        if err.code == Base.UV_ECONNREFUSED
            # @error "Error in intializing the socket: $err"
            return false
        end
    end
end

function send_byte_message(text::String)
    try
        if is_connected()
            display("send_message: '$(text)'")
            output_buffer = Vector{UInt8}(text)
            println(output_buffer)
            write(socket, output_buffer)
            return
        end
        display("Drat! send_message lost socket connection.")
    catch err
        display("send_message error: $err")
    end
end

function send_raw_message(text::String)
    try
        display("send_raw_message: '$(text)'")
        write(socket, text)
    catch err
        display("send_message error: $err")
    end
end

function send_request(request::String, expected_response::String)
    send_raw_message(request)
    for loop in 1:10
        response = readline(socket)
        display("  loop: $(loop), response from send_request: $(response)")
        if isempty(response)
            break
        end
        text = strip(response)
        if occursin(expected_response, text)
            display("response got the expected response: $(expected_response)")
            return
        end
    end
    display("We did not get the expected response: $(expected_response)");
end

function get_data_from_iq_client()
    # display("Starting get_data_from_iq_client.")
    try
        text = readline(socket)
        # display("get_data_from_iq_client: '$(text)'")
        return text
    catch err
        display("get_data_from_iq_client error: $err")
        return "error"
    end
end

function parse_record(text::String)
    # The default format of the Q trade record looks like:
    #   Sym,     Last, Size,            Time, Total Volume,       Bid, Bid Size,      Ask, Ask Size,     Open,     High,     Low,     Close
    #   ----  --------  ----  ---------------  ------------   --------  --------  -------- ---------  --------  --------  -------- ---------
    # Q,AAPL, 167.2750,  100, 13:51:11.621788,   5,30547653,  167.2700,      100, 167.2800,      500, 165.1900, 167.4600, 165.1900, 163.7600,C,01,
    fields = split(text, ',')
    symbol = fields[2]
    last   = parse(Float64, fields[3])
    shares = parse(Int64, fields[4])
    time   = fields[5]
    display("symbol: $(symbol): shares: $(shares), price: $(last), time: $(time)")
end

function read_stream()
    display("Connecting to the IQFeed client.")
    if !socket_init()
        display("Client is not running, let's start the IQFeed client.")
        try
            arguments = "<your login arguments go here>"
            run(`iqconnect`, arguments, true)
        catch err
            @error "Error starting iqconnect: $err"
            return
        end
        display("Sleeping for 5 seconds.")
        sleep(5)
        display("IQFeed client is now running.")
    end

    display("Send the protocol request.");
    send_request("S,SET PROTOCOL,6.2\r\n",
                 "S,CURRENT PROTOCOL,6.2")

    display("Send a request to start real-time feed on AAPL.");
    global symbol = "AAPL"
    write(socket, "w$(symbol)\r\n")
    display("Sent $(symbol)");
    n_Q_records = 0

    while n_Q_records < 3
        # display("Calling: get_data_from_iq_client");
        text = get_data_from_iq_client()
        if isempty(text) || text == "error"
            break
        end
        fields = split(text, ',')
        if length(fields) > 0
            code = fields[1][1]
            # display("code: $(code)")
            if code == 'E'
                display("text: $(text)")
                continue
            end
            if code == 'S' || code == 'F'
                continue
            end
            if code == 'Q'
                # Display("text: $(text)")
                n_Q_records = n_Q_records + 1
                if length(fields) > 12
                    parse_record(text)
                end
            end
        end
    end
    display("read_stream, the market is closed")
end


if is__market_open()
    read_stream()
else
    display("The market is closed.")
    print("Do you still want to proceed (y/n):")
    key = read(stdin, Char)
    if key == 'y'
        display("\nOK, let's connect to IQFeed.")
        read_stream()
    end
    display("Done.")
end