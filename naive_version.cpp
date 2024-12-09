#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <algorithm>
#include <random>

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

// Генерация синусоидального сигнала с добавлением случайного шума
std::vector<double> generateNoisySignal(int num_points, double frequency, double amplitude, double noise_stddev) {
    std::vector<double> signal;
    std::default_random_engine generator;
    std::normal_distribution<double> noise_dist(0.0, noise_stddev); // Генератор случайного шума
    for (int i = 0; i < num_points; ++i) {
        double t = static_cast<double>(i) / num_points; // Нормализованное время
        double base_signal = amplitude * std::sin(2.0 * 3.14 * frequency * t); // Синусоидальный сигнал
        double noise = noise_dist(generator); // Случайный шум
        signal.push_back(base_signal + noise); // Возвращаем зашумлённую синусойду и шум
    }
    return signal;
}

// Функция для применения фильтра Repeated Median
std::vector<double> RepeatedMedianFilter(const std::vector<double>& signal, int window_size) {
    std::vector<double> filtered_signal;
    int half_window = window_size / 2;
    // Проход по всем точкам сигнала
    for (size_t t = 0; t < signal.size(); ++t) {
        int start = std::max(0, static_cast<int>(t) - half_window); // Начало окна
        int end = std::min(static_cast<int>(signal.size()) - 1, static_cast<int>(t) + half_window); // Конец окна
        // Вычисляем наклон для текущего окна
        std::vector<double> slopes;
        for (int i = start; i <= end; ++i) {
            std::vector<double> local_slopes;
            for (int j = start; j <= end; ++j) {
                if (i != j) {
                    local_slopes.push_back((signal[i] - signal[j]) / (i - j)); // Разница значений / разница индексов
                }
            }
            slopes.push_back(findMedian(local_slopes)); // Медиана наклонов
        }
        // Общая медиана наклонов для текущего окна
        double beta_t = findMedian(slopes);
        // Вычисляем уровень для текущего окна
        std::vector<double> levels;
        for (int i = start; i <= end; ++i) {
            levels.push_back(signal[i] - beta_t * i); // Разность между значением и наклоном
        }
        double mu_t = findMedian(levels); // Медиана уровней
        // Итоговое значение для точки t
        filtered_signal.push_back(mu_t + beta_t * t);
    }
    return filtered_signal;
}

// Функция для записи данных в текстовый файл
void writeDataToFile(const std::vector<double>& original_signal, const std::vector<double>& filtered_signal, const std::string& filename) {
    std::ofstream file(filename); // Открытие файла
    if (!file.is_open()) {
        std::cerr << "Ошибка при открытии файла!" << std::endl;
        return;
    }
    // Запись данных построчно: оригинальный и отфильтрованный сигналы
    for (size_t i = 0; i < original_signal.size(); ++i) {
        file << original_signal[i] << "\t" << filtered_signal[i] << "\n";
    }
    file.close();
}

int main() {
        // Наивная реализация
        int num_points = 1000;           // Количество точек
        double frequency = 1.0;          // Частота синусоиды
        double amplitude = 1.0;          // Амплитуда синусоиды
        double noise_stddev = 0.2;       // Стандартное отклонение шума
        int window_size = 11;            // Размер окна фильтра
        std::vector<double> noisy_signal = generateNoisySignal(num_points, frequency, amplitude, noise_stddev);
        std::vector<double> filtered_signal = RepeatedMedianFilter(noisy_signal, window_size);
        writeDataToFile(noisy_signal, filtered_signal, "output.txt");
        std::cout << "Данные успешно записаны в файл output.txt!" << std::endl;
    return 0;
}