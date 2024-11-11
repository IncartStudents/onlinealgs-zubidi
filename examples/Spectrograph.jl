module Spectrographs
# Реализовать анимацию ЭКГ синхронно со амплитудным спектром текущего кадра.
using DSP, FFTW
using Plots
using Dates

include("Readers.jl")
import .Readers as rd

# отдельная структура для источника сигнала
mutable struct SignalSource
    ecg::Vector{Float64}
    ecg_cursor::Int
    function SignalSource(ecg::Vector{Float64})
        new(ecg, 1)
    end
end
# читаем и выдаем одну точку ЭКГ
function read(s::SignalSource)
    res = s.ecg[s.ecg_cursor]
    s.ecg_cursor = mod1(s.ecg_cursor + 1, length(s.ecg))
    return res
end


mutable struct Spectrograph
    src::SignalSource
    frame_time::Vector{Float64} # отсчеты времени (X)
    frame_ecg::Vector{Float64} # отсчеты ЭКГ (Y)
    frame_cursor::Int # точка для обновления ЭКГ
    frame_freqs::Vector{Float64} # частоты спектра (X)
    frame_spectr::Vector{Float64} # амплитуды спектра (Y)

    function Spectrograph(src::SignalSource, fs, len = length(ecg))
        frame_ecg = fill(0.0, len)

        frame_time = 0 : len - 1
        frame_time = frame_time ./ fs

        freqs = fftfreq(len, fs)
        frame_freqs = freqs[1 : len ÷ 2]

        frame_spectr = zeros(Float64, size(frame_freqs)) # массив такой же длины

        new(src, frame_time, frame_ecg, 1, frame_freqs, frame_spectr)
    end
end

function step_fast!(state::Spectrograph, speed = 10)
    for _ in 1:speed
        step!(state)
    end
end

function step!(state::Spectrograph)

    # заполняем кадр frame так, чтобы ЭКГ на экране
    # перетиралось справа-налево новыми данными из ecg
    # например, для растущего массива 1,2,3...
    # в какой-то момент будет показано: 8, 9, 10, 4, 5, 6, 7
    # а на следующем кадре: 8, 9, 10, 11, 5, 6, 7
    new_ecg_point = read(state.src)
    len = length(state.frame_ecg)

    state.frame_ecg[state.frame_cursor] = new_ecg_point
    state.frame_cursor = mod1(state.frame_cursor + 1, len)

    F = fft(state.frame_ecg)

    # берем только половину fft
    state.frame_spectr = abs.(F[1 : len ÷ 2])
    state.frame_spectr[1] = 0 # убираем постоянную составляющую

    return nothing
end

function (@main)()

    b_file = raw"C:\Users\gvg\binECG\temp\8s001456.bin"
    #b_file = "../data/ECG/8s001456/8s001456.bin"
    b_samples = 1:10000
    channels, fs, timestart, units = rd.readbin(b_file, b_samples)
    ecg = channels[1][1:10000]

    src = SignalSource(ecg)
    car = Spectrograph(src, b_fs, 700)

    anim = @animate for time = 1:100
        step_fast!(car)
        time_domain = plot(car.frame_time, car.frame_ecg, ylim = (-500, 500), title = "Signal", label='f', legend=:top)
        freq_domain = plot(car.frame_freqs, car.frame_spectr, title = "Spectrum", xlim=(0, fs / 2), label="abs.(F)",legend=:top)
        plot(time_domain, freq_domain, layout = (2,1))
    end
    gif(anim, "cardiograph1.gif", fps = 10)
end

end

import .Spectrographs as sg

sg.main()
