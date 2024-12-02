#pragma once
#include <fstream>
#include <sstream>
#include <vector>

using tTime = unsigned int; // Время, например, в миллисекундах.
using tData = float;        // Тип данных сигнала.

class SignalBufferData {
public:
    tTime getTimeEnd() const { return 0; }
    tData* addData(tData*, size_t) { return nullptr; }
};

class IStreamAlg {
public:
    virtual ~IStreamAlg() = default;
    virtual void Reset() = 0;
    virtual bool Run() = 0;
};

const tTime G_QUANT = 40;

class SignalsFromFile : public IStreamAlg {
protected:
    SignalBufferData& signal_buffer;
    tData* m_buf = nullptr;
    std::ifstream& m_fscan;
    const tTime QUANT;

public:
    SignalsFromFile(SignalBufferData& buffer, std::ifstream& fscan)
        : signal_buffer(buffer),
          m_fscan(fscan),
          QUANT(G_QUANT) {
        m_buf = new tData[QUANT]; // Создаем рабочий буфер
        Reset();
    }

    ~SignalsFromFile() {
        if (m_buf) delete[] m_buf;
    }

    void Reset() override {
        m_fscan.clear();
        m_fscan.seekg(0, std::ios::beg); // Перемотка на начало файла
    }

    bool Run() override {
        size_t len = QUANT * sizeof(tData);

        if (m_fscan.eof()) return false;

        m_fscan.read((char*)m_buf, len);

        if (m_fscan.gcount() < len) {
            return false;
        }

        signal_buffer.addData(m_buf, QUANT);

        return true;
    }
};


