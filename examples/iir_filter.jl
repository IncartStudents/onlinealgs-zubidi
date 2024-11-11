
# см. реализации фильтров: https://www.dsprelated.com/freebooks/filters/Four_Direct_Forms.html
# ниже - direct form 2 transposed:
mutable struct IIRFilter{T}
    b::Vector{Float64}
    a::Vector{Float64}
    # s0::Vector{Float64} # начальное состояние для инициализации (сброса)
    si::Vector{Float64} # текущее состояние
    need_restart::Bool # состояние о необходимости инициализации на след. шаге

    function IIRFilter{T}(ftype::FilterType, coefs::FilterCoefficients) where {T}
        df = digitalfilter(ftype, coefs) |> DF2TFilter
        b = coefb(df.coef)
        a = coefa(df.coef)

        order = length(a) - 1
        si = zeros(order)
        s0 = _zerostate(ftype, a, b)

        new(b, a, si, s0, true)
    end
end

function _zerostate(::Union{Lowpass, Bandstop}, a::Vector{Float64}, b::Vector{Float64})
    order = length(a) - 1
    s0 = zeros(order)

    s0[order] = b[order + 1] - a[order + 1]
    for k in order:-1:2
      s0[k - 1] = b[k] - a[k] + s0[k]
    end
    return s0
end

function _zerostate(::Union{Highpass, Bandpass}, a::Vector{Float64}, b::Vector{Float64})
    # если сумма весов b == 0 ???
    order = length(b) - 1
    s0 = zeros(order)

    s0[order] = b[order + 1]
    for k in order:-1:2
      s0[k - 1] = b[k] + s0[k]
    end
    return s0
end

function restart(obj::IIRFilter)
    obj.need_restart = true
end

# все методы run можно вызвать скобками от объекта фильтра
(obj::IIRFilter{T})(args...) where {T} = exe(obj, args...)

# не проверяется на nan и рестарты - вынесено вовне
function exe(obj::IIRFilter{T}, x::T) where T
    a, b, si = obj.a, obj.b, obj.si
    order = length(si)

    y = si[1] + b[1]*x
    for j in 2:order
        si[j-1] = si[j] + b[j]*x - a[j]*y
    end
    si[order] = b[order+1]*x - a[order+1]*y
    y = (T <: Integer) ? round(T, y) : T(y)
    return y
end

function exe(obj::IIRFilter{T}, y::AbstractVector{T}, x::AbstractVector{T}) where T
    a, b, si, s0 = obj.a, obj.b, obj.si, obj.s0
    order = length(si)
    if obj.need_restart
        @inbounds for k in 1:order
            si[k] = s0[k] * x[1] # был xi
        end
        obj.need_restart = false
    end

    @inbounds for i in 1:length(x)
        xi = x[i]
        yi = si[1] + b[1]*xi
        for j in 2:order
            si[j-1] = si[j] + b[j]*xi - a[j]*yi
        end
        si[order] = b[order+1]*xi - a[order+1]*yi
        y[i] = (T <: Integer) ? round(T, yi) : T(yi)
    end
    return obj
end

function runbackward(obj::IIRFilter{T}, y::AbstractVector{T}, x::AbstractVector{T}) where T
    a, b, si, s0 = obj.a, obj.b, obj.si, obj.s0
    order = length(si)
    if obj.need_restart
        @inbounds for k in 1:order
            si[k] = s0[k] * x[end] # был xi
        end
        obj.need_restart = false
    end

    @inbounds for i in length(x):-1:1
        xi = x[i]
        yi = si[1] + b[1]*xi
        for j in 2:order
            si[j-1] = si[j] + b[j]*xi - a[j]*yi
        end
        si[order] = b[order+1]*xi - a[order+1]*yi
        y[i] = (T <: Integer) ? round(T, yi) : T(yi)
    end
    obj.need_restart = true
    return obj
end
