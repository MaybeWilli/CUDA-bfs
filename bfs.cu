#include <stdio.h>
#include <assert.h>
#include <array>
#include <iostream>
#include <vector>
#include "bfs.h"
#include <chrono>

constexpr int v_size = 3000*3000;
constexpr double rate = 0.01;
constexpr int queue_size = 1024;
int mode = 2;
int dists[v_size];
int* edges;
int e_size;
int offsets[v_size+1];
int current[v_size];
int next_frontier[v_size];

inline
cudaError_t checkCuda(cudaError_t result)
{
    if (result != cudaSuccess)
    {
        printf("CUDA Runtime Error: %s\n", cudaGetErrorString(result));
        assert(result == cudaSuccess);
    }
    return result;
}

void create_graph()
{
    if (mode == 0)
    {
        std::vector<int> temp;
        for (int i = 0; i < v_size; i++)
        {
            offsets[i] = temp.size();
            for (int j = 0; j < v_size; j++)
            {
                if (rand() % 100 / 100.0 < rate && j != i)
                {
                    temp.push_back(j);
                }
            }
        }
        offsets[v_size] = temp.size();
        e_size = temp.size();
        edges = new int[e_size];
        std::copy(temp.begin(), temp.end(), edges);
    }
    else if (mode == 1)
    {
        int l = sqrt(v_size);
        edges = new int[v_size*4];

        for (int i = 0; i < v_size*4; i += 4)
        {
            offsets[i/4] = i;
            edges[i] = (i/4 % l + 1) % l + (int(i/4/l)) * l;
            edges[i+1] = (i/4 % l - 1 + l) % l + (int(i/4/l)) * l;
            edges[i+2] = (i/4 % l) + ((int(i/4/l)+1) % l) * l;
            edges[i+3] = (i/4 % l) + ((int(i/4/l)-1+l) % l) * l;
        }

        offsets[v_size] = v_size*4;
        e_size = v_size*4;
    }
    else if (mode == 2)
    {
        vector<int> degree(v_size);
        int total = 0;
        for (int i = 0; i < v_size; i++)
        {
            if (rand() % 100 < 98)
            {
                degree[i] = rand()% 2 + 2;
            }
            else
            {
                degree[i] = rand() % 400 + 100;
            }
            total += degree[i];
        }

        int offset = 0;
        edges = new int[total];
        for (int i = 0; i < v_size; i++)
        {
            offsets[i] = offset;
            for (int j = 0; j < degree[i]; j++)
            {
                edges[offset + j] = rand() % v_size;
            }
            offset += degree[i];

        }
        offsets[v_size] = total;
        e_size = total;
    }
}

__global__ void frontier_vertex_solve(int* edges, int e_size, int* offsets, int vertices, int* current, int* next, 
    int* dists, int frontier_size, int* next_size)
{
    int idx = threadIdx.x + blockIdx.x * blockDim.x;

    if (idx < frontier_size)
    {
        int vertex = current[idx];
        int dist = dists[vertex];
        int start = offsets[vertex];
        int end = offsets[vertex+1];

        for (int i = start; i < end; i++)
        {
            int edge = edges[i];
            if (atomicCAS(&dists[edge], -1, dist+1) == -1)
            {
                int index = atomicAdd(next_size, 1);
                next[index] = edge;
            }

        }
    }
}

__global__ void frontier_vertex_solve2(int* edges, int e_size, int* offsets, int vertices, int* current, int* next, 
    int* dists, int frontier_size, int* next_size)
{
    __shared__ int queue[queue_size];
    __shared__ int counter;
    __shared__ int queue_index;
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (threadIdx.x == 0)
    {
        counter = 0;
    }
    __syncthreads();

    if (idx < frontier_size)
    {
        int vertex = current[idx];
        int dist = dists[vertex];
        int start = offsets[vertex];
        int end = offsets[vertex+1];

        if (end - start < 32 || true)
        {
            for (int i = start; i < end; i++)
            {
                int edge = edges[i];
                if (atomicCAS(&dists[edge], -1, dist+1) == -1)
                {
                    int index = atomicAdd(&counter, 1);
                    if (index < queue_size)
                    {
                        queue[index] = edge;
                    }
                    else
                    {
                        
                        index = atomicAdd(next_size, 1);
                        next[index] = edge;
                    }
                }
            }
        }
    }//*/
    __syncthreads();
    if (threadIdx.x == 0)
    {
        queue_index = atomicAdd(next_size, counter);
        if (counter >= queue_size)
        {
            counter = queue_size;
        }
    }
    __syncthreads();
    
    for (int i = threadIdx.x; i < counter; i += blockDim.x)
    {
        next[queue_index + i] = queue[i];
    }
}

void init_input()
{
    for (int i = 0; i < v_size; i++)
    {
        dists[i] = -1;
    }
    create_graph();
}

