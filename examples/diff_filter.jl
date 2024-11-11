
"""
Первая разность c шагом `delta`: 
`y[i] = x[i] - x[i-delta]`.
Задержка фильтра: `delta/2`
"""
mutable struct DiffFilter{T}
    buf::Vector{T} # буфер предыдущих отсчетов
    k::Int
    need_restart::Bool

    function DiffFilter{T}(delta::Int) where T
        new(fill(T(0), delta), 1, true)
    end
end

function exe(obj::DiffFilter{T}, x::T) where T
    buf, k = obj.buf, obj.k

    if obj.need_restart # инициализация на первой точке
        fill!(buf, x) # заполняем буфер первой точкой
        obj.need_restart = false
    end

    x0 = buf[k]
    y = x - x0

    buf[k] = x
    k += 1
    if k > length(buf)
        k = 1
    end
    
    obj.k = k
    return y
end

(obj::DiffFilter)(x) = exe(obj, x)

# =============================================

# inp = Float64[3,3,3,3,3,2,1,2,3,3,3,3,3] # входной сигнал - массив точек
# out = fill(0.0, size(inp)) # выход - массив такой же длины

# # параметр фильтра:
# delta = 2
# d_flt = DiffFilter{Float64}(delta)

# for i in 1:length(inp)
#     out[i] = exe(d_flt, inp[i]) # состояние фильтра - x0, меняется при повторных вызовах функции
# end

# plot(inp, marker = :circle)
# plot!(out, marker = :circle, legend = false)