# CUDA-bfs

CUDA kernel for gpu-accelerated BFS. Uses thread-per-frontier-vertex and an atomic counter-based frontier queue. Example graphs included are a 2d torus grid (each vertex has 4 neighbours) and a sparse graph (99% have 2-4 neighbors, and 1% have 100-500 neighbors).

## Build instructions:

Run build command:
```
make
```

Run program:
```
./bfs
```

## BFS Performance (CUDA vs CPU)

| Scale        | Graph Type | GPU (ms) | CPU (ms) | Speedup |
|--------------|------------|----------|----------|---------|
| 1M vertices  | Torus      | 17.12    | 18.76    | 1.10x   |
| 1M vertices  | Sparse     | 8.79     | 41.87    | 4.76x   |
| 9M vertices  | Torus      | 55.16    | 267.36   | 4.85x   |
| 9M vertices  | Sparse     | 82.15    | 893.90   | 10.88x  |


## Notes

Experimented with two kernels. One which directly increments the atomic queue counter to maximize occupancy, and one which has one thread per block increment the counter and write all discovered vertices at once, in an effort to lower contention on the global atomic, and to improve memory coalescing on writes. Both achieved similar performance. More complex kernels did not justify the loss of latency-hiding with more complex synchronization efforts, though perhaps on massive vertex hubs of tens of thousands of edges, they probably could perform better.

Speedups on the grid only started appearing around the 1 million vertex mark.

Hardware used:
GPU: GeForce RTX 3060
CPU: AMD Ryzen 5 5600X
