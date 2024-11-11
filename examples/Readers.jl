
module Readers

using Dates
using CSV
using DataFrames

export read_csv_header, readhdr, readbin


function read_csv_header(filepath::String)
    timestart = nothing
    freq = nothing
    len = nothing
    dataname = ""
    header_lines = 0
    open(filepath, "r") do io
        while !eof(io)
            line = readline(io)
            m = match(r"#(\w+):(.*)", line) # #name:value
            header_lines += 1 # читаем, пока не перестанут идти решётки
            if isnothing(m)
                break
            end
            if m.captures[1] == "timestart"
                timestart = parse(DateTime, m.captures[2])
            end
            if m.captures[1] == "freq"
                freq = parse(Float64, m.captures[2])
            end
            if m.captures[1] == "len"
                len = parse(Int, m.captures[2])
            end
            if m.captures[1] == "dataname"
                dataname = String(m.captures[2])
            end
        end
    end
    return timestart, freq, len, dataname, header_lines
end

"""
чтение hdr-файла заголовка
"""
function readhdr(filepath::AbstractString)

    str = open(filepath, "r") do io
        len = stat(filepath).size
        bytes = Vector{UInt8}(undef, len)
        readbytes!(io, bytes, len)
        if bytes[1:3] == [0xEF, 0xBB, 0xBF] # проверка на UTF-8 BOM и пропуск
            bytes = bytes[4:end]
        end
        str = Array{Char}(bytes) |> x->String(x)
    end
    io = IOBuffer(str)
    lines = readlines(io) #, enc"windows-1251") # read and decode from windows-1251 to UTF-8 string

    lines = rstrip.(lines)

    delim = (' ', '\t')
    ln = split(lines[1], delim)
    num_ch, fs, lsb = parse(Int, ln[1]), parse(Float64, ln[2]), parse(Float64, ln[3])
    type = Int32
    # if (length(ln) > 3) # optional field
    #     type = string2datatype[ln[4]]
    # end

    ln = split(lines[2], delim)
    ibeg, iend = parse(Int, ln[1]), parse(Int, ln[2])
    timestart = parse(DateTime, ln[3])

    names = String.(split(lines[3], delim))
    lsbs = parse.(Float64, split(lines[4], delim))
    units = String.(split(lines[5], delim))

    if num_ch != length(names) # фикс, если в начале указано неверное кол-во каналов
        num_ch = length(names)
    end

    length(names) == length(lsbs) == length(units) || error("разное количество полей")

    return num_ch, fs, ibeg, iend, timestart, names, lsbs, units, type
end

"""
чтение bin-файла с каналами, рядом должен лежать hdr-файл
"""
function readbin(filepath::AbstractString, range::Union{Nothing, UnitRange{Int}} = nothing)
    # защита от дурака
    fpath, ext = splitext(filepath)
    hdrpath = fpath * ".hdr"
    binpath = fpath * ".bin"

    num_ch, fs, _, _, timestart, names, lsbs, units, type = readhdr(hdrpath)

    offset = (range !== nothing) ? range.start - 1 : 0

    elsize = num_ch * sizeof(type)
    byteoffset = offset * elsize # 0-based
    maxlen = (filesize(binpath) - byteoffset) ÷ elsize # 0-based
    len = (range !== nothing) ? min(maxlen, length(range)) : maxlen

    if len <= 0
        data = Matrix{type}(undef, num_ch, 0)
    else
        data = Matrix{type}(undef, num_ch, len)
        open(binpath, "r") do io
            seek(io, byteoffset)
            read!(io, data)
        end
    end

    channels = [data[ch, :] .* lsbs[ch] for ch in 1:num_ch] |> Tuple # matrix -> vector of channel vectors
    sym_names = Symbol.(names) |> Tuple # column names: String -> Symbol

    named_channels = NamedTuple{sym_names}(channels)
    return named_channels, fs, timestart, units
end

end # module
