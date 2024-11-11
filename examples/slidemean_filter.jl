
"""
Фильтр скользящего среднего в окне `window`. 
Задержка фильтра: `(window-1)/2`
"""
mutable struct SlideMeanFilter{T}
    buf::Vector{T}
    k::Int
    need_restart::Bool
    prev_sum::T
    function SlideMeanFilter{T}(window::Int) where T
        new(fill(T(0), window-1), 1, true)
    end
end

function exe(obj::SlideMeanFilter{T}, x::T) where T
    buf, k = obj.buf, obj.k

    if obj.need_restart # инициализация на первой точке
        fill!(buf, x) # заполняем буфер первой точкой
        obj.need_restart = false
        obj.prev_sum = x
    end
    window = (length(buf) + 1)
    y = obj.prev_sum + ( x - buf[k] ) / window
    # sum_x = x
    # for xi in buf # сумма всех элементов в буфере + 1 новая точка
    #     sum_x += xi
    # end
    # y = sum_x / window # (length(buf) + 1)
    obj.prev_sum = y

    buf[k] = x
    k += 1
    if k > length(buf)
        k = 1
    end
    
    obj.k = k
    return y
end

(obj::SlideMeanFilter)(x) = exe(obj, x)

# =============================================

# inp = fill(-3.0, 30) # входной сигнал - массив точек
# inp[7] = -1.0
# inp[20:22] = [-2.0,-1.0,-2.0]
# out = fill(0.0, size(inp)) # выход - массив такой же длины

# # параметры фильтра
# window = 5

# slide_flt = SlideMeanFilter{Float64}(window)

# for i in 1:length(inp)
#     x = inp[i]
#     y = slide_flt(x)
#     out[i] = y
# end

# plot(inp, marker = :circle)
# plot!(out, marker = :circle, legend = false)