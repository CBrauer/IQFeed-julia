module IQFeed

export init_sockets
export launch_iqconnect
export send_byte_message
export send_raw_message
export send_request
export get_data_from_iq_client

using Sockets, InteractiveUtils

function init_socket()
    println("At init_socket.")
    try
        # Connect to the server and println socket and peer details
        inet_addr = Sockets.InetAddr(IPv4("127.0.0.1"), 5009)
        global socket = Sockets.connect(inet_addr)
        #sockname = getsockname(socket)
        #println("ip $(sockname[1]), port $(sockname[2])")
        peername = getpeername(socket)
        println("socket: ip $(peername[1]), port $(peername[2])")
        println("socket has been initialized.")
        return true, socket
    catch err
        if err.code == Base.UV_ECONNREFUSED
            println("The socket connection was refused.")
        else
            @error "Error in intializing the socket: $err"
        end
        return false, nothing
    end
end

function launch_iqconnect()
    println("launch_iqconnect: launching the IQFeed client.")
    try
        iqconnect_path = raw"C:\Program Files\DTN\IQFeed\IQConnect.exe"
        product = "EQUIVOLUME_CHARTS"
        version = "1.0"
        login = "187519"
        password = "Foobar112357"
        open(`$iqconnect_path -product $product -version $version -login $login -password $password -autoconnect`)
    catch err
        @error "Error launching iqconnect: $err"
        return
    end
    println("Sleeping for 5 seconds.")
    sleep(5)
    println("IQFeed client is now running.")
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
        peername = getpeername(socket)
        println("socket: ip $(peername[1]), port $(peername[2])")
        println("send_message error: $err")
    end
end

function send_raw_message(text::String)
    try
        println("send_raw_message: '$(text)'")
        write(socket, text)
    catch err
        peername = getpeername(socket)
        println("socket: ip $(peername[1]), port $(peername[2])")
        println("send_message error: $err")
    end
end

function send_request(request::String, expected_response::String)
    send_raw_message(request)
    for loop in 1:10
        response = readline(socket)
        println("  $(loop). response from send_request: $(response)")
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
    # println("get_data_from_iq_client is trying to read text from the socket.")
    try
        text = readline(socket)
        # println("get_data_from_iq_client: '$(text)'")
        return text
    catch err
        println("get_data_from_iq_client error: $err")
        return "error"
    end
end

end