int main()
{
    int start = 0;
    int frontier = 1;
    int* frontier_size = new int;
    string graph_types[] = {"Very dense", "2d torus grid", "Sparse"}; 
    
    //very dense takes too long to generate at higher vertex counts
    for (int i = 1; i < 3; i++)
    {
        unsigned int seed = time(NULL);
        srand(seed);
        
        mode = i;
        init_input();
        dists[start] = 0;
        current[0] = start;

        /*int dists[v_size];
        int* edges;
        int e_size;
        int offsets[v_size+1];
        int current[v_size];
        int next[v_size];*/

        int* d_dists;
        int* d_edges;
        int* d_offsets;
        int* d_current;
        int* d_next;
        int* d_next_size;

        checkCuda ( cudaMalloc((void**)&d_dists, v_size * sizeof(int)));
        checkCuda ( cudaMalloc((void**)&d_offsets, (v_size+1) * sizeof(int)));
        checkCuda ( cudaMalloc((void**)&d_edges, e_size * sizeof(int)));
        checkCuda ( cudaMalloc((void**)&d_current, v_size * sizeof(int)));
        checkCuda ( cudaMalloc((void**)&d_next, v_size * sizeof(int)));
        checkCuda ( cudaMalloc((void**)&d_next_size, sizeof(int)));

        //dim3 grid(244, 1);
        dim3 grid(v_size/256 + 1, 1);
        dim3 block(256, 1);

        dim3 grid2(v_size*32/256 + 1, 1);

        float milliseconds;
        cudaEvent_t startEvent, stopEvent;
        checkCuda( cudaEventCreate(&startEvent) );
        checkCuda( cudaEventCreate(&stopEvent) );

        checkCuda( cudaMemcpy(d_dists, dists, v_size * sizeof(int), cudaMemcpyHostToDevice) );
        checkCuda( cudaMemcpy(d_offsets, offsets, (v_size+1) * sizeof(int), cudaMemcpyHostToDevice) );
        checkCuda( cudaMemcpy(d_edges, edges, e_size * sizeof(int), cudaMemcpyHostToDevice) );
        checkCuda( cudaMemcpy(d_current, current, v_size * sizeof(int), cudaMemcpyHostToDevice) );
        checkCuda( cudaMemcpy(d_next, next_frontier, v_size * sizeof(int), cudaMemcpyHostToDevice) );
        checkCuda( cudaMemset(d_next_size, 0, sizeof(int)));

        checkCuda( cudaEventRecord(startEvent, 0) );
        while (true)
        {
            frontier_vertex_solve<<<grid, block>>>(d_edges, e_size, d_offsets, v_size, d_current, d_next, d_dists, 
                frontier, d_next_size);
            
            checkCuda( cudaMemcpy(frontier_size, d_next_size, sizeof(int), cudaMemcpyDeviceToHost) );

            if (*frontier_size == 0)
            {
                checkCuda( cudaMemcpy(dists, d_dists, v_size*sizeof(int), cudaMemcpyDeviceToHost) );
                break;
            }
            int* temp = d_current;
            d_current = d_next;
            d_next = temp;
            frontier = *frontier_size;
            checkCuda( cudaMemset(d_next_size, 0, sizeof(int)));
            grid = dim3((frontier + block.x - 1) / block.x);

        }
        checkCuda( cudaDeviceSynchronize() );
        checkCuda( cudaEventRecord(stopEvent, 0) );
        checkCuda( cudaEventSynchronize(stopEvent) );
        checkCuda( cudaEventElapsedTime(&milliseconds, startEvent, stopEvent) );

        Bfs bfs = Bfs(v_size, edges, e_size, offsets);
        auto start_time = chrono::steady_clock::now();
        bfs.solve(0);
        auto end_time = chrono::steady_clock::now();
        chrono::duration<double> time_passed = end_time - start_time;
        /*for (int i = 0; i < v_size; i++)
        {
            std::cout<<dists[i]<<" ";
        }
        std::cout<<std::endl;
        for (int i = 0; i < v_size; i++)
        {
            std::cout<<bfs.dists[i]<<" ";
        }*/
        for (int j = 0; j < v_size; j++)
        {
            if (dists[j] != bfs.dists[j])
            {
                std::cout<<"Error found "<<offsets[j+1] - offsets[j]<<" "<<j<<" "<<dists[j]<<" "<<bfs.dists[j]<<endl;
                //break;
            }
        }
        std::cout<<std::endl;
        std::cout<<"Graph type: "<<graph_types[i]<<std::endl;
        std::cout<<"GPU Milliseconds: "<<milliseconds<<std::endl;
        std::cout<<"CPU milliseconds: "<<time_passed.count()*1000<<std::endl;
        delete[] edges;
        cudaFree(d_dists);
        cudaFree(d_offsets);
        cudaFree(d_edges);
        cudaFree(d_current);
        cudaFree(d_next);
        cudaFree(d_next_size);
    }

    

}