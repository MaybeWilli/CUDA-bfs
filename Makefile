NVCC = nvcc
TARGET = bfs

CUDA_FLAGS = -O3 -arch=sm_86
HOST_FLAGS = -O3 -march=native

all: $(TARGET)

$(TARGET): bfs.cu bfs.cpp
	$(NVCC) $(CUDA_FLAGS) -Xcompiler="$(HOST_FLAGS)" bfs.cu bfs.cpp -o $(TARGET)

clean:
	rm -f $(TARGET)