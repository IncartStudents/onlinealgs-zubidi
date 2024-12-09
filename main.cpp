#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <algorithm>
#include "SignalsFromFile.h"

// Функция для нахождения медианы
double findMedian(std::vector<double>& data) {
    size_t n = data.size();
    size_t mid = n / 2;
    std::nth_element(data.begin(), data.begin() + mid, data.end()); // Нахождение среднего элемента
    if (n % 2 != 0) {
        return data[mid]; // Если нечётное количество элементов
    } else {
        double mid1 = data[mid];
        std::nth_element(data.begin(), data.begin() + mid - 1, data.end());
        double mid2 = data[mid - 1];
        return (mid1 + mid2) / 2.0; // Если чётное количество элементов
    }
}

// Функция для применения фильтра Repeated Median
std::vector<double> RepeatedMedianFilter(const std::vector<double>& signal, int window_size) {
    std::vector<double> filtered_signal;
    int half_window = window_size / 2;
    for (size_t t = 0; t < signal.size(); ++t) { // Проход по всем точкам сигнала
        int start = std::max(0, static_cast<int>(t) - half_window); // Начало окна
        int end = std::min(static_cast<int>(signal.size()) - 1, static_cast<int>(t) + half_window); // Конец окна
        std::vector<double> slopes; // Вычисляем наклон для текущего окна
        for (int i = start; i <= end; ++i) {
            std::vector<double> local_slopes;
            for (int j = start; j <= end; ++j) {
                if (i != j) {
                    local_slopes.push_back((signal[i] - signal[j]) / (i - j)); // Разница значений / разница индексов
                }
            }
            slopes.push_back(findMedian(local_slopes)); // Медиана наклонов
        }
        double beta_t = findMedian(slopes); // Общая медиана наклонов для текущего окна
        std::vector<double> levels; // Вычисляем уровень для текущего окна
        for (int i = start; i <= end; ++i) {
            levels.push_back(signal[i] - beta_t * i); // Разность между значением и наклоном
        }
        double mu_t = findMedian(levels); // Медиана уровней
        filtered_signal.push_back(mu_t + beta_t * t); // Итоговое значение для точки t
    }
    return filtered_signal;
}


class Buffer : public SignalBufferData {
private:
    std::vector<tData> buffer;
public:
    void addData(const tData* data, size_t size) override {
        buffer.insert(buffer.end(), data, data + size);
    }
    std::vector<tData> getBuffer() const {
        return buffer;
    }
    void clear() {
        buffer.clear();
    }
};

size_t getSavedPosition(const std::string& position_file) {
    std::ifstream file(position_file);
    size_t position = 0;
    if (file.is_open()) {
        file >> position;
        file.close();
    }
    return position;
}

void savePosition(const std::string& position_file, size_t position) {
    std::ofstream file(position_file, std::ios::trunc);
    if (file.is_open()) {
        file << position;
        file.close();
    }
}

void processSignalBinarFile(const std::string& input_file,
                                  const std::string& output_file,
                                  const std::string& position_file,
                                  int window_size) {
    size_t saved_position = getSavedPosition(position_file);
    std::ifstream input(input_file, std::ios::binary);
    std::ofstream output(output_file, std::ios::app);
    Buffer signal_buffer;
    SignalsFromFile signal_reader(signal_buffer, input);
    input.seekg(saved_position); // Устанавливаем позицию в файле
    std::vector<double> buffer;
    size_t batch_counter = saved_position; // Счётчик обработанных точек
    size_t total_points_processed = G_QUANT*batch_counter;  // Счётчик партий обработки
    std::cout << "Начало обработки файла: " << input_file << std::endl;
    while (true) {
        bool success = signal_reader.Run();
        if (!success) {
            std::cout << "Данные завершены или произошла ошибка чтения." << std::endl;
            break;
        }
        auto channel_data = signal_buffer.getBuffer();
        buffer.assign(channel_data.begin(), channel_data.end());
        if (!buffer.empty()) {
            std::vector<double> filtered_signal = RepeatedMedianFilter(buffer, window_size);
            for (size_t i = 0; i < buffer.size(); ++i) {
                output << buffer[i] << "\t" << filtered_signal[i] << "\n";
            }
            total_points_processed += buffer.size();
            batch_counter++;
            if (batch_counter % 10 == 0) {
                std::cout << "Обработано партий: " << batch_counter
                          << ", Всего точек: " << total_points_processed << std::endl;
            }
        }
        // Сохраняем текущую позицию в файле
        std::streampos current_position = batch_counter;
        savePosition(position_file, static_cast<size_t>(current_position));
        signal_buffer.clear();
    }
    // Сохраняем последнюю позицию перед выходом
    std::streampos final_position = batch_counter;
    savePosition(position_file, static_cast<size_t>(final_position));
    input.close();
    output.close();
}

int main() {
    std::string input_file = "8s001456.bin";
    std::string output_file = "filtered_signals.txt";
    std::string position_file = "position_log.txt";
    int window_size = 10;
    processSignalBinarFile(input_file, output_file, position_file, window_size);
    std::cout << "Обработка завершена." << std::endl;
    return 0;
}
