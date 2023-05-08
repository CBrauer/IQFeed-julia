module Market
export is_open

using Dates, TimeZones, DataFrames, ODBC

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

function is_open()
    # 1. Check to see if today is on the week-end
    day_of_week = Dates.dayofweek(today())
    name_of_day = Dates.dayname(day_of_week)
    if day_of_week == 6 || day_of_week == 7
        println("Today is $name_of_day.")
        return false
    else
        println("Today is $name_of_day.")
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

end