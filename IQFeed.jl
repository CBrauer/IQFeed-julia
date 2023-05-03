using Sockets
using Dates
using TimeZones
using REPL.Terminals
using InteractiveUtils
using DataFrames
using ODBC

function is_today_a_holiday()
    dsn = "Driver={ODBC Driver 17 for SQL Server}; Server=BIGSUR; Database=Securities; Trusted_Connection=yes;"
    conn = ODBC.Connection(dsn)
    holidays = DBInterface.execute(conn, "SELECT Month, Day, Year FROM dbo.Holidays") |> DataFrame
    holidays[!, :Date] = Date.(holidays.Year, holidays.Month, holidays.Day)
    holidays.Date = Date.(holidays.Date)
    # Define the date to check, 
    todays_date = Date(now())
    is_holiday = any(holidays.Date .== todays_date)
    return is_holiday
end

function is__market_open()
    # 1. Check to see if today is on the week-end
    day_of_week = Dates.dayofweek(today())
    if day_of_week == 6 || day_of_week == 7
        name_of_day = Dates.dayname(day_of_week)
        println("Today is $name_of_day.")
        return false
    end

    # 2. Check to see if today is a holiday.
    # holidays = [Date(2023,5,2), Date(2023,6,19), Date(2023,7,4), Date(2023,9,4), Date(2023,11,23), Date(2023,12,25)]
    # A Better way than hard coding is to get the holidays from the SQL Server table
    if is_today_a_holiday()
        println("Today is a holiday. Go back to bed.")
        return false
    end

    # 3. Now check the time in New York City to see if the markets are open.
    ny_time = now(tz"America/New_York")
    if (Dates.hour(ny_time) > 9 || (Dates.hour(ny_time) == 9 && Dates.minute(ny_time) >= 30)) &&
       (Dates.hour(ny_time) < 16)
        println("market is open.")
        return true
    else
        println("market is closed.")
        return false
    end
end

function my_socket_init()
    println("At socket_init.")
    try
        # Connect to the server and println socket and peer details
        inet_addr = Sockets.InetAddr(IPv4("127.0.0.1"), 5009)
        global socket = Sockets.connect(inet_addr)
        sockname = getsockname(socket)
        peername = getpeername(socket)
        println("ip $(sockname[1]), port $(sockname[2])")
        println("ip $(peername[1]), port $(peername[2])")
        println("socket has been initialized.")
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
            println("send_message: '$(text)'")
            output_buffer = Vector{UInt8}(text)
            println(output_buffer)
            write(socket, output_buffer)
            return
        end
        println("Drat! send_message lost socket connection.")
    catch err
        println("send_message error: $err")
    end
end

function send_raw_message(text::String)
    try
        println("send_raw_message: '$(text)'")
        write(socket, text)
    catch err
        println("send_message error: $err")
    end
end

function send_request(request::String, expected_response::String)
    send_raw_message(request)
    for loop in 1:10
        response = readline(socket)
        println("  loop: $(loop), response from send_request: $(response)")
        if isempty(response)
            break
        end
        text = strip(response)
        if occursin(expected_response, text)
            println("response got the expected response: $(expected_response)")
            return
        end
    end
    println("We did not get the expected response: $(expected_response)");
end

function get_data_from_iq_client()
    # println("Starting get_data_from_iq_client.")
    try
        text = readline(socket)
        # println("get_data_from_iq_client: '$(text)'")
        return text
    catch err
        println("get_data_from_iq_client error: $err")
        return "error"
    end
end

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

function start_iqconnect()
    println("Client is not running, let's start the IQFeed client.")
    try
        iqconnect_path = raw"C:\Program Files\DTN\IQFeed\IQConnect.exe"
        product = "EQUIVOLUME_CHARTS"
        version = "1.0"
        login = "123456"
        password = "Foobar"
        open(`$iqconnect_path -product $product -version $version -login $login -password $password -autoconnect`)
    catch err
        @error "Error starting iqconnect: $err"
        return
    end
    println("Sleeping for 5 seconds.")
    sleep(5)
    println("IQFeed client is now running.")
end

function read_stream()
    println("Connecting to the IQFeed client.")
    if !my_socket_init()
        println("Client is not running, let's start the IQFeed client.")
        start_iqconnect()
    end

    println("Send the protocol request.");
    send_request("S,SET PROTOCOL,6.2\r\n",
                 "S,CURRENT PROTOCOL,6.2")

    println("Send a request to start real-time feed on AAPL.");
    global symbol = "AAPL"
    write(socket, "w$(symbol)\r\n")
    println("Sent $(symbol)");
    n_Q_records = 0

    while n_Q_records < 20
        # println("Calling: get_data_from_iq_client");
        text = get_data_from_iq_client()
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
                end
            end
        end
    end
    println("read_stream, the market is closed")
end

if is__market_open()
    read_stream()
else
    println("The market is closed.")
    print("Do you still want to proceed (y/n):")
    key = read(stdin, Char)
    if key == 'y'
        println("OK, let's launch the IQFeed client.")
        start_iqconnect()
        read_stream()
    end
   println("Done.")
